import { createClient } from "npm:@supabase/supabase-js@2";
import { groundedMissionSearch } from "../_shared/grounded_search_provider.ts";
import { jsonResponse, preflightResponse, readJson } from "../_shared/http.ts";

type MissionInput = {
  id?: string;
  quest_id?: string;
  quest_title?: string;
  title?: string;
  description?: string;
};

Deno.serve(async (req) => {
  const preflight = preflightResponse(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, { status: 405 });

  const user = await authenticatedUser(req);
  if (!user) return jsonResponse({ error: "Unauthorized" }, { status: 401 });
  const payload = await readJson<{
    mission?: MissionInput;
    force_refresh?: boolean;
  }>(req);
  const mission = payload?.mission;
  if (!mission?.id || !mission.quest_id || !mission.title?.trim()) {
    return jsonResponse({ error: "Invalid Mission" }, { status: 400 });
  }
  const allowed = await ownerOwnsMission(user.id, mission.id, mission.quest_id);
  if (!allowed) return jsonResponse({ error: "Mission not found" }, { status: 404 });
  if (payload?.force_refresh !== true) {
    const cached = await loadCachedResearch(user.id, mission.id);
    if (cached) {
      return jsonResponse({ ...cached, source_type: "mission_research_cache" });
    }
  }
  if (!await withinRateLimit(user.id)) {
    return jsonResponse({ error: "Research rate limit reached" }, { status: 429 });
  }

  const result = await groundedMissionSearch({
    parent_quest: limit(mission.quest_title, 120),
    mission: limit(mission.title, 120),
    mission_description: limit(mission.description, 600),
    requested_output: "Only information necessary to complete this Mission",
  });
  if (!result) return jsonResponse({ error: "Search unavailable" }, { status: 503 });

  const parsed = parseResult(result.text);
  const retrievedAt = new Date().toISOString();
  const responseBody = {
    ...parsed,
    sources: result.sources.map((source) => ({
      ...source,
      retrieved_at: retrievedAt,
      verified: true,
    })),
    source_type: result.sourceType,
  };
  await saveCachedResearch(user.id, mission.id, responseBody);
  return jsonResponse(responseBody);
});

async function authenticatedUser(req: Request) {
  const auth = req.headers.get("Authorization");
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!auth || !url || !anon) return null;
  const client = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const { data, error } = await client.auth.getUser();
  return error ? null : data.user;
}

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(url, key, { auth: { persistSession: false } });
}

async function ownerOwnsMission(userId: string, missionId: string, questId: string) {
  const { data } = await adminClient().from("missions").select("id,quests!inner(owner_id)")
    .eq("id", missionId).eq("quest_id", questId).eq("quests.owner_id", userId).maybeSingle();
  return Boolean(data);
}

async function withinRateLimit(userId: string) {
  const admin = adminClient();
  const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count } = await admin.from("mission_research_requests").select("id", { count: "exact", head: true })
    .eq("user_id", userId).gte("created_at", since);
  if ((count ?? 0) >= 10) return false;
  await admin.from("mission_research_requests").insert({ user_id: userId });
  return true;
}

async function loadCachedResearch(userId: string, missionId: string) {
  const { data } = await adminClient().from("mission_research_results")
    .select("result_data")
    .eq("user_id", userId)
    .eq("mission_id", missionId)
    .gt("expires_at", new Date().toISOString())
    .maybeSingle();
  return data?.result_data && typeof data.result_data === "object"
    ? data.result_data as Record<string, unknown>
    : null;
}

async function saveCachedResearch(
  userId: string,
  missionId: string,
  resultData: Record<string, unknown>,
) {
  await adminClient().from("mission_research_results").upsert({
    user_id: userId,
    mission_id: missionId,
    result_data: resultData,
    retrieved_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString(),
  }, { onConflict: "user_id,mission_id" });
}

function parseResult(raw: string) {
  try {
    const value = JSON.parse(raw.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, ""));
    return {
      summary: limit(value.summary, 1400),
      checkpoints: stringList(value.checkpoints, 6),
      cautions: stringList(value.cautions, 4),
    };
  } catch (_) {
    return { summary: limit(raw, 1400), checkpoints: [], cautions: ["参照先で最新条件を確認してください。"] };
  }
}

function stringList(value: unknown, max: number) {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string").slice(0, max).map((item) => limit(item, 280)) : [];
}

function limit(value: unknown, max: number) {
  const text = typeof value === "string" ? value.trim() : "";
  return text.length <= max ? text : text.slice(0, max);
}
