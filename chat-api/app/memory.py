"""Conversation memory: load prior context, append turns, summarize when long."""
from __future__ import annotations

import logging

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI

from app.config import HISTORY_KEEP_RECENT, HISTORY_MAX_MESSAGES, SUMMARY_MODEL
from app.storage import (
    Message,
    append_messages,
    build_message,
    get_history,
    get_summary,
    put_history,
    put_summary,
)

log = logging.getLogger(__name__)

_SUMMARIZER_SYSTEM = (
    "You compress chat history. Given a previous summary and a batch of older "
    "messages, produce a concise, faithful running summary in under 200 words. "
    "Preserve factual details, user intent, and unresolved questions."
)


def load_context(session_id: str) -> tuple[str, list[Message]]:
    """Return (summary, recent_messages). Recent is capped to HISTORY_KEEP_RECENT."""
    summary = get_summary(session_id)
    history = get_history(session_id)
    recent = history[-HISTORY_KEEP_RECENT:] if history else []
    return summary, recent


def format_context(summary: str, recent: list[Message]) -> str:
    """Flatten (summary, recent) into the single string the locked prompt expects."""
    parts: list[str] = []
    parts.append(f"Summary: {summary.strip()}" if summary.strip() else "Summary: (none)")
    if recent:
        parts.append("Recent messages:")
        for msg in recent:
            role = msg.get("role", "user")
            content = (msg.get("content") or "").strip()
            parts.append(f"{role}: {content}")
    return "\n".join(parts)


def append_and_maybe_summarize(
    session_id: str, user_msg: str, assistant_msg: str
) -> None:
    """Persist the new turn; summarize-and-trim when history grows past threshold."""
    new_messages = [
        build_message("user", user_msg),
        build_message("assistant", assistant_msg),
    ]
    combined = append_messages(session_id, new_messages)

    if len(combined) <= HISTORY_MAX_MESSAGES:
        return

    drop_count = len(combined) - HISTORY_KEEP_RECENT
    to_summarize = combined[:drop_count]
    kept = combined[drop_count:]

    prev_summary = get_summary(session_id)
    new_summary = _summarize(prev_summary, to_summarize)

    put_summary(session_id, new_summary)
    put_history(session_id, kept)


def _summarize(prev_summary: str, messages: list[Message]) -> str:
    llm = ChatOpenAI(model=SUMMARY_MODEL, temperature=0)

    transcript_lines = []
    for msg in messages:
        role = msg.get("role", "user")
        content = (msg.get("content") or "").strip()
        transcript_lines.append(f"{role}: {content}")
    transcript = "\n".join(transcript_lines)

    payload = (
        f"Previous summary:\n{prev_summary or '(none)'}\n\n"
        f"Older messages to fold in:\n{transcript}\n\n"
        "Return only the updated summary text."
    )

    try:
        response = llm.invoke(
            [SystemMessage(content=_SUMMARIZER_SYSTEM), HumanMessage(content=payload)]
        )
        return (response.content or "").strip()
    except Exception as exc:
        body = _openai_error_body(exc)
        log.exception(
            "summarizer failed; keeping previous summary. "
            "model=%s payload_chars=%d prev_summary_chars=%d messages=%d body=%s",
            SUMMARY_MODEL,
            len(payload),
            len(prev_summary or ""),
            len(messages),
            body,
        )
        return prev_summary


def _openai_error_body(exc: BaseException) -> str:
    """Best-effort extraction of the OpenAI error body (what actually tells you why it 400'd)."""
    response = getattr(exc, "response", None)
    if response is not None:
        text = getattr(response, "text", None)
        if text:
            return str(text)[:2000]
    body = getattr(exc, "body", None)
    if body:
        return str(body)[:2000]
    return str(exc)[:2000]
