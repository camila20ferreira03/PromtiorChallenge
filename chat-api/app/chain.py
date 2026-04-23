"""LangChain runnable that fronts LangServe /chat/invoke and /chat/stream.

Design:
  1. Enforce per-session quota (atomic conditional UpdateItem).
  2. Load conversation context and the cached S3 docs.
  3. Render the locked prompt (see SYSTEM_PROMPT / USER_PROMPT_TEMPLATE).
  4. Stream tokens from the LLM while accumulating the full reply.
  5. After the stream drains (same code path for invoke and stream), persist
     the user message + assistant reply and run summarize-if-overflow.
"""
from __future__ import annotations

import logging
import time
from typing import Any, AsyncIterator

from fastapi import HTTPException
from openai import (
    APIConnectionError,
    APIError,
    APITimeoutError,
    AuthenticationError,
    BadRequestError,
    PermissionDeniedError,
    RateLimitError,
)
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableGenerator
from langchain_openai import ChatOpenAI
from pydantic import BaseModel, Field

from app.config import LLM_MODEL, RETRIEVAL_K, SESSION_MAX_REQUESTS
from app.memory import append_and_maybe_summarize, format_context, load_context
from app.storage import QuotaExceededError, reserve_request_slot
from app.vectors import format_retrieved_as_docs_json, retrieve

log = logging.getLogger(__name__)


SYSTEM_PROMPT = """INSTRUCTIONS: You are a chatbot assistant for Promtior.

You must answer questions only using the provided documents and conversation context.
Do not generate, assume, or infer any information that is not explicitly present in the sources.

Scope:
- Answer questions related to the Promtior website and uploaded documentation.
- Typical questions include services offered and company information.
- Do not go outside this domain.

Rules:
- If the question is unclear, incomplete, or too vague , do NOT immediately reject it.
  Instead, respond politely and guide the user by:
    - Asking for clarification, OR
    - Suggesting example questions related to Promtior (e.g., services, company information), OR
    - Providing a brief introduction of what the assistant can help with based on the available documents.

- If the question is unrelated to Promtior or out the scope, clearly state that you can only answer questions about Promtior.

- If the answer is not found in the documents, say clearly that you do not have that information available in the provided sources.

- Do not hallucinate or create information under any circumstances.

Conversation:
- Use the conversation summary and recent messages to maintain context.
- Keep consistency with previous answers.

Documents:
- Use the retrieved document chunks (DOCS) as the single source of truth.
- Base your answer strictly on those contents.

Behavior Guidelines:
- Be helpful but strict about the scope.
- Prefer asking for clarification over rejecting the user too early.
- Maintain a professional and concise tone."""


USER_PROMPT_TEMPLATE = """
DOCS:
{retrieved_documents_json}

CONVERSATION CONTEXT:
{conversation_summary_and_recent_messages}

USER INPUT:
{user_question}"""


_PROMPT = ChatPromptTemplate.from_messages(
    [("system", SYSTEM_PROMPT), ("human", USER_PROMPT_TEMPLATE)]
)


class ChatInput(BaseModel):
    session_id: str = Field(..., description="Client-supplied conversation identifier.")
    message: str = Field(..., description="User message to answer.")


def _coerce_input(payload: Any) -> dict[str, str]:
    if isinstance(payload, ChatInput):
        return payload.model_dump()
    if hasattr(payload, "model_dump"):
        return payload.model_dump()
    if isinstance(payload, dict):
        return {"session_id": payload["session_id"], "message": payload["message"]}
    raise HTTPException(status_code=400, detail="invalid chat payload")


def _build_llm() -> ChatOpenAI:
    # stream_usage=True makes OpenAI emit a final chunk carrying input/output token
    # counts, which we pull off in _atransform to log per-request token usage.
    return ChatOpenAI(model=LLM_MODEL, temperature=0.2, streaming=True, stream_usage=True)


def _log_retrieval(session_id: str, query: str, retrieved: list[dict[str, Any]], elapsed_ms: float) -> None:
    """Emit one structured line per /chat so we can see which chunks fed the prompt."""
    preview = []
    for i, chunk in enumerate(retrieved):
        meta = chunk.get("metadata") or {}
        preview.append(
            {
                "rank": i,
                "score": round(float(chunk.get("score", 0.0)), 4),
                "source_id": meta.get("source_id"),
                "title": meta.get("title") or meta.get("source_key"),
                "document_type": meta.get("document_type"),
                "preview": (chunk.get("text") or "")[:80].replace("\n", " "),
            }
        )
    log.info(
        "retrieval session=%s k=%d elapsed_ms=%.1f query=%r chunks=%s",
        session_id,
        len(retrieved),
        elapsed_ms,
        query[:120],
        preview,
    )


def _openai_user_message(exc: BaseException) -> str:
    """Best-effort user-facing string from OpenAI SDK errors."""
    body = getattr(exc, "body", None)
    if isinstance(body, dict):
        err = body.get("error")
        if isinstance(err, dict) and err.get("message"):
            return str(err["message"])
    msg = getattr(exc, "message", None)
    return str(msg) if msg else str(exc)


