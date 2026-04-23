"""pgvector-backed retrieval used by chain.py.

At chat time we embed the user's question (OpenAI) and run a similarity search
against the `langchain_pg_embedding` table populated by the embedding Lambda.
No document cache in this process — pgvector is the single source of truth.
"""
from __future__ import annotations

import json
import logging
from threading import Lock
from typing import Any

from langchain_core.documents import Document
from langchain_openai import OpenAIEmbeddings
from langchain_postgres import PGVector

from app.config import (
    EMBEDDING_MODEL,
    PGVECTOR_COLLECTION,
    load_db_connection_string,
)

log = logging.getLogger(__name__)

_LOCK = Lock()
_STORE: PGVector | None = None


def _get_store() -> PGVector:
    """Lazy-init a process-wide PGVector client (opens a pooled SQLAlchemy engine).

    Creating the store on import would force the Secrets Manager lookup to run
    at container build time; deferring it keeps startup cheap and surfaces DB
    issues as HTTP errors on the first /chat request rather than as boot loops.
    """
    global _STORE
    with _LOCK:
        if _STORE is None:
            _STORE = PGVector(
                embeddings=OpenAIEmbeddings(model=EMBEDDING_MODEL),
                collection_name=PGVECTOR_COLLECTION,
                connection=load_db_connection_string(),
                use_jsonb=True,
            )
    return _STORE


def retrieve(query: str, k: int) -> list[dict[str, Any]]:
    """Return the top-k chunks for the query as `[{text, metadata, score}, ...]`.

    `score` is the pgvector distance returned by langchain-postgres: smaller is
    closer (0 ≈ exact match). Chunks are ordered ascending by `score`. Returns
    an empty list when the query is blank or pgvector has no rows yet.
    """
    if not query or not query.strip():
        return []
    try:
        store = _get_store()
        scored: list[tuple[Document, float]] = store.similarity_search_with_score(query, k=k)
    except Exception:
        log.exception("pgvector similarity_search failed; returning no docs")
        return []
    return [
        {
            "text": doc.page_content,
            "metadata": dict(doc.metadata or {}),
            "score": float(score),
        }
        for doc, score in scored
    ]


def format_retrieved_as_docs_json(docs: list[dict[str, Any]]) -> str:
    """Group retrieved chunks by title to match the locked prompt shape.

    Shape (unchanged from the old doc-cache path so SYSTEM_PROMPT /
    USER_PROMPT_TEMPLATE stay identical):
      [{"title", "source", "document_type", "chunks": [text, ...]}, ...]
    """
    if not docs:
        return "[]"
    buckets: dict[str, dict[str, Any]] = {}
    for chunk in docs:
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
    return json.dumps(list(buckets.values()), ensure_ascii=False)
