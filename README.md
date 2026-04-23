# Promtior Challenge

Retrieval-augmented chatbot about Promtior. The user asks a question in a web UI; the backend embeds the question, pulls the most relevant chunks from a vector database, feeds them to an LLM, and streams the answer back.


## Repository layout

- `chat-api/` — FastAPI + LangServe backend. Handles `/chat/invoke` and `/chat/stream`, retrieval, prompt assembly, session memory and quota.
- `frontend/` — Vite + React + TypeScript chat UI.
- `lambda/document_processor/` — S3-triggered Lambda. Input: raw PDF/HTML. Output: JSONL of text chunks with metadata.
- `lambda/embedding_processor/` — S3-triggered Lambda. Input: chunk JSONL. Output: rows in pgvector (idempotent per `source_id`).
- `infra/` — Terraform root module and per-service submodules (S3, RDS, DynamoDB, EC2, ECR, CloudFront, Lambda, network).
- `scripts/` — Local helper scripts (untracked).

## Main components

- **Chat API** (`chat-api/app/`): `main.py` is the FastAPI entrypoint, `chain.py` is the LangChain runnable that drives each turn, `vectors.py` wraps the pgvector retriever, `memory.py` + `storage.py` manage the DynamoDB-backed session state, `config.py` centralises all env vars.
- **Document processor Lambda** (`lambda/document_processor/handler.py`): detects PDF vs HTML, extracts text, chunks with `RecursiveCharacterTextSplitter`, writes one `.chunks.jsonl` file per source to the processed bucket.
- **Embedding processor Lambda** (`lambda/embedding_processor/handler.py`): reads the JSONL, calls OpenAI embeddings, deletes any existing rows for the same `source_id`, inserts the new ones into the `promtior_docs` pgvector collection.
- **Frontend** (`frontend/src/`): one active conversation, persistent `session_id` in `localStorage`, streams tokens from the backend.

## Data model

- **Raw S3 bucket** — user-uploaded PDF/HTML.
- **Processed S3 bucket** — `processed/<source>.chunks.jsonl`, one JSON object per line: `{ "text": "...", "metadata": { "source_id", "chunk_id", "title", "source_key", "document_type", "page_number", ... } }`.
- **pgvector** — `langchain_pg_embedding` rows grouped under the collection `promtior_docs`.
- **DynamoDB chat table** — one item per session with the rolling summary, recent messages, and request count.
- **Secrets Manager** — OpenAI API key and RDS credentials.

## Request flow

1. Frontend sends `POST /chat/stream` with `{ session_id, message }`.
2. Backend reserves a request slot in DynamoDB (atomic conditional update; returns 429 if the quota is exhausted).
3. Backend loads the conversation summary + recent messages, embeds the question, and retrieves the top `RETRIEVAL_K` chunks from pgvector.
4. Backend renders the locked prompt (`SYSTEM_PROMPT` + `USER_PROMPT_TEMPLATE`) with the retrieved chunks as `DOCS`, and streams the LLM response.
5. After the stream ends, the user message and assistant reply are appended to the session; if history exceeds `HISTORY_MAX_MESSAGES`, it is folded into the summary.

## Key environment variables

Declared in `chat-api/app/config.py` and the two Lambda handlers:

- `OPENAI_SECRET_ARN`, `DB_SECRET_ARN` — Secrets Manager ARNs (falls back to `OPENAI_API_KEY` / `DB_URL` for local dev).
- `CHAT_TABLE_NAME` — DynamoDB table for sessions.
- `LLM_MODEL`, `SUMMARY_MODEL`, `EMBEDDING_MODEL`.
- `PGVECTOR_COLLECTION`, `RETRIEVAL_K`.
- `HISTORY_MAX_MESSAGES`, `HISTORY_KEEP_RECENT`, `SESSION_MAX_REQUESTS`.
- `CORS_ALLOW_ORIGINS`.
