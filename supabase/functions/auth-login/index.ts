import { createClient } from "npm:@supabase/supabase-js@2";

type LoginRequest = {
  identifier?: string;
  password?: string;
};

type LoginAccount = {
  user_id: string;
  email_norm: string;
  locked_until: string | null;
};

const MAX_BODY_BYTES = 4_096;
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

  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (contentLength > MAX_BODY_BYTES) {
    return secureJson({ error: "Request too large" }, 413, origin);
  }

  const rawBody = await req.text();
  if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
    return secureJson({ error: "Request too large" }, 413, origin);
  }

  let payload: LoginRequest;
  try {
    payload = JSON.parse(rawBody) as LoginRequest;
  } catch (_) {
    return secureJson({ error: "Invalid request" }, 400, origin);
  }

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

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const account = await findLoginAccount(admin, identifier);
  if (!account) {
    await minimumFailureDelay();
    return invalidCredentials(origin);
  }

  if (isLocked(account.locked_until)) {
    await minimumFailureDelay();
    return invalidCredentials(origin);
  }

  const authResponse = await fetch(
    `${supabaseUrl}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: {
        "apikey": anonKey,
        "authorization": `Bearer ${anonKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ email: account.email_norm, password }),
    },
  );

  const authPayload = await safeJson(authResponse);
  if (!authResponse.ok) {
    if (authPayload.code === "invalid_credentials") {
      await admin.rpc("record_auth_login_failure", {
        target_user_id: account.user_id,
      });
      await minimumFailureDelay();
      return invalidCredentials(origin);
    }
    if (authResponse.status === 429) {
      return secureJson(
        { code: "rate_limited", error: "しばらく待ってから再度お試しください。" },
        429,
        origin,
      );
    }
    return invalidCredentials(origin);
  }

  const accessToken = stringValue(authPayload.access_token);
  const refreshToken = stringValue(authPayload.refresh_token);
  if (!accessToken || !refreshToken) {
    return secureJson({ error: "Authentication is unavailable" }, 503, origin);
  }

  await admin.rpc("record_auth_login_success", {
    target_user_id: account.user_id,
  });

  return secureJson({
    access_token: accessToken,
    refresh_token: refreshToken,
    expires_in: authPayload.expires_in,
  }, 200, origin);
});

async function findLoginAccount(
  admin: ReturnType<typeof createClient>,
  identifier: string,
): Promise<LoginAccount | null> {
  const column = identifier.includes("@") ? "email_norm" : "login_id_norm";
  const { data, error } = await admin
    .from("auth_login_accounts")
    .select("user_id,email_norm,locked_until")
    .eq(column, identifier)
    .maybeSingle();

  if (error || !data) return null;
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
