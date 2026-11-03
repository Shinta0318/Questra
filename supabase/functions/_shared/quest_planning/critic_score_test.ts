import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { activePrompt } from "./prompt_registry.ts";
import {
  contradictoryPassingCritic,
  criticReviewCoverage,
  passesMissionDimensionScores,
  passesOverallCriticScore,
} from "./critic_score.ts";

Deno.test("five-point critic scores cannot pass the 100-point quality gate", () => {
  assertEquals(passesOverallCriticScore(5), false);
  assertEquals(
    passesMissionDimensionScores({
      questRelevance: 5,
      outcomeQuality: 5,
      missionGranularity: 5,
      successConditionQuality: 5,
      personalization: 5,
      nonTemplateQuality: 5,
      uniqueness: 5,
      sequencing: 5,
      completenessContribution: 5,
      taskSeparation: 5,
    }),
    false,
  );
});

Deno.test("valid percentage scores pass without lowering existing thresholds", () => {
  assertEquals(passesOverallCriticScore(85), true);
  assertEquals(
    passesMissionDimensionScores({
      questRelevance: 90,
      outcomeQuality: 85,
      missionGranularity: 90,
      successConditionQuality: 90,
      personalization: 80,
      nonTemplateQuality: 90,
      uniqueness: 90,
      sequencing: 80,
      completenessContribution: 85,
      taskSeparation: 95,
    }),
    true,
  );
  assertEquals(passesOverallCriticScore(101), false);
});

Deno.test("Critic prompts explicitly require 0-100 scores", () => {
  assertEquals(
    activePrompt("mission_critic").systemInstruction.includes("0-100"),
    true,
  );
  assertEquals(
    activePrompt("task_critic").systemInstruction.includes("0-100"),
    true,
  );
});

Deno.test("Critic review coverage requires exactly one result per candidate", () => {
  assertEquals(
    criticReviewCoverage(["m1", "m2"], [{ clientId: "m1" }, {
      clientId: "m2",
    }]),
    {
      missing: [],
      duplicate: [],
      unexpected: [],
      invalidCount: 0,
    },
  );
  assertEquals(
    criticReviewCoverage(["m1", "m2"], [
      { clientId: "m1" },
      { clientId: "m1" },
      { clientId: "extra" },
      null,
    ]),
    {
      missing: ["m2"],
      duplicate: ["m1"],
      unexpected: ["extra"],
      invalidCount: 1,
    },
  );
  assertEquals(criticReviewCoverage(["m1"], null).missing, ["m1"]);
});

Deno.test("Mission granularity reviews must cover each candidate exactly once", () => {
  assertEquals(
    criticReviewCoverage(["m1", "m2"], [
      { candidateId: "m1" },
      { candidateId: "m1" },
      { candidateId: "other" },
    ], "candidateId"),
    {
      missing: ["m2"],
      duplicate: ["m1"],
      unexpected: ["other"],
      invalidCount: 0,
    },
  );
});

Deno.test("a passing five-point Critic result is a retryable evaluator mismatch", () => {
  const fivePoint = {
    passed: true,
    overallScore: 5,
    missionResults: [{
      clientId: "m1",
      passed: true,
      verdict: "pass",
      scores: {
        questRelevance: 5,
        outcomeQuality: 5,
        missionGranularity: 5,
        successConditionQuality: 5,
        personalization: 5,
        nonTemplateQuality: 5,
        uniqueness: 5,
        sequencing: 5,
        completenessContribution: 5,
        taskSeparation: 5,
      },
    }],
  };
  assertEquals(
    contradictoryPassingCritic("quest_planning.mission_critic", fivePoint),
    true,
  );
  assertEquals(
    contradictoryPassingCritic("quest_planning.mission_critic", {
      ...fivePoint,
      passed: false,
    }),
    false,
  );
  assertEquals(
    contradictoryPassingCritic("quest_planning.task_critic", {
      passed: true,
      overallScore: 5,
      taskResults: [{ clientId: "t1", passed: true }],
    }),
    true,
  );
});
