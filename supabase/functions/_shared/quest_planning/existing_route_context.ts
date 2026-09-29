export type ExistingRouteMission = {
  id: string;
  title: string;
  objective: string;
  successCondition: string;
  expectedOutcome: string;
  status: string;
  required: boolean;
  orderIndex: number;
  generatedBy: string;
  updatedAt: string;
};

export type ExistingRouteContext = {
  applicationMode: "initial" | "replace_remaining";
  missions: ExistingRouteMission[];
  baseMissions: Array<{ id: string; status: string; updatedAt: string }>;
  completedMissionIds: string[];
  existingMissionCount: number;
  completedMissionCount: number;
  replaceableMissionCount: number;
};

export function buildExistingRouteContext(
  rows: Array<Record<string, unknown>>,
): ExistingRouteContext {
  const missions = rows
    .map(toMission)
    .filter((mission): mission is ExistingRouteMission => mission !== null)
    .sort((a, b) => a.orderIndex - b.orderIndex)
    .slice(0, 30);
  const completedMissionIds = missions
    .filter((mission) => mission.status === "completed")
    .map((mission) => mission.id);

  return {
    applicationMode: missions.length === 0 ? "initial" : "replace_remaining",
    missions,
    baseMissions: missions.map(({ id, status, updatedAt }) => ({
      id,
      status,
      updatedAt,
    })),
    completedMissionIds,
    existingMissionCount: missions.length,
    completedMissionCount: completedMissionIds.length,
    replaceableMissionCount: missions.length - completedMissionIds.length,
  };
}

function toMission(
  row: Record<string, unknown>,
): ExistingRouteMission | null {
  const id = stringValue(row.id);
  const title = stringValue(row.title);
  const updatedAt = stringValue(row.updated_at);
  if (!id || !title || !updatedAt) return null;

  return {
    id,
    title,
    objective: stringValue(row.objective),
    successCondition: stringValue(row.success_condition),
    expectedOutcome: stringValue(row.expected_outcome),
    status: stringValue(row.status) || "todo",
    required: row.required !== false,
    orderIndex: finiteInteger(row.order_index ?? row.sort_order),
    generatedBy: stringValue(row.generated_by) || "manual",
    updatedAt,
  };
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function finiteInteger(value: unknown) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.trunc(number) : 0;
}
