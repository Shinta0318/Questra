export function authErrorCode(payload: Record<string, unknown>): string | null {
  if (typeof payload.error_code === "string") return payload.error_code;
  return typeof payload.code === "string" ? payload.code : null;
}

export function classifyAuthFailure(
  status: number,
  payload: Record<string, unknown>,
): "unavailable" | "rate_limited" | "invalid_credentials" | "unconfirmed" | "other" {
  if (status >= 500) return "unavailable";
  if (status === 429) return "rate_limited";
  const code = authErrorCode(payload);
  if (code === "invalid_credentials") return "invalid_credentials";
  if (code === "email_not_confirmed") return "unconfirmed";
  return "other";
}