def _http_exception_from_openai(exc: BaseException) -> HTTPException:
    """Map OpenAI client errors to HTTP status + detail (LangServe returns JSON, not 500)."""
    message = _openai_user_message(exc)
    if isinstance(exc, AuthenticationError):
        log.warning("OpenAI auth failed: %s", exc)
        return HTTPException(
            status_code=401,
            detail=message or "OpenAI API key invalid or missing.",
        )
    if isinstance(exc, PermissionDeniedError):
        return HTTPException(status_code=403, detail=message or "OpenAI permission denied.")
    if isinstance(exc, BadRequestError):
        return HTTPException(status_code=400, detail=message or "Invalid OpenAI request.")
    if isinstance(exc, RateLimitError):
        log.warning("OpenAI rate limit / quota: %s", message)
        return HTTPException(
            status_code=429,
            detail=message
            or "OpenAI rate limit or quota exceeded. Check billing and usage at https://platform.openai.com/account/billing",
        )
    if isinstance(exc, APIConnectionError):
        log.warning("OpenAI connection error: %s", exc)
        return HTTPException(
            status_code=503,
            detail="Cannot reach OpenAI. Check network and try again.",
        )
    if isinstance(exc, APITimeoutError):
        return HTTPException(status_code=504, detail="OpenAI request timed out.")
    if isinstance(exc, APIError):
        code = getattr(exc, "status_code", None)
        if not isinstance(code, int) or code < 400 or code >= 600:
            code = 502
        return HTTPException(status_code=code, detail=message or "OpenAI API error.")
    log.exception("Unexpected error calling OpenAI")
    return HTTPException(status_code=502, detail="LLM provider error.")


async def _atransform(
    input_stream: AsyncIterator[Any],
) -> AsyncIterator[str]:
    llm = _build_llm()

    async for raw in input_stream:
        data = _coerce_input(raw)
        session_id = data["session_id"].strip()
        message = data["message"]

        if not session_id:
            raise HTTPException(status_code=400, detail="session_id is required")
        if not message or not message.strip():
            raise HTTPException(status_code=400, detail="message is required")

        try:
            reserve_request_slot(session_id, SESSION_MAX_REQUESTS)
        except QuotaExceededError:
            raise HTTPException(
                status_code=429,
                detail=f"session request limit reached ({SESSION_MAX_REQUESTS})",
            )

        t0 = time.perf_counter()
        summary, recent = load_context(session_id)
        context_str = format_context(summary, recent)

        t_retr_start = time.perf_counter()
        retrieved = retrieve(message, k=RETRIEVAL_K)
        t_retr_ms = (time.perf_counter() - t_retr_start) * 1000
        _log_retrieval(session_id, message, retrieved, t_retr_ms)

        docs_json = format_retrieved_as_docs_json(retrieved)

        messages = _PROMPT.format_messages(
            retrieved_documents_json=docs_json,
            conversation_summary_and_recent_messages=context_str,
            user_question=message,
        )

        accumulated: list[str] = []
        input_tokens = output_tokens = total_tokens = 0
        t_llm_start = time.perf_counter()
        try:
            async for chunk in llm.astream(messages):
                text = getattr(chunk, "content", "") or ""
                if text:
                    accumulated.append(text)
                    yield text
                # OpenAI emits usage only on the final chunk when stream_usage=True.
                usage = getattr(chunk, "usage_metadata", None)
                if usage:
                    input_tokens = int(usage.get("input_tokens", 0) or 0)
                    output_tokens = int(usage.get("output_tokens", 0) or 0)
                    total_tokens = int(usage.get("total_tokens", input_tokens + output_tokens) or 0)
        except (RateLimitError, AuthenticationError, PermissionDeniedError, BadRequestError) as e:
            raise _http_exception_from_openai(e) from e
        except APIConnectionError as e:
            raise _http_exception_from_openai(e) from e
        except APITimeoutError as e:
            raise _http_exception_from_openai(e) from e
        except APIError as e:
            raise _http_exception_from_openai(e) from e

        t_llm_ms = (time.perf_counter() - t_llm_start) * 1000
        t_total_ms = (time.perf_counter() - t0) * 1000
        full_reply = "".join(accumulated)

        log.info(
            "chat_done session=%s model=%s k=%d retrieval_ms=%.1f llm_ms=%.1f total_ms=%.1f "
            "input_tokens=%d output_tokens=%d total_tokens=%d reply_chars=%d",
            session_id,
            LLM_MODEL,
            len(retrieved),
            t_retr_ms,
            t_llm_ms,
            t_total_ms,
            input_tokens,
            output_tokens,
            total_tokens,
            len(full_reply),
        )

        try:
            append_and_maybe_summarize(session_id, message, full_reply)
        except Exception:
            log.exception("persist after stream failed for session %s", session_id)


chat_chain = RunnableGenerator(transform=_atransform).with_types(
    input_type=ChatInput, output_type=str
)
