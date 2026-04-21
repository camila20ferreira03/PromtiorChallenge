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
from typing import Any, AsyncIterator

from fastapi import HTTPException
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableGenerator
from langchain_openai import ChatOpenAI
from pydantic import BaseModel, Field

from app.config import LLM_MODEL, SESSION_MAX_REQUESTS
from app.docs import get_docs_json
from app.memory import append_and_maybe_summarize, format_context, load_context
from app.storage import QuotaExceededError, reserve_request_slot

log = logging.getLogger(__name__)


SYSTEM_PROMPT = """You are a chatbot assistant for Promtior.

You must answer questions only using the provided documents and conversation context.
Do not generate, assume, or infer any information that is not explicitly present in the sources.

Scope:
- Answer only questions related to the Promtior website and uploaded documentation.
- Typical questions include services offered and company information.
- Do not go outside this domain.

Rules:
- If the answer is not found in the documents, say clearly: "The information is not available in the provided sources."
- Do not hallucinate or create information.
- If the question is unclear, ask for clarification or suggest a better question.

Conversation:
- Use the conversation summary and recent messages to maintain context.
- Keep consistency with previous answers.

Documents:
- Use the retrieved document chunks (DOCS) as the source of truth.
- Base your answer strictly on those contents."""


USER_PROMPT_TEMPLATE = """INSTRUCTIONS:
You are a chatbot assistant for Promtior. Answer only using the provided documents and conversation context.

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
    return ChatOpenAI(model=LLM_MODEL, temperature=0.2, streaming=True)


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

        summary, recent = load_context(session_id)
        context_str = format_context(summary, recent)
        docs_json = get_docs_json()

        messages = _PROMPT.format_messages(
            retrieved_documents_json=docs_json,
            conversation_summary_and_recent_messages=context_str,
            user_question=message,
        )

        accumulated: list[str] = []
        async for chunk in llm.astream(messages):
            text = getattr(chunk, "content", "") or ""
            if text:
                accumulated.append(text)
                yield text

        full_reply = "".join(accumulated)
        try:
            append_and_maybe_summarize(session_id, message, full_reply)
        except Exception:
            log.exception("persist after stream failed for session %s", session_id)


chat_chain = RunnableGenerator(transform=_atransform).with_types(
    input_type=ChatInput, output_type=str
)
