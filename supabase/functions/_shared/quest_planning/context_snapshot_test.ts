import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  planningToolContextFingerprint,
  planningToolContextSnapshot,
} from "./context_snapshot.ts";

const owner = "00000000-0000-4000-8000-000000000001";
const quest = "00000000-0000-4000-8000-000000000002";

function fixture() {
  const state = {
    quest: [{ id: quest, title: "旅行する", quest_dna_version: 1 }],
    missions: [{ id: "mission-1", status: "not_started", sort_order: 1 }],
    availability: [{ planning_consent_granted: true, monday_minutes: 60 }],
    memories: [{ id: "memory-1", content: "家族と旅行したい" }],
  };
  const paths: string[] = [];
  const serviceFetch = (path: string, init?: RequestInit) => {
    paths.push(path);
    if (path.includes("/rest/v1/quests?")) {
      const url = new URL(path, "https://example.test");
      if (
        url.searchParams.get("owner_id") !== `eq.${owner}` ||
        url.searchParams.get("id") !== `eq.${quest}`
      ) return Promise.resolve(Response.json([]));
      return Promise.resolve(Response.json(state.quest));
    }
    if (path.includes("/rest/v1/missions?")) {
      return Promise.resolve(Response.json(state.missions));
    }
    if (path.includes("/rest/v1/weekly_availability?")) {
      return Promise.resolve(Response.json(state.availability));
    }
    if (path.endsWith("/rpc/get_relevant_arc_memories")) {
      const body = JSON.parse(String(init?.body));
      if (body.p_user_id !== owner || body.p_quest_id !== quest) {
        return Promise.resolve(Response.json([]));
      }
      return Promise.resolve(Response.json(state.memories));
    }
    return Promise.resolve(
      Response.json({ error: "unexpected" }, { status: 404 }),
    );
  };
  return { state, paths, serviceFetch };
}

Deno.test("unchanged planning tool context keeps its restart fingerprint", async () => {
  const { serviceFetch, paths } = fixture();
  const first = await planningToolContextFingerprint(
    serviceFetch,
    owner,
    quest,
  );
  const resumed = await planningToolContextFingerprint(
    serviceFetch,
    owner,
    quest,
  );
  assertEquals(first, resumed);
  assertEquals(first?.length, 64);
  assertEquals(paths.length, 8);
});

Deno.test("planning tool context changes invalidate the old fingerprint", async () => {
  const { state, serviceFetch } = fixture();
  const first = await planningToolContextFingerprint(
    serviceFetch,
    owner,
    quest,
  );
  state.availability[0] = {
    ...state.availability[0],
    monday_minutes: 30,
  };
  const afterAvailability = await planningToolContextFingerprint(
    serviceFetch,
    owner,
    quest,
  );
  assertNotEquals(first, afterAvailability);
  state.memories = [];
  const afterMemory = await planningToolContextFingerprint(
    serviceFetch,
    owner,
    quest,
  );
  assertNotEquals(afterAvailability, afterMemory);
  state.missions[0] = { ...state.missions[0], status: "completed" };
  const afterMission = await planningToolContextFingerprint(
    serviceFetch,
    owner,
    quest,
  );
  assertNotEquals(afterMemory, afterMission);
  state.quest[0] = { ...state.quest[0], quest_dna_version: 2 };
  assertNotEquals(
    afterMission,
    await planningToolContextFingerprint(serviceFetch, owner, quest),
  );
});

Deno.test("missing or unavailable context fails closed", async () => {
  const { state, serviceFetch } = fixture();
  state.quest = [];
  assertEquals(
    await planningToolContextFingerprint(serviceFetch, owner, quest),
    null,
  );
  assertEquals(
    await planningToolContextFingerprint(
      () => Promise.resolve(null),
      owner,
      quest,
    ),
    null,
  );
});

Deno.test("server snapshot exposes only verified planning consent", async () => {
  const { state, serviceFetch } = fixture();
  assertEquals(
    (await planningToolContextSnapshot(serviceFetch, owner, quest))
      ?.planningConsentGranted,
    true,
  );
  state.availability[0] = {
    ...state.availability[0],
    planning_consent_granted: false,
  };
  assertEquals(
    (await planningToolContextSnapshot(serviceFetch, owner, quest))
      ?.planningConsentGranted,
    false,
  );
  state.availability = [];
  assertEquals(
    (await planningToolContextSnapshot(serviceFetch, owner, quest))
      ?.planningConsentGranted,
    false,
  );
});
