// Real client for the chat-api (FastAPI + LangServe).
//
// LangServe mounts the chain at `path="/chat"` via `add_routes(...)` in
// `chat-api/app/main.py`, which exposes both:
//   POST {BASE}/chat/invoke   → JSON, one-shot
//   POST {BASE}/chat/stream   → Server-Sent Events stream (text/event-stream)
//
// We use the streaming endpoint so tokens show up as they are generated and we
// never hit CloudFront's 30s origin-response timeout on long completions.

const envBase = (import.meta.env.VITE_CHAT_API_URL as string | undefined)?.trim();
// Production build: empty → same origin (CloudFront serves UI and proxies /chat* to EC2).
const BASE_URL: string = (
  envBase && envBase.length > 0
    ? envBase
    : import.meta.env.PROD
      ? ""
      : "http://localhost:8000"
).replace(/\/+$/, "");

interface ErrorPayload {
  detail?: string | { message?: string };
  message?: string;
  status_code?: number;
}

function extractErrorMessage(status: number, body: ErrorPayload | string): string {
  if (typeof body === "string" && body) return `HTTP ${status}: ${body.slice(0, 300)}`;
  if (body && typeof body === "object") {
    const detail = body.detail;
    if (typeof detail === "string" && detail) return detail;
    if (detail && typeof detail === "object" && typeof detail.message === "string") {
      return detail.message;
    }
    if (typeof body.message === "string" && body.message) return body.message;
  }
  return `HTTP ${status}`;
}

export interface StreamChatOptions {
  onToken: (token: string) => void;
  signal?: AbortSignal;
}

/**
 * POST to /chat/stream and drive `onToken` as LangServe emits SSE events.
 *
 * LangServe's stream shape (one blank-line-separated block per event):
 *   event: data\n data: "<json-encoded string chunk>"\n\n
 *   event: error\n data: {"status_code": 429, "message": "..."}\n\n
 *   event: end\n data:\n\n
 *
 * We resolve when the stream ends cleanly and reject on `event: error` or a
 * non-200 response (e.g. a JSON error returned before the stream even opens).
 */
export async function streamChatMessage(
  sessionId: string,
  message: string,
  { onToken, signal }: StreamChatOptions,
): Promise<void> {
  const url = `${BASE_URL}/chat/stream`;

  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "text/event-stream",
      },
      body: JSON.stringify({ input: { session_id: sessionId, message } }),
      signal,
    });
  } catch (err) {
    if (err instanceof DOMException && err.name === "AbortError") throw err;
    throw new Error(
      `Could not reach chat-api at ${BASE_URL}. Is it running? (${
        err instanceof Error ? err.message : "network error"
      })`,
    );
  }

  if (!res.ok) {
    const contentType = res.headers.get("content-type") ?? "";
    const body: ErrorPayload | string = contentType.includes("application/json")
      ? ((await res.json()) as ErrorPayload)
      : await res.text();
    throw new Error(extractErrorMessage(res.status, body));
  }

  if (!res.body) {
    throw new Error("chat-api returned an empty stream.");
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder("utf-8");
  let buffer = "";

  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });

      // SSE event terminator is a blank line: \n\n or \r\n\r\n depending on the server.
      // sse_starlette emits CRLF, so match whichever comes first.
      let match: { index: number; length: number } | null;
      while ((match = findEventBoundary(buffer))) {
        const rawEvent = buffer.slice(0, match.index);
        buffer = buffer.slice(match.index + match.length);
        const parsed = parseSseEvent(rawEvent);
        if (!parsed) continue;

        if (parsed.event === "end") {
          return;
        }
        if (parsed.event === "error") {
          let payload: ErrorPayload | string = parsed.data;
          try {
            payload = JSON.parse(parsed.data) as ErrorPayload;
          } catch {
            // keep raw string
          }
          const status =
            typeof payload === "object" && typeof payload.status_code === "number"
              ? payload.status_code
              : 500;
          throw new Error(extractErrorMessage(status, payload));
        }
        if (parsed.event === "data") {
          const token = decodeDataChunk(parsed.data);
          if (token) onToken(token);
        }
      }
    }
  } finally {
    try {
      reader.releaseLock();
    } catch {
      // reader was already released
    }
  }
}

interface ParsedSseEvent {
  event: string;
  data: string;
}

function findEventBoundary(buffer: string): { index: number; length: number } | null {
  const crlf = buffer.indexOf("\r\n\r\n");
  const lf = buffer.indexOf("\n\n");
  if (crlf === -1 && lf === -1) return null;
  if (crlf !== -1 && (lf === -1 || crlf < lf)) {
    return { index: crlf, length: 4 };
  }
  return { index: lf, length: 2 };
}

function parseSseEvent(raw: string): ParsedSseEvent | null {
  const trimmed = raw.replace(/^\r?\n+/, "");
  if (!trimmed) return null;
  let event = "message";
  const dataLines: string[] = [];
  for (const line of trimmed.split(/\r?\n/)) {
    if (!line || line.startsWith(":")) continue;
    const colon = line.indexOf(":");
    const field = colon === -1 ? line : line.slice(0, colon);
    let value = colon === -1 ? "" : line.slice(colon + 1);
    if (value.startsWith(" ")) value = value.slice(1);
    if (field === "event") event = value;
    else if (field === "data") dataLines.push(value);
  }
  return { event, data: dataLines.join("\n") };
}

function decodeDataChunk(data: string): string {
  if (!data) return "";
  // LangServe JSON-encodes each chunk (so newlines, quotes, etc. survive).
  try {
    const parsed = JSON.parse(data);
    if (typeof parsed === "string") return parsed;
    if (parsed && typeof parsed === "object") {
      const maybe = (parsed as { content?: unknown; output?: unknown }).content
        ?? (parsed as { output?: unknown }).output;
      if (typeof maybe === "string") return maybe;
    }
    return "";
  } catch {
    return data;
  }
}
