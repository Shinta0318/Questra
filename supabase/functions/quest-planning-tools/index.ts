import { jsonResponse, preflightResponse, readJson } from "../_shared/http.ts";
import { executeQuestraTool } from "../_shared/quest_planning/tool_server.ts";

Deno.serve(async (req) => {
  const preflight = preflightResponse(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, { status: 405 });
  const auth = req.headers.get("Authorization");
  const userId = await authenticatedUserId(auth);
  if (!userId) return jsonResponse({ error: "authentication_required" }, { status: 401 });
  const payload = await readJson<{ tool?: string; arguments?: Record<string, unknown>; trace_id?: string }>(req);
  if (!payload || typeof payload.tool !== "string" || !isRecord(payload.arguments)) {
    return jsonResponse({ error: "invalid_tool_request" }, { status: 400 });
  }
  const result = await executeQuestraTool(payload.tool, payload.arguments, {
    userId,
    traceId: uuid(payload.trace_id) ?? crypto.randomUUID(),
    // Write approval is verified only by approve_quest_plan_preview RPC.
    approved: false,
  });
  return jsonResponse(result, { status: result.ok ? 200 : result.error === "target_not_owned" ? 404 : 403 });
});

async function authenticatedUserId(auth: string | null) {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon || !auth) return null;
  const response = await fetch(`${url}/auth/v1/user`, { headers: { apikey: anon, Authorization: auth } });
  if (!response.ok) return null;
  const user = await response.json() as Record<string, unknown>;
  return uuid(user.id);
}

function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null; }
function uuid(value: unknown) { return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value) ? value : null; }
