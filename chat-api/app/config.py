"""Runtime configuration shared across the chat-api modules.

Reads environment variables once at import time. Secrets Manager lookup for the
OpenAI key happens in load_openai_key() and is called by main.py at startup so
langchain-openai picks it up via the standard OPENAI_API_KEY env var.
"""
from __future__ import annotations

import json
import logging
import os
from functools import lru_cache

import boto3

log = logging.getLogger(__name__)

AWS_REGION: str = os.getenv("AWS_REGION", "us-east-1")

CHAT_TABLE_NAME: str = os.environ.get("CHAT_TABLE_NAME", "")
PROCESSED_BUCKET: str = os.environ.get("PROCESSED_BUCKET", "")
OPENAI_SECRET_ARN: str = os.environ.get("OPENAI_SECRET_ARN", "")

LLM_MODEL: str = os.getenv("LLM_MODEL", "gpt-4o-mini")
SUMMARY_MODEL: str = os.getenv("SUMMARY_MODEL", "gpt-4o-mini")

HISTORY_MAX_MESSAGES: int = int(os.getenv("HISTORY_MAX_MESSAGES", "12"))
HISTORY_KEEP_RECENT: int = int(os.getenv("HISTORY_KEEP_RECENT", "6"))
SESSION_MAX_REQUESTS: int = int(os.getenv("SESSION_MAX_REQUESTS", "10"))


@lru_cache(maxsize=1)
def dynamodb_resource():
    return boto3.resource("dynamodb", region_name=AWS_REGION)


@lru_cache(maxsize=1)
def chat_table():
    if not CHAT_TABLE_NAME:
        raise RuntimeError("CHAT_TABLE_NAME is not set")
    return dynamodb_resource().Table(CHAT_TABLE_NAME)


@lru_cache(maxsize=1)
def s3_client():
    return boto3.client("s3", region_name=AWS_REGION)


@lru_cache(maxsize=1)
def secrets_client():
    return boto3.client("secretsmanager", region_name=AWS_REGION)


def load_openai_key() -> None:
    """Populate os.environ['OPENAI_API_KEY'] from Secrets Manager.

    No-op when OPENAI_SECRET_ARN is unset (useful for local dev where the env
    var is already exported). Supports both plain-string secrets and JSON
    secrets of the form {"OPENAI_API_KEY": "sk-..."}.
    """
    if os.getenv("OPENAI_API_KEY"):
        return
    if not OPENAI_SECRET_ARN:
        log.warning("OPENAI_SECRET_ARN not set; skipping secret load")
        return

    resp = secrets_client().get_secret_value(SecretId=OPENAI_SECRET_ARN)
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
