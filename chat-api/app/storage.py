"""DynamoDB persistence for chat sessions.

Schema (single table, PK/SK both strings):
  HISTORY item : PK=SESSION#<sid>, SK=HISTORY, messages=[{role,content,ts}], request_count, updated_at
  SUMMARY item : PK=SESSION#<sid>, SK=SUMMARY, summary, updated_at
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, TypedDict

from botocore.exceptions import ClientError

from app.config import chat_table

log = logging.getLogger(__name__)

HISTORY_SK = "HISTORY"
SUMMARY_SK = "SUMMARY"


class Message(TypedDict):
    role: str
    content: str
    ts: str


class QuotaExceededError(RuntimeError):
    """Raised when a session_id has reached its lifetime request cap."""


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
    """Overwrite the messages list but preserve the existing request_count."""
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


def reserve_request_slot(session_id: str, limit: int) -> int:
    """Atomically bump request_count on the HISTORY item; reject past the cap.

    Uses a conditional UpdateItem so quota is enforced even under concurrent
    requests. Raises QuotaExceededError when the session has reached its cap.
    """
    try:
        resp = chat_table().update_item(
            Key={"PK": _pk(session_id), "SK": HISTORY_SK},
            UpdateExpression="ADD request_count :one SET updated_at = :u",
            ConditionExpression=(
                "attribute_not_exists(request_count) OR request_count < :limit"
            ),
            ExpressionAttributeValues={
                ":one": 1,
                ":limit": limit,
                ":u": _now_iso(),
            },
            ReturnValues="UPDATED_NEW",
        )
    except ClientError as err:
        if err.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            raise QuotaExceededError(
                f"session {session_id} reached request limit {limit}"
            ) from err
        raise

    return int(resp.get("Attributes", {}).get("request_count", 0))


def get_request_count(session_id: str) -> int:
    resp = chat_table().get_item(
        Key={"PK": _pk(session_id), "SK": HISTORY_SK},
        ProjectionExpression="request_count",
    )
    item = resp.get("Item") or {}
    return int(item.get("request_count") or 0)


def build_message(role: str, content: str) -> Message:
    return {"role": role, "content": content, "ts": _now_iso()}


def append_messages(session_id: str, new_messages: list[Message]) -> list[Message]:
    """Fetch HISTORY, extend it with new messages, persist, and return the result."""
    existing = get_history(session_id)
    combined = existing + new_messages
    put_history(session_id, combined)
    return combined
