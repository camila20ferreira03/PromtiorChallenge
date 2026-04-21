const STORAGE_KEY = "promtior_chat_session_id";

function randomId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `s_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
}

function read(): string | null {
  try {
    return window.localStorage.getItem(STORAGE_KEY);
  } catch {
    return null;
  }
}

function write(id: string): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, id);
  } catch {
    /* storage blocked; session survives only in memory */
  }
}

export function ensureSessionId(): string {
  const existing = read();
  if (existing) return existing;
  const fresh = randomId();
  write(fresh);
  return fresh;
}

export function rotateSessionId(): string {
  const fresh = randomId();
  write(fresh);
  return fresh;
}
