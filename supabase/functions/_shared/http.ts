const productionOrigin = Deno.env.get("WEB_APP_ORIGIN")?.trim() || "https://app.questra.jp";
const allowLocalOrigins = Deno.env.get("ALLOW_LOCAL_WEB_ORIGINS") === "true";

export const corsHeaders = {
  "Access-Control-Allow-Origin": productionOrigin,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "600",
  "Vary": "Origin",
};

export function preflightResponse(req: Request) {
  if (req.method !== "OPTIONS") return null;
  const origin = req.headers.get("origin");
  if (origin && !isAllowedWebOrigin(origin)) {
    return new Response("Origin not allowed", { status: 403 });
  }
  return new Response("ok", { headers: corsHeaders });
}

function isAllowedWebOrigin(origin: string) {
  if (origin === productionOrigin) return true;
  return allowLocalOrigins && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
}

export function jsonResponse(
  body: unknown,
  init: ResponseInit = {},
) {
  const headers = new Headers(init.headers);
  for (const [name, value] of Object.entries(corsHeaders)) {
    headers.set(name, value);
  }
  return Response.json(body, {
    ...init,
    headers,
  });
}

export async function readJson<T>(req: Request): Promise<T | null> {
  try {
    return await req.json() as T;
  } catch (_) {
    return null;
  }
}
