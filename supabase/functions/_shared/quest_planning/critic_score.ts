const missionMinimums: Record<string, number> = {
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
};

export function passesOverallCriticScore(score: unknown): boolean {
  return typeof score === "number" && Number.isFinite(score) && score >= 85 &&
    score <= 100;
}

export function passesMissionDimensionScores(value: unknown): boolean {
  if (!value || typeof value !== "object") return false;
  const scores = value as Record<string, unknown>;
  return Object.entries(missionMinimums).every(([key, minimum]) =>
    typeof scores[key] === "number" && Number.isInteger(scores[key]) &&
    Number(scores[key]) >= minimum && Number(scores[key]) <= 100
  );
}

export function criticReviewCoverage(
  expectedIds: string[],
  results: unknown,
  idField: "clientId" | "candidateId" = "clientId",
) {
  const expected = new Set(expectedIds);
  const counts = new Map<string, number>();
  const unexpected = new Set<string>();
  let invalidCount = 0;
  if (!Array.isArray(results)) {
    return {
      missing: [...expected],
      duplicate: [],
      unexpected: [],
      invalidCount: 1,
    };
  }
  for (const raw of results) {
    const id = raw && typeof raw === "object"
      ? (raw as Record<string, unknown>)[idField]
      : null;
    if (typeof id !== "string" || !id.trim()) {
      invalidCount++;
    } else if (!expected.has(id)) {
      unexpected.add(id);
    } else {
      counts.set(id, (counts.get(id) ?? 0) + 1);
    }
  }
  return {
    missing: [...expected].filter((id) => !counts.has(id)),
    duplicate: [...counts].filter(([, count]) => count > 1).map(([id]) => id),
    unexpected: [...unexpected],
    invalidCount,
  };
}

export function contradictoryPassingCritic(
  operation: string,
  output: unknown,
): boolean {
  if (!output || typeof output !== "object") return false;
  const critic = output as Record<string, unknown>;
  if (critic.passed !== true) return false;
  if (operation === "quest_planning.mission_critic") {
    return !passesOverallCriticScore(critic.overallScore) ||
      !Array.isArray(critic.missionResults) ||
      critic.missionResults.length === 0 ||
      critic.missionResults.some((raw: unknown) => {
        if (!raw || typeof raw !== "object") return true;
        const review = raw as Record<string, unknown>;
        return review.passed !== true || review.verdict !== "pass" ||
          !passesMissionDimensionScores(review.scores);
      });
  }
  if (operation === "quest_planning.task_critic") {
    return !passesOverallCriticScore(critic.overallScore) ||
      !Array.isArray(critic.taskResults) || critic.taskResults.length === 0 ||
      critic.taskResults.some((raw: unknown) =>
        !raw || typeof raw !== "object" ||
        (raw as Record<string, unknown>).passed !== true
      );
  }
  return false;
}
