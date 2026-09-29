import { resolveFallbackModel, resolveModel } from "./model_registry.ts";

Deno.test("configured primary fails over to a different stable model", () => {
  withEnv(
    {
      GEMINI_MODEL_MISSION_GENERATOR: "gemini-3.5-flash",
      GEMINI_FALLBACK_MODEL_MISSION_GENERATOR: null,
    },
    () => {
      const primary = resolveModel("mission_generator");
      const fallback = resolveFallbackModel("mission_generator", primary.name);
      assertEquals(primary.name, "gemini-3.5-flash");
      assertEquals(fallback.name, "gemini-3.6-flash");
      assertNotEquals(primary.name, fallback.name);
      assertEquals(fallback.releaseType, "stable");
    },
  );
});

Deno.test("configured fallback is independent from configured primary", () => {
  withEnv(
    {
      GEMINI_MODEL_STRATEGIC_PLANNER: "gemini-3.6-flash",
      GEMINI_FALLBACK_MODEL_STRATEGIC_PLANNER: "gemini-3.5-flash-lite",
    },
    () => {
      const primary = resolveModel("strategic_planner");
      const fallback = resolveFallbackModel("strategic_planner", primary.name);
      assertEquals(primary.name, "gemini-3.6-flash");
      assertEquals(fallback.name, "gemini-3.5-flash-lite");
    },
  );
});

Deno.test("unknown model overrides fail closed to pinned routes", () => {
  withEnv(
    {
      GEMINI_MODEL_QUEST_UNDERSTANDING: "gemini-flash-latest",
      GEMINI_FALLBACK_MODEL_QUEST_UNDERSTANDING: "unknown-model",
    },
    () => {
      const primary = resolveModel("quest_understanding");
      const fallback = resolveFallbackModel(
        "quest_understanding",
        primary.name,
      );
      assertEquals(primary.name, "gemini-3.5-flash");
      assertEquals(fallback.name, "gemini-3.5-flash-lite");
    },
  );
});

function withEnv(values: Record<string, string | null>, body: () => void) {
  const previous = Object.fromEntries(
    Object.keys(values).map((key) => [key, Deno.env.get(key)]),
  );
  try {
    for (const [key, value] of Object.entries(values)) {
      if (value === null) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
    body();
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}

function assertNotEquals(actual: unknown, expected: unknown) {
  if (actual === expected) {
    throw new Error(`Expected values to differ: ${actual}`);
  }
}
