export type MissionRepairScope = {
  failedMissionClientIds: string[];
  coverageGap: boolean;
  needsRepair: boolean;
};

const internalPlanningIds = new Set([
  "__critic_overall__",
  "__plan_structure__",
  "__coverage_gap__",
]);

export function isInternalPlanningId(id: string): boolean {
  return internalPlanningIds.has(id);
}

export function missionRepairScope(
  plan: unknown,
  failedIds: string[],
): MissionRepairScope {
  const missions = plan && typeof plan === "object" &&
      Array.isArray((plan as Record<string, unknown>).missions)
    ? (plan as { missions: unknown[] }).missions
    : [];
  const actualIds = new Set(
    missions.map((mission) =>
      mission && typeof mission === "object"
        ? (mission as Record<string, unknown>).clientId
        : null
    ).filter((id): id is string =>
      typeof id === "string" && !isInternalPlanningId(id)
    ),
  );
  const failedMissionClientIds = [
    ...new Set(failedIds.filter((id) => actualIds.has(id))),
  ];
  const coverageGap = failedIds.includes("__coverage_gap__");
  return {
    failedMissionClientIds,
    coverageGap,
    needsRepair: failedMissionClientIds.length > 0 || coverageGap,
  };
}

export function taskRepairIds(plan: unknown, failedIds: string[]): string[] {
  const tasks = plan && typeof plan === "object" &&
      Array.isArray((plan as Record<string, unknown>).tasks)
    ? (plan as { tasks: unknown[] }).tasks
    : [];
  const actualIds = new Set(
    tasks.map((task) =>
      task && typeof task === "object"
        ? (task as Record<string, unknown>).clientId
        : null
    ).filter((id): id is string =>
      typeof id === "string" && !isInternalPlanningId(id)
    ),
  );
  return [...new Set(failedIds.filter((id) => actualIds.has(id)))];
}
