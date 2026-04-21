"""In-memory cache of processed S3 chunks, formatted as JSON for prompt stuffing.

The document Lambda writes `processed/<source_key>.chunks.jsonl` files to the
processed bucket. At app startup (and on refresh) we list the prefix, read each
JSONL, and cache the flattened `[{text, metadata}]` list.
"""
from __future__ import annotations

import json
import logging
from threading import Lock
from typing import Any

from app.config import PROCESSED_BUCKET, s3_client

log = logging.getLogger(__name__)

_PREFIX = "processed/"

_CHUNKS: list[dict[str, Any]] = []
_DOCS_JSON: str = "[]"
_LOCK = Lock()


def load_docs() -> int:
    """Rebuild the in-memory cache from S3. Returns the number of chunks loaded."""
    if not PROCESSED_BUCKET:
        log.warning("PROCESSED_BUCKET not set; doc cache will be empty")
        _set_cache([])
        return 0

    s3 = s3_client()
    chunks: list[dict[str, Any]] = []
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=PROCESSED_BUCKET, Prefix=_PREFIX):
        for obj in page.get("Contents") or []:
            key = obj.get("Key")
            if not key or not key.endswith(".chunks.jsonl"):
                continue
            try:
                body = s3.get_object(Bucket=PROCESSED_BUCKET, Key=key)["Body"].read()
            except Exception:
                log.exception("failed to read s3://%s/%s", PROCESSED_BUCKET, key)
                continue
            for line in body.splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    chunks.append(json.loads(line))
                except json.JSONDecodeError:
                    log.warning("skipping malformed jsonl line in %s", key)

    _set_cache(chunks)
    log.info("loaded %d chunks from s3://%s/%s", len(chunks), PROCESSED_BUCKET, _PREFIX)
    return len(chunks)


def _set_cache(chunks: list[dict[str, Any]]) -> None:
    global _CHUNKS, _DOCS_JSON
    grouped = _group_by_title(chunks)
    with _LOCK:
        _CHUNKS = chunks
        _DOCS_JSON = json.dumps(grouped, ensure_ascii=False)


def _group_by_title(chunks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Collapse chunks into `[{title, source, chunks: [text, ...]}]` for the prompt."""
    buckets: dict[str, dict[str, Any]] = {}
    for chunk in chunks:
        meta = chunk.get("metadata") or {}
        title = meta.get("title") or meta.get("source_key") or "untitled"
        bucket = buckets.setdefault(
            title,
            {
                "title": title,
                "source": meta.get("source_key", ""),
                "document_type": meta.get("document_type", ""),
                "chunks": [],
            },
        )
        bucket["chunks"].append(chunk.get("text", ""))
    return list(buckets.values())


def get_docs_json() -> str:
    """Return the cached doc payload ready to drop into the prompt template."""
    with _LOCK:
        return _DOCS_JSON


def get_chunk_count() -> int:
    with _LOCK:
        return len(_CHUNKS)
