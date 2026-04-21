// Real client for the chat-api (FastAPI + LangServe).
//
// LangServe mounts the chain at `path="/chat"` via `add_routes(...)` in
// `chat-api/app/main.py`, so the JSON contract is:
//   POST {BASE}/chat/invoke
//   body: { "input": { "session_id": string, "message": string } }
//   200 : { "output": string, "metadata": {...}, ... }

const BASE_URL: string = (
  (import.meta.env.VITE_CHAT_API_URL as string | undefined) ??
  "http://localhost:8000"
).replace(/\/+$/, "");

interface InvokeResponse {
  output?: string;
  detail?: string | { message?: string };
}

function extractErrorMessage(status: number, body: InvokeResponse | string): string {
  if (typeof body === "string" && body) return `HTTP ${status}: ${body.slice(0, 300)}`;
  if (body && typeof body === "object") {
    const detail = body.detail;
    if (typeof detail === "string" && detail) return detail;
    if (detail && typeof detail === "object" && typeof detail.message === "string") {
      return detail.message;
    }
  }
  return `HTTP ${status}`;
}

export async function sendChatMessage(
  sessionId: string,
  message: string,
  signal?: AbortSignal,
): Promise<string> {
  const url = `${BASE_URL}/chat/invoke`;

  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
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

  const contentType = res.headers.get("content-type") ?? "";
  const payload: InvokeResponse | string = contentType.includes("application/json")
    ? ((await res.json()) as InvokeResponse)
    : await res.text();

  if (!res.ok) {
    throw new Error(extractErrorMessage(res.status, payload));
  }

  if (typeof payload === "object" && typeof payload.output === "string") {
    return payload.output;
  }
  throw new Error("Unexpected response shape from chat-api (missing `output`).");
}
