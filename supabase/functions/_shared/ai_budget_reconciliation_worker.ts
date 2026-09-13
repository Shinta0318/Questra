export type ReconciliationAlertClaim = {
  alert_id: string;
  alert_kind: "queue_sla_breach" | "worker_failure";
  severity: "s1" | "s2";
  open_count: number;
  sla_breached_count: number;
  oldest_age_bucket:
    | "under_24_hours"
    | "one_to_three_days"
    | "over_three_days"
    | "unknown";
  delivery_attempts: number;
};

export type PrivacySafeAlertPayload = {
  payload_version: 1;
  alert_kind: ReconciliationAlertClaim["alert_kind"];
  severity: ReconciliationAlertClaim["severity"];
  open_count: number;
  sla_breached_count: number;
  oldest_age_bucket: ReconciliationAlertClaim["oldest_age_bucket"];
};

const scheduleKeyPattern = /^[A-Za-z0-9:_.-]{8,100}$/;

export function isValidScheduleKey(value: unknown): value is string {
  return typeof value === "string" && scheduleKeyPattern.test(value);
}

export function constantTimeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  let difference = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let index = 0; index < length; index += 1) {
    difference |= (a[index] ?? 0) ^ (b[index] ?? 0);
  }
  return difference === 0;
}

export function classifyReconciliationError(
  error: unknown,
):
  | "timeout"
  | "rate_limited"
  | "database_unavailable"
  | "permission_denied"
  | "invalid_configuration"
  | "unknown" {
  const value = String(error).toLowerCase();
  if (value.includes("timeout") || value.includes("abort")) return "timeout";
  if (value.includes("429") || value.includes("rate")) return "rate_limited";
  if (value.includes("permission") || value.includes("service_role_required")) {
    return "permission_denied";
  }
  if (value.includes("configuration") || value.includes("missing")) {
    return "invalid_configuration";
  }
  if (
    value.includes("fetch") ||
    value.includes("connect") ||
    value.includes("database") ||
    value.includes("unavailable")
  ) {
    return "database_unavailable";
  }
  return "unknown";
}

export function classifyAlertDeliveryError(
  error: unknown,
): "timeout" | "http_error" | "invalid_endpoint" | "unavailable" | "unknown" {
  const value = String(error).toLowerCase();
  if (value.includes("timeout") || value.includes("abort")) return "timeout";
  if (value.includes("invalid_endpoint")) return "invalid_endpoint";
  if (value.includes("http_error")) return "http_error";
  if (value.includes("fetch") || value.includes("connect")) return "unavailable";
  return "unknown";
}

export function parseHttpsEndpoint(value: string): URL | null {
  try {
    const endpoint = new URL(value);
    return endpoint.protocol === "https:" ? endpoint : null;
  } catch (_) {
    return null;
  }
}

export function buildPrivacySafeAlertPayload(
  alert: ReconciliationAlertClaim,
): PrivacySafeAlertPayload {
  return {
    payload_version: 1,
    alert_kind: alert.alert_kind,
    severity: alert.severity,
    open_count: boundedCount(alert.open_count),
    sla_breached_count: boundedCount(alert.sla_breached_count),
    oldest_age_bucket: alert.oldest_age_bucket,
  };
}

function boundedCount(value: number): number {
  if (!Number.isFinite(value) || value < 0) return 0;
  return Math.min(Math.trunc(value), 1_000_000);
}
