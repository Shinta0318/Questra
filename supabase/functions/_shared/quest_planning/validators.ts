import { ValidationIssue, ValidationResult } from "./contracts.ts";

type Mission = {
  clientId: string;
  title: string;
  action: string;
  purpose: string;
  doneCondition: string;
  expectedOutput: string;
  estimatedEffortMinutes: number;
  calendarDurationDays: number;
  dependencies: string[];
  required: boolean;
  confidence: number;
};

export function validateMissionPlan(value: unknown, expectedQuestId: string): ValidationResult {
  const issues: ValidationIssue[] = [];
  if (!isRecord(value)) return invalid("$", "type", "MissionPlan must be an object");
  if (value.questId !== expectedQuestId) issues.push(issue("$.questId", "quest_mismatch", "Quest ID does not match"));
  if (!Number.isInteger(value.planVersion) || Number(value.planVersion) < 1) issues.push(issue("$.planVersion", "range", "planVersion must be positive"));
  if (!Array.isArray(value.missions) || value.missions.length < 1 || value.missions.length > 30) {
    issues.push(issue("$.missions", "count", "Mission count must be between 1 and 30"));
    return { valid: false, issues };
  }
  const missions = value.missions as unknown[];
  const ids = new Set<string>();
  const titles = new Set<string>();
  missions.forEach((raw, index) => {
    const path = `$.missions[${index}]`;
    if (!isRecord(raw)) {
      issues.push(issue(path, "type", "Mission must be an object"));
      return;
    }
    const id = text(raw.clientId);
    if (!id) issues.push(issue(`${path}.clientId`, "required", "clientId is required"));
    else if (ids.has(id)) issues.push(issue(`${path}.clientId`, "duplicate", "clientId must be unique", id));
    else ids.add(id);
    for (const [key, min, max] of [["title", 3, 100], ["action", 10, 500], ["purpose", 5, 300], ["doneCondition", 10, 500], ["expectedOutput", 3, 300]] as const) {
      const content = text(raw[key]);
      if (!content || content.length < min || content.length > max) issues.push(issue(`${path}.${key}`, "length", `${key} length is invalid`, id));
    }
    const normalizedTitle = text(raw.title)?.toLowerCase();
    if (normalizedTitle && titles.has(normalizedTitle)) issues.push(issue(`${path}.title`, "duplicate", "Mission title is duplicated", id));
    if (normalizedTitle) titles.add(normalizedTitle);
    if (!integerBetween(raw.estimatedEffortMinutes, 1, 1440)) issues.push(issue(`${path}.estimatedEffortMinutes`, "range", "Effort is outside the allowed range", id));
    if (!integerBetween(raw.calendarDurationDays, 0, 3650)) issues.push(issue(`${path}.calendarDurationDays`, "range", "Duration is outside the allowed range", id));
    if (!Array.isArray(raw.dependencies)) issues.push(issue(`${path}.dependencies`, "type", "Dependencies must be an array", id));
    if (typeof raw.required !== "boolean") issues.push(issue(`${path}.required`, "type", "required must be boolean", id));
    if (typeof raw.confidence !== "number" || raw.confidence < 0 || raw.confidence > 1) issues.push(issue(`${path}.confidence`, "range", "confidence must be from 0 to 1", id));
  });
  const typed = missions.filter(isMission);
  for (const mission of typed) {
    for (const dependency of mission.dependencies) {
      if (!ids.has(dependency)) issues.push(issue("$.missions.dependencies", "missing_dependency", `Dependency ${dependency} does not exist`, mission.clientId));
      if (dependency === mission.clientId) issues.push(issue("$.missions.dependencies", "self_dependency", "Mission cannot depend on itself", mission.clientId));
    }
  }
  if (hasCycle(typed)) issues.push(issue("$.missions", "dependency_cycle", "Mission dependency graph contains a cycle"));
  return { valid: issues.length === 0, issues };
}

export function validateMissionSemantics(value: unknown, questText: string): ValidationResult {
  if (!isRecord(value) || !Array.isArray(value.missions)) return invalid("$.missions", "type", "Missions are required");
  const issues: ValidationIssue[] = [];
  const generic = /^(調査する|準備する|計画する|実行する|確認する)$/;
  const questTerms = tokens(questText);
  for (const raw of value.missions) {
    if (!isRecord(raw)) continue;
    const id = text(raw.clientId);
    const title = text(raw.title) ?? "";
    const body = `${title} ${text(raw.action) ?? ""} ${text(raw.purpose) ?? ""}`;
    if (generic.test(title.trim())) issues.push(issue("$.missions.title", "template_like", "Mission title is too generic", id));
    if (!/\d|完了|提出|予約|作成|記録|確認|取得|実施|選択|決定/.test(text(raw.doneCondition) ?? "")) {
      issues.push(issue("$.missions.doneCondition", "not_verifiable", "Done condition is not objectively verifiable", id));
    }
    if (questTerms.length > 0 && !questTerms.some((term) => body.includes(term))) {
      issues.push(issue("$.missions", "weak_relevance", "Mission has weak lexical connection to the Quest", id));
    }
  }
  return { valid: issues.length === 0, issues };
}

function hasCycle(missions: Mission[]) {
  const graph = new Map(missions.map((mission) => [mission.clientId, mission.dependencies]));
  const visiting = new Set<string>();
  const visited = new Set<string>();
  const visit = (id: string): boolean => {
    if (visiting.has(id)) return true;
    if (visited.has(id)) return false;
    visiting.add(id);
    for (const dependency of graph.get(id) ?? []) if (visit(dependency)) return true;
    visiting.delete(id);
    visited.add(id);
    return false;
  };
  return missions.some((mission) => visit(mission.clientId));
}

function isMission(value: unknown): value is Mission {
  return isRecord(value) && typeof value.clientId === "string" && Array.isArray(value.dependencies) && value.dependencies.every((item) => typeof item === "string");
}
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null; }
function text(value: unknown) { return typeof value === "string" && value.trim() ? value.trim() : null; }
function integerBetween(value: unknown, min: number, max: number) { return Number.isInteger(value) && Number(value) >= min && Number(value) <= max; }
function issue(path: string, code: string, message: string, missionClientId?: string): ValidationIssue { return { path, code, message, missionClientId }; }
function invalid(path: string, code: string, message: string): ValidationResult { return { valid: false, issues: [issue(path, code, message)] }; }
function tokens(value: string) { return [...new Set(value.toLowerCase().split(/[\s、。,.!！?？「」『』()（）]+/).filter((part) => part.length >= 2))].slice(0, 12); }
