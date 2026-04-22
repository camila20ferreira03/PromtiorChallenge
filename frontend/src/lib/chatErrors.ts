/** Matches FastAPI 429 from `chain.reserve_request_slot` (session request cap). */
export function isSessionRequestLimitError(message: string): boolean {
  const m = message.toLowerCase();
  return (
    m.includes("session request limit") ||
    m.includes("http 429") ||
    m.includes("request limit")
  );
}
