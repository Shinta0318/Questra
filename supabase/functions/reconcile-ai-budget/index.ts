import { createClient } from "npm:@supabase/supabase-js@2.112.4";
import { jsonResponse } from "../_shared/http.ts";
import {
  buildPrivacySafeAlertPayload,
  classifyAlertDeliveryError,
  classifyReconciliationError,
  constantTimeEqual,
  isValidScheduleKey,
  parseHttpsEndpoint,
  type ReconciliationAlertClaim,
} from "../_shared/ai_budget_reconciliation_worker.ts";

const defaultTimeoutMs = 20_000;

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, { status: 405 });
  }

  const expectedSecret = Deno.env.get("AI_RECONCILIATION_WORKER_SECRET") ?? "";
  const suppliedSecret = request.headers.get("x-worker-secret") ?? "";
  if (
    expectedSecret.length < 32 ||
    !constantTimeEqual(expectedSecret, suppliedSecret)
  ) {
    return jsonResponse({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await readJsonObject(request);
  const scheduleKey = body?.schedule_key;
  if (!isValidScheduleKey(scheduleKey)) {
    return jsonResponse({ error: "Invalid schedule request" }, { status: 400 });
  }

  const client = adminClient();
  const timeoutMs = configuredTimeoutMs();
  try {
    const { data, error } = await client
      .rpc("run_ai_budget_reconciliation_scheduler", {
        p_schedule_key: scheduleKey,
      })
      .abortSignal(AbortSignal.timeout(timeoutMs));
    if (error) throw error;

    const result = safeRunResult(data);
    if (result.disabled === true) {
      return jsonResponse({ status: "disabled", reconciliation: result });
    }

    const delivery = await deliverPendingAlerts(client, timeoutMs);
    return jsonResponse({
      status: "completed",
      reconciliation: result,
      alert_delivery: delivery,
    });
  } catch (error) {
    const errorCode = classifyReconciliationError(error);
    await recordFailure(client, scheduleKey, errorCode, timeoutMs);
    return jsonResponse(
      {
        error: "Reconciliation is temporarily unavailable",
        retry_after_seconds: 300,
      },
      { status: 503, headers: { "Retry-After": "300" } },
    );
  }
});

async function deliverPendingAlerts(
  client: ReturnType<typeof adminClient>,
  timeoutMs: number,
) {
  const rawEndpoint = Deno.env.get("AI_RECONCILIATION_ALERT_WEBHOOK_URL") ?? "";
  if (!rawEndpoint) {
    return { status: "not_configured", delivered: 0, retry_scheduled: 0 };
  }
  const endpoint = parseHttpsEndpoint(rawEndpoint);
  const signingSecret = Deno.env.get("AI_RECONCILIATION_ALERT_WEBHOOK_SECRET") ?? "";
  if (!endpoint || signingSecret.length < 32) {
    return { status: "invalid_configuration", delivered: 0, retry_scheduled: 0 };
  }

  const { data, error } = await client
    .rpc("claim_ai_budget_reconciliation_sla_alerts", { p_limit: 10 })
    .abortSignal(AbortSignal.timeout(timeoutMs));
  if (error) throw error;

  const alerts = (data ?? []) as ReconciliationAlertClaim[];
  let delivered = 0;
  let retryScheduled = 0;
  for (const alert of alerts) {
    try {
      const payload = buildPrivacySafeAlertPayload(alert);
      const encoded = JSON.stringify(payload);
      const signature = await signPayload(encoded, signingSecret);
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-questra-signature": `v1=${signature}`,
        },
        body: encoded,
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (!response.ok) throw new Error("http_error");
      await resolveAlert(client, alert.alert_id, true, null, timeoutMs);
      delivered += 1;
    } catch (error) {
      await resolveAlert(
        client,
        alert.alert_id,
        false,
        classifyAlertDeliveryError(error),
        timeoutMs,
      );
      retryScheduled += 1;
    }
  }
  return { status: "processed", delivered, retry_scheduled: retryScheduled };
}

async function resolveAlert(
  client: ReturnType<typeof adminClient>,
  alertId: string,
  delivered: boolean,
  errorCode: string | null,
  timeoutMs: number,
) {
  const { error } = await client
    .rpc("resolve_ai_budget_reconciliation_sla_alert", {
      p_alert_id: alertId,
      p_delivered: delivered,
      p_error_code: errorCode,
    })
    .abortSignal(AbortSignal.timeout(timeoutMs));
  if (error) throw error;
}

async function recordFailure(
  client: ReturnType<typeof adminClient>,
  scheduleKey: string,
  errorCode: string,
  timeoutMs: number,
) {
  try {
    await client
      .rpc("record_ai_budget_reconciliation_worker_failure", {
        p_schedule_key: scheduleKey,
        p_error_code: errorCode,
      })
      .abortSignal(AbortSignal.timeout(timeoutMs));
  } catch (_) {
    // The caller receives a retryable response even when the database is offline.
  }
}

async function signPayload(payload: string, secret: string) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  return Array.from(new Uint8Array(signature))
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

function safeRunResult(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const source = value as Record<string, unknown>;
  const allowed = [
    "executed",
    "disabled",
    "idempotent",
    "retry_scheduled",
    "retry_after_seconds",
    "processed_count",
    "reconciled_count",
    "operator_review_count",
    "recovered_claim_count",
    "open_count",
    "sla_breached_count",
    "sla_alert_created",
    "pending_alert_count",
  ];
  return Object.fromEntries(
    allowed.filter((key) => Object.hasOwn(source, key)).map((key) => [key, source[key]]),
  );
}

async function readJsonObject(request: Request) {
  try {
    const value = await request.json();
    return value && typeof value === "object" && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch (_) {
    return null;
  }
}

function configuredTimeoutMs() {
  const value = Number(Deno.env.get("AI_RECONCILIATION_TIMEOUT_MS"));
  return Number.isFinite(value) && value >= 5_000 && value <= 60_000
    ? Math.trunc(value)
    : defaultTimeoutMs;
}

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Supabase worker configuration missing");
  return createClient(url, key, { auth: { persistSession: false } });
}
