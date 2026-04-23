"""DynamoDB persistence for chat sessions.

Schema (single table, PK/SK both strings):
  HISTORY item : PK=SESSION#<sid>, SK=HISTORY, messages=[{role,content,ts}], updated_at
  SUMMARY item : PK=SESSION#<sid>, SK=SUMMARY, summary, updated_at
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import TypedDict

from app.config import chat_table

HISTORY_SK = "HISTORY"
SUMMARY_SK = "SUMMARY"


class Message(TypedDict):
    role: str
    content: str
    ts: str


def _pk(session_id: str) -> str:
    return f"SESSION#{session_id}"


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_history(session_id: str) -> list[Message]:
    resp = chat_table().get_item(Key={"PK": _pk(session_id), "SK": HISTORY_SK})
    item = resp.get("Item") or {}
    return list(item.get("messages") or [])


def get_summary(session_id: str) -> str:
    resp = chat_table().get_item(Key={"PK": _pk(session_id), "SK": SUMMARY_SK})
    item = resp.get("Item") or {}
    return str(item.get("summary") or "")


def put_history(session_id: str, messages: list[Message]) -> None:
    chat_table().update_item(
        Key={"PK": _pk(session_id), "SK": HISTORY_SK},
        UpdateExpression="SET messages = :m, updated_at = :u",
        ExpressionAttributeValues={":m": messages, ":u": _now_iso()},
    )


def put_summary(session_id: str, summary: str) -> None:
    chat_table().put_item(
        Item={
            "PK": _pk(session_id),
            "SK": SUMMARY_SK,
            "summary": summary,
            "updated_at": _now_iso(),
        }
    )


def build_message(role: str, content: str) -> Message:
    return {"role": role, "content": content, "ts": _now_iso()}


def append_messages(session_id: str, new_messages: list[Message]) -> list[Message]:
    """Fetch HISTORY, extend it with new messages, persist, and return the result."""
    existing = get_history(session_id)
    combined = existing + new_messages
    put_history(session_id, combined)
    return combined
