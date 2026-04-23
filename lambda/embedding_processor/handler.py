"""S3 ObjectCreated (processed/*.chunks.jsonl) -> OpenAI embeddings -> RDS Postgres + pgvector.

Idempotent: on every invocation, rows with the incoming `metadata.source_id` are
deleted from the collection before the new ones are inserted. This lets a raw
document be re-uploaded and fully reindexed with no duplicates.
"""
from __future__ import annotations

import json
import logging
import os
from typing import Any
from urllib.parse import quote_plus, unquote_plus

import boto3
import psycopg
from langchain_core.documents import Document
from langchain_openai import OpenAIEmbeddings
from langchain_postgres import PGVector

PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
OPENAI_SECRET_ARN = os.environ["OPENAI_SECRET_ARN"]
DB_SECRET_ARN = os.environ["DB_SECRET_ARN"]
EMBEDDING_MODEL = os.environ.get("EMBEDDING_MODEL", "text-embedding-3-small")
PGVECTOR_COLLECTION = os.environ.get("PGVECTOR_COLLECTION", "promtior_docs")
EMBED_BATCH_SIZE = int(os.environ.get("EMBED_BATCH_SIZE", "64"))

_s3 = boto3.client("s3")
_secrets = boto3.client("secretsmanager")

log = logging.getLogger()
log.setLevel(logging.INFO)

_store: PGVector | None = None
_libpq_uri: str | None = None
_extension_ready = False


class _Skip(Exception):
    """Logged and reported per-record; does not fail the invocation."""


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    records = event.get("Records") or []
    if not records:
        return {"statusCode": 400, "body": json.dumps({"error": "expected_s3_records"})}

    _ensure_openai_key()
    store = _get_store()

    processed: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []

    for record in records:
        if record.get("eventSource") != "aws:s3":
            continue
        if not (record.get("eventName") or "").startswith("ObjectCreated:"):
            continue

        s3_info = record.get("s3") or {}
        bucket = (s3_info.get("bucket") or {}).get("name")
        key = (s3_info.get("object") or {}).get("key")
        if not bucket or not key:
            continue
        key = unquote_plus(key)

        if not key.startswith("processed/") or not key.endswith(".chunks.jsonl"):
            skipped.append({"key": key, "reason": "not_a_chunks_jsonl"})
            continue

        try:
            processed.append(_process_record(store, bucket, key))
        except _Skip as err:
            log.info("skip %s/%s: %s", bucket, key, err)
            skipped.append({"key": key, "reason": str(err)})

    return {"statusCode": 200, "body": json.dumps({"processed": processed, "skipped": skipped})}


def _process_record(store: PGVector, bucket: str, key: str) -> dict[str, Any]:
    chunks = _read_chunks(bucket, key)
    if not chunks:
        raise _Skip("empty_jsonl")

    source_id = (chunks[0].get("metadata") or {}).get("source_id")
    if not source_id:
        raise _Skip("missing_source_id")

    deleted = _delete_by_source_id(source_id)

    docs: list[Document] = []
    ids: list[str] = []
    for i, row in enumerate(chunks):
        metadata = dict(row.get("metadata") or {})
        docs.append(Document(page_content=row.get("text", ""), metadata=metadata))
        ids.append(metadata.get("chunk_id") or f"{source_id}:{i}")

    store.add_documents(docs, ids=ids)

    log.info(
        "indexed source_id=%s key=%s deleted=%d inserted=%d",
        source_id, key, deleted, len(docs),
    )
    return {
        "source_key": key,
        "source_id": source_id,
        "deleted": deleted,
        "inserted": len(docs),
    }


def _read_chunks(bucket: str, key: str) -> list[dict[str, Any]]:
    body = _s3.get_object(Bucket=bucket, Key=key)["Body"].read()
    chunks: list[dict[str, Any]] = []
    for line in body.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            chunks.append(json.loads(line))
        except json.JSONDecodeError:
            log.warning("skipping malformed jsonl line in %s", key)
    return chunks


def _get_store() -> PGVector:
    """Lazy, per-container PGVector client. Ensures the vector extension on first use."""
    global _store
    if _store is not None:
        return _store

    sa_url, libpq_uri = _load_db_uris()
    _ensure_vector_extension(libpq_uri)

    _store = PGVector(
        embeddings=OpenAIEmbeddings(model=EMBEDDING_MODEL, chunk_size=EMBED_BATCH_SIZE),
        collection_name=PGVECTOR_COLLECTION,
        connection=sa_url,
        use_jsonb=True,
    )
    return _store


def _ensure_vector_extension(libpq_uri: str) -> None:
    """Idempotent `CREATE EXTENSION vector;`. Once per cold start is enough."""
    global _extension_ready
    if _extension_ready:
        return

    with psycopg.connect(libpq_uri, autocommit=True) as conn:
        conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
    _extension_ready = True


def _delete_by_source_id(source_id: str) -> int:
    """Drop every embedding whose `metadata.source_id` matches. Returns rows deleted.

    Done via a direct psycopg connection to sidestep langchain_postgres private
    internals. The `langchain_pg_collection` / `langchain_pg_embedding` tables
    are PGVector's stable public contract.
    """
    global _libpq_uri
    if _libpq_uri is None:
        _load_db_uris()
    assert _libpq_uri is not None

    with psycopg.connect(_libpq_uri) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                DELETE FROM langchain_pg_embedding
                WHERE collection_id = (
                    SELECT uuid FROM langchain_pg_collection WHERE name = %s
                )
                AND cmetadata->>'source_id' = %s
                """,
                (PGVECTOR_COLLECTION, source_id),
            )
            return cur.rowcount or 0


def _load_db_uris() -> tuple[str, str]:
    """Read RDS creds once and return (SQLAlchemy URL, libpq URI)."""
    global _libpq_uri
    resp = _secrets.get_secret_value(SecretId=DB_SECRET_ARN)
    payload = json.loads(resp["SecretString"])
    host = payload["host"]
    port = int(payload.get("port", 5432))
    dbname = payload.get("dbname", "postgres")
    user = quote_plus(str(payload["username"]))
    password = quote_plus(str(payload["password"]))
    sa_url = (
        f"postgresql+psycopg://{user}:{password}@{host}:{port}/{dbname}"
        "?sslmode=require"
    )
    libpq_uri = (
        f"postgresql://{user}:{password}@{host}:{port}/{dbname}?sslmode=require"
    )
    _libpq_uri = libpq_uri
    return sa_url, libpq_uri


def _ensure_openai_key() -> None:
    """Populate OPENAI_API_KEY from Secrets Manager once per cold start."""
    if os.environ.get("OPENAI_API_KEY"):
        return
    resp = _secrets.get_secret_value(SecretId=OPENAI_SECRET_ARN)
    raw = resp.get("SecretString") or ""
    key = raw.strip()
    if key.startswith("{"):
        try:
            payload = json.loads(raw)
            key = payload.get("OPENAI_API_KEY") or payload.get("openai_api_key") or ""
        except json.JSONDecodeError:
            pass
    if not key:
        raise RuntimeError(f"secret {OPENAI_SECRET_ARN} did not yield an OpenAI key")
    os.environ["OPENAI_API_KEY"] = key
