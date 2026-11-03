import type { PlanningInput } from "./pipeline.ts";

export type ApprovalInputSnapshot = {
  wish: string;
  targetDate: string | null;
  budget: string | null;
  availableTime: unknown;
  experience: string | null;
  location: string | null;
  constraints: string[];
  approvedContext: Record<string, unknown> | null;
};

const APPROVED_CONTEXT_KEYS = new Set([
  "consent_granted",
  "weekly_minutes",
  "budget_label",
  "location",
  "experience",
  "available_resources",
  "preferences",
  "companion_type",
  "setback_reasons",
  "approved_mission_history_summary",
]);

function boundedObject(
  value: unknown,
  maxBytes: number,
): value is Record<string, unknown> {
  return value !== null && typeof value === "object" &&
    !Array.isArray(value) &&
    new TextEncoder().encode(JSON.stringify(value)).length <= maxBytes;
}

function validOptionalText(value: unknown, maxLength: number): boolean {
  return value === null ||
    (typeof value === "string" && value.length <= maxLength);
}

function validApprovedContext(value: unknown): boolean {
  if (value === null) return true;
  if (!boundedObject(value, 4_096) || value.consent_granted !== true) {
    return false;
  }
  if (Object.keys(value).some((key) => !APPROVED_CONTEXT_KEYS.has(key))) {
    return false;
  }
  const minutes = value.weekly_minutes;
  if (
    minutes != null &&
    (!Number.isInteger(minutes) || Number(minutes) < 0 ||
      Number(minutes) > 10_080)
  ) {
    return false;
  }
  for (
    const key of [
      "budget_label",
      "location",
      "experience",
      "companion_type",
      "approved_mission_history_summary",
    ]
  ) {
    if (value[key] !== undefined && !validOptionalText(value[key], 1_200)) {
      return false;
    }
  }
  for (const key of ["available_resources", "preferences", "setback_reasons"]) {
    const items = value[key];
    if (
      items !== undefined &&
      (!Array.isArray(items) || items.length > 20 ||
        items.some((item) => typeof item !== "string" || item.length > 300))
    ) return false;
  }
  return true;
}

export function approvalInputSnapshot(
  input: Pick<
    PlanningInput,
    | "wish"
    | "targetDate"
    | "budget"
    | "availableTime"
    | "experience"
    | "location"
    | "constraints"
    | "approvedContext"
  >,
): ApprovalInputSnapshot | null {
  const value: ApprovalInputSnapshot = {
    wish: input.wish,
    targetDate: input.targetDate ?? null,
    budget: input.budget ?? null,
    availableTime: input.availableTime ?? null,
    experience: input.experience ?? null,
    location: input.location ?? null,
    constraints: input.constraints ?? [],
    approvedContext: input.approvedContext ?? null,
  };
  return readApprovalInputSnapshot(value);
}

export function readApprovalInputSnapshot(
  value: unknown,
): ApprovalInputSnapshot | null {
  if (!boundedObject(value, 8_192)) return null;
  const wish = value.wish;
  if (
    typeof wish !== "string" || !wish.trim() || wish.length > 1_200 ||
    !validOptionalText(value.targetDate, 20) ||
    !validOptionalText(value.budget, 120) ||
    !validOptionalText(value.experience, 300) ||
    !validOptionalText(value.location, 200) ||
    !Array.isArray(value.constraints) || value.constraints.length > 40 ||
    value.constraints.some((item) =>
      typeof item !== "string" || item.length > 500
    ) ||
    !validApprovedContext(value.approvedContext)
  ) return null;
  const availability = value.availableTime;
  if (
    availability !== null &&
    (!boundedObject(availability, 256) ||
      Object.keys(availability).some((key) => key !== "weekly_minutes") ||
      !Number.isInteger(availability.weekly_minutes) ||
      Number(availability.weekly_minutes) < 0 ||
      Number(availability.weekly_minutes) > 10_080)
  ) return null;
  return value as ApprovalInputSnapshot;
}

export function hasPersonalPlanningContext(
  value: ApprovalInputSnapshot,
): boolean {
  return Boolean(
    value.budget || value.availableTime || value.experience ||
      value.location || value.constraints?.length || value.approvedContext,
  );
}
