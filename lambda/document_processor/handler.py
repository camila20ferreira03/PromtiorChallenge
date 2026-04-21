"""S3 ObjectCreated:Put -> load, detect (pdf|html), clean, chunk, write JSONL. Single-file handler."""
from __future__ import annotations

import hashlib
import io
import json
import logging
import os
import re
from typing import Any
from urllib.parse import unquote_plus

import boto3
from bs4 import BeautifulSoup
from langchain_text_splitters import RecursiveCharacterTextSplitter
from pypdf import PdfReader

RAW_BUCKET = os.environ["RAW_BUCKET"]
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
CHUNK_SIZE = int(os.getenv("CHUNK_SIZE", "1000"))
CHUNK_OVERLAP = int(os.getenv("CHUNK_OVERLAP", "150"))
MAX_INPUT_MB = int(os.getenv("MAX_INPUT_MB", "20"))

_HTML_NOISE_TAGS = ("script", "style", "noscript", "nav", "footer", "header", "aside", "form")
_WS_RUN = re.compile(r"[ \t]+")
_MULTI_NL = re.compile(r"\n{3,}")

_s3 = boto3.client("s3")
log = logging.getLogger()
log.setLevel(logging.INFO)


class _Skip(Exception):
    """Raised to skip an object (logged, not fatal)."""


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    records = event.get("Records") or []
    if not records:
        return {"statusCode": 400, "body": json.dumps({"error": "expected_s3_records"})}

    processed: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []

    for record in records:
        if record.get("eventSource") != "aws:s3":
            continue
        if record.get("eventName") != "ObjectCreated:Put":
            continue

        s3_info = record.get("s3") or {}
        bucket = (s3_info.get("bucket") or {}).get("name")
        key = (s3_info.get("object") or {}).get("key")
        if not bucket or not key:
            continue
        key = unquote_plus(key)

        if bucket != RAW_BUCKET:
            skipped.append({"key": key, "reason": f"unexpected_bucket:{bucket}"})
            continue

        try:
            processed.append(_process(bucket, key))
        except _Skip as err:
            log.info("skip %s/%s: %s", bucket, key, err)
            skipped.append({"key": key, "reason": str(err)})

    if not processed and not skipped:
        return {"statusCode": 400, "body": json.dumps({"error": "no_matching_records"})}

    return {"statusCode": 200, "body": json.dumps({"processed": processed, "skipped": skipped})}


# --- load ---

def _process(bucket: str, key: str) -> dict[str, Any]:
    resp = _s3.get_object(Bucket=bucket, Key=key)
    size_mb = (resp.get("ContentLength") or 0) / (1024 * 1024)
    if size_mb > MAX_INPUT_MB:
        raise _Skip(f"object_too_large_{size_mb:.1f}MB")

    body: bytes = resp["Body"].read()
    if not body:
        raise _Skip("empty_object")

    content_type = (resp.get("ContentType") or "").lower()
    user_meta = {k.lower(): v for k, v in (resp.get("Metadata") or {}).items()}
    kind = _detect_kind(body, content_type, key)
    source_id = hashlib.sha256(f"{bucket}:{key}".encode("utf-8")).hexdigest()[:32]

    # --- clean ---
    if kind == "pdf":
        text, pages, title = _clean_pdf(body)
        document_type = "pdf"
    else:
        text, pages, title = _clean_html(body)
        document_type = "webpage"

    base_meta = {
        "source_id": source_id,
        "title": title or os.path.basename(key),
        "created_date": resp["LastModified"].isoformat(),
        "document_type": document_type,
        "topic": user_meta.get("topic", ""),
        "category": user_meta.get("category", ""),
        "source_bucket": bucket,
        "source_key": key,
    }

    # --- chunk ---
    chunks = _chunk(text, pages, base_meta)
    if not chunks:
        raise _Skip("no_text_extracted")

    # --- write ---
    dest_key = f"processed/{key}.chunks.jsonl"
    body_out = "\n".join(json.dumps(c, ensure_ascii=False) for c in chunks).encode("utf-8")
    _s3.put_object(
        Bucket=PROCESSED_BUCKET,
        Key=dest_key,
        Body=body_out,
        ContentType="application/x-ndjson; charset=utf-8",
    )
    return {"source_key": key, "processed_key": dest_key, "chunks": len(chunks)}


def _detect_kind(body: bytes, content_type: str, key: str) -> str:
    """PDF vs HTML: magic bytes > Content-Type > extension."""
    if body[:5] == b"%PDF-":
        return "pdf"
    if "application/pdf" in content_type:
        return "pdf"
    if "text/html" in content_type or "application/xhtml" in content_type:
        return "html"
    lowered = key.lower()
    if lowered.endswith(".pdf"):
        return "pdf"
    if lowered.endswith((".html", ".htm")):
        return "html"
    raise _Skip(f"unsupported_kind:content_type={content_type!r}")


def _clean_pdf(body: bytes) -> tuple[str, list[str], str]:
    """Per-page extraction keeps page_number accurate later."""
    reader = PdfReader(io.BytesIO(body))
    pages = [_normalize(p.extract_text() or "") for p in reader.pages]
    title = ""
    meta = getattr(reader, "metadata", None)
    if meta and hasattr(meta, "get"):
        t = meta.get("/Title")
        if t:
            title = str(t).strip()
    return "\n\n".join(p for p in pages if p), pages, title


def _clean_html(body: bytes) -> tuple[str, list[str], str]:
    """Strip noise tags; pull visible text, preserving structure via newlines."""
    soup = BeautifulSoup(body, "html.parser")
    for tag in soup(list(_HTML_NOISE_TAGS)):
        tag.decompose()
    title = soup.title.string.strip() if soup.title and soup.title.string else ""
    return _normalize(soup.get_text(separator="\n")), [], title


def _normalize(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = _WS_RUN.sub(" ", text)
    text = _MULTI_NL.sub("\n\n", text)
    return text.strip()


def _chunk(text: str, pages: list[str], base_meta: dict[str, Any]) -> list[dict[str, Any]]:
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP,
        length_function=len,
    )
    chunks: list[dict[str, Any]] = []
    # PDF: chunk per page so page_number stays accurate. HTML: one text stream.
    if pages:
        for page_number, page_text in enumerate(pages, start=1):
            if not page_text:
                continue
            for piece in splitter.split_text(page_text):
                chunks.append(_row(piece, base_meta, len(chunks), page_number))
    else:
        for piece in splitter.split_text(text):
            chunks.append(_row(piece, base_meta, len(chunks), None))
    return chunks


def _row(text: str, base_meta: dict[str, Any], ordinal: int, page_number: int | None) -> dict[str, Any]:
    metadata = dict(base_meta)
    metadata["chunk_id"] = f"{base_meta['source_id']}:{ordinal}"
    if page_number is not None:
        metadata["page_number"] = page_number
    return {"text": text, "metadata": metadata}
