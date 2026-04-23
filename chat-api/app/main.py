"""FastAPI entrypoint wiring LangServe and the OpenAI key load."""
from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from langserve import add_routes

from app.chain import chat_chain
from app.config import (
    CHAT_TABLE_NAME,
    EMBEDDING_MODEL,
    LLM_MODEL,
    PGVECTOR_COLLECTION,
    RETRIEVAL_K,
    load_openai_key,
)

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("chat-api")


@asynccontextmanager
async def lifespan(_: FastAPI):
    load_openai_key()
    yield


app = FastAPI(title="Promtior Chat API", version="0.2.0", lifespan=lifespan)

_cors_origins_env = os.getenv("CORS_ALLOW_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173")
_cors_origins = [o.strip() for o in _cors_origins_env.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins or ["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/config")
def config() -> dict[str, object]:
    return {
        "aws_region": os.getenv("AWS_REGION"),
        "chat_table_name": CHAT_TABLE_NAME,
        "llm_model": LLM_MODEL,
        "embedding_model": EMBEDDING_MODEL,
        "pgvector_collection": PGVECTOR_COLLECTION,
        "retrieval_k": RETRIEVAL_K,
    }


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
