"""FastAPI entrypoint wiring LangServe, doc cache warmup, and OpenAI key load."""
from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from langserve import add_routes

from app.chain import chat_chain
from app.config import (
    CHAT_TABLE_NAME,
    LLM_MODEL,
    PROCESSED_BUCKET,
    SESSION_MAX_REQUESTS,
    load_openai_key,
)
from app.docs import get_chunk_count, load_docs
from app.storage import get_request_count

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("chat-api")


@asynccontextmanager
async def lifespan(_: FastAPI):
    load_openai_key()
    try:
        count = load_docs()
        log.info("doc cache warmed: %d chunks", count)
    except Exception:
        log.exception("doc cache warmup failed; continuing with empty cache")
    yield


app = FastAPI(title="Promtior Chat API", version="0.1.0", lifespan=lifespan)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/config")
def config() -> dict[str, object]:
    return {
        "aws_region": os.getenv("AWS_REGION"),
        "chat_table_name": CHAT_TABLE_NAME,
        "processed_bucket": PROCESSED_BUCKET,
        "llm_model": LLM_MODEL,
        "session_max_requests": SESSION_MAX_REQUESTS,
        "cached_chunks": get_chunk_count(),
    }


@app.get("/sessions/{session_id}/usage")
def session_usage(session_id: str) -> dict[str, object]:
    used = get_request_count(session_id)
    return {
        "session_id": session_id,
        "used": used,
        "limit": SESSION_MAX_REQUESTS,
        "remaining": max(SESSION_MAX_REQUESTS - used, 0),
    }


@app.post("/admin/refresh-docs")
def refresh_docs() -> dict[str, int]:
    count = load_docs()
    return {"chunks": count}


add_routes(
    app,
    chat_chain,
    path="/chat",
    playground_type="chat",
)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8000")),
        reload=False,
    )
