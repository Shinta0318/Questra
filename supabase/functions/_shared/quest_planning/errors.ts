import { ProviderError, ProviderErrorCode } from "./contracts.ts";

export function classifyProviderError(status?: number, error?: unknown): ProviderError {
  const name = error instanceof Error ? error.name : "";
  let code: ProviderErrorCode = "unknown";
  if (name === "AbortError" || status === 408) code = "timeout";
  else if (status === 429) code = "rate_limited";
  else if (status === 413) code = "context_too_large";
  else if (status === 400 || status === 422) code = "malformed_output";
  else if (status === 503 || status === 502 || status === 504) code = "unavailable";
  else if (status === 499) code = "cancelled";
  return { code, retryable: ["timeout", "rate_limited", "unavailable"].includes(code), status, message: code };
}

export function shouldRetry(error: ProviderError, attempt: number, maxAttempts = 2) {
  return error.retryable && attempt < maxAttempts;
}
