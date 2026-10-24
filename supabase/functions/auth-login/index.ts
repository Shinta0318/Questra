import { createClient } from "npm:@supabase/supabase-js@2.112.4";
import { classifyAuthFailure } from "./auth_error.ts";
import { requestPasswordGrant, runLoginDecisionRpc } from "./auth_io.ts";
import { readBoundedJsonObject } from "./bounded_request.ts";

type LoginAccount = {
  user_id: string;
  email_norm: string;
  locked_until: string | null;
};

const MAX_BODY_BYTES = 4_096;
const AUTH_CONTRACT_VERSION = "2026-10-18.1";
const LOGIN_ID_PATTERN = /^[a-z0-9][a-z0-9._-]{2,39}$/;
const LOCAL_ORIGIN_PATTERN = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  if (!isAllowedOrigin(origin)) {
    return secureJson({ error: "Origin not allowed" }, 403, null);
  }

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: secureHeaders(origin) });
  }
  if (req.method !== "POST") {
    return secureJson({ error: "Method not allowed" }, 405, origin);
  }

  const parsed = await readBoundedJsonObject(req, MAX_BODY_BYTES);
  if (parsed.kind !== "ok") {
    const failure = {
      too_large: { message: "Request too large", status: 413 },
      invalid: { message: "Invalid request", status: 400 },
      timed_out: { message: "Request timed out", status: 408 },
    }[parsed.kind];
    return secureJson({ error: failure.message }, failure.status, origin);
  }

  const payload = parsed.value;
  const identifier = normalizeIdentifier(payload.identifier);
  const password = typeof payload.password === "string" ? payload.password : "";
  if (!identifier || password.length < 1 || password.length > 72) {
    await minimumFailureDelay();
    return invalidCredentials(origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return secureJson({ error: "Authentication is unavailable" }, 503, origin);
  }

  const admin = createAuthAdminClient(supabaseUrl, serviceRoleKey);

  let account: LoginAccount | null;
  try {
    account = await findLoginAccount(admin, identifier);
  } catch (_) {
    return secureJson({ error: "Authentication is unavailable" }, 503, origin);
  }
  if (!account) {
    await minimumFailureDelay();
    return invalidCredentials(origin);
  }

  if (isLocked(account.locked_until)) {
    await minimumFailureDelay();
    return invalidCredentials(origin);
  }

  const authResponse = await requestPasswordGrant(
    supabaseUrl,
    anonKey,
    account.email_norm,
    password,
  );
  if (!authResponse) {
    return secureJson({ error: "Authentication is unavailable" }, 503, origin);
  }

  const authPayload = await safeJson(authResponse);
  if (!authResponse.ok) {
    const failure = classifyAuthFailure(authResponse.status, authPayload);
    if (failure === "invalid_credentials") {
      const decision = await runLoginDecisionRpc(() =>
        admin.rpc("record_auth_login_failure_v2", {
          target_user_id: account.user_id,
        })
      );
      if (decision === "unavailable") {
        return secureJson({ error: "Authentication is unavailable" }, 503, origin);
      }
      await minimumFailureDelay();
      return invalidCredentials(origin);
    }
    if (failure === "unconfirmed") {
      await minimumFailureDelay();
      return invalidCredentials(origin);
    }
    if (failure === "rate_limited") {
      return secureJson(
        { code: "rate_limited", error: "しばらく待ってから再度お試しください。" },
        429,
        origin,
      );
    }
    return secureJson({ error: "Authentication is unavailable" }, 503, origin);
  }

  const accessToken = stringValue(authPayload.access_token);
  const refreshToken = stringValue(authPayload.refresh_token);
  if (!accessToken || !refreshToken) {
    return secureJson({ error: "Authentication is unavailable" }, 503, origin);
  }

  const decision = await runLoginDecisionRpc(() =>
    admin.rpc("record_auth_login_success_v2", {
      target_user_id: account.user_id,
    })
  );
  if (decision === "unavailable") {
    return secureJson({ error: "Authentication is unavailable" }, 503, origin);
  }
  if (decision === "locked") {
    await minimumFailureDelay();
    return invalidCredentials(origin);
  }

  return secureJson({
    access_token: accessToken,
    refresh_token: refreshToken,
    expires_in: authPayload.expires_in,
  }, 200, origin);
});

function createAuthAdminClient(url: string, serviceRoleKey: string) {
  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

async function findLoginAccount(
  admin: ReturnType<typeof createAuthAdminClient>,
  identifier: string,
): Promise<LoginAccount | null> {
  const column = identifier.includes("@") ? "email_norm" : "login_id_norm";
  const { data, error } = await admin
    .from("auth_login_accounts")
    .select("user_id,email_norm,locked_until")
    .eq(column, identifier)
    .maybeSingle();

  if (error) throw error;
  if (!data) return null;
  return data as LoginAccount;
}

function normalizeIdentifier(value: unknown) {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  if (normalized.length < 3 || normalized.length > 254) return null;
  if (normalized.includes("@")) {
    return normalized.includes(" ") ? null : normalized;
  }
  return LOGIN_ID_PATTERN.test(normalized) ? normalized : null;
}

function isLocked(value: string | null) {
  if (!value) return false;
  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) && timestamp > Date.now();
}

function invalidCredentials(origin: string | null) {
  return secureJson({
    code: "invalid_credentials",
    error: "ログインIDまたはパスワードを確認してください。",
  }, 401, origin);
}

async function minimumFailureDelay() {
  await new Promise((resolve) => setTimeout(resolve, 250));
}

async function safeJson(response: Response): Promise<Record<string, unknown>> {
  try {
    return await response.json() as Record<string, unknown>;
  } catch (_) {
    return {};
  }
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function isAllowedOrigin(origin: string | null) {
  if (!origin) return true;
  if (LOCAL_ORIGIN_PATTERN.test(origin)) return true;
  const configured = (Deno.env.get("ALLOWED_WEB_ORIGINS") ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  return configured.includes(origin);
}

function secureHeaders(origin: string | null) {
  const headers = new Headers({
    "access-control-allow-headers":
      "authorization, x-client-info, apikey, content-type",
    "access-control-allow-methods": "POST, OPTIONS",
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    "referrer-policy": "no-referrer",
    "vary": "Origin",
    "x-content-type-options": "nosniff",
    "x-questra-auth-contract": AUTH_CONTRACT_VERSION,
  });
  if (origin) headers.set("access-control-allow-origin", origin);
  return headers;
}

function secureJson(
  body: unknown,
  status: number,
  origin: string | null,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: secureHeaders(origin),
  });
}
