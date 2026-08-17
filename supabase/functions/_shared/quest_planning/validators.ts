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

export function validateRouteMissionPlan(value: unknown, expectedQuestId: string): ValidationResult {
  const issues: ValidationIssue[] = [];
  if (!isRecord(value) || !Array.isArray(value.missions)) return invalid("$.missions", "type", "Route Missions are required");
  if (value.questId !== expectedQuestId) issues.push(issue("$.questId", "quest_mismatch", "Quest ID does not match"));
  const ids = new Set<string>();
  const missions = value.missions as unknown[];
  for (const [index, raw] of missions.entries()) {
    if (!isRecord(raw)) { issues.push(issue(`$.missions[${index}]`, "type", "Mission must be an object")); continue; }
    const id = text(raw.clientId);
    if (!id || ids.has(id)) issues.push(issue(`$.missions[${index}].clientId`, "duplicate", "Mission clientId is missing or duplicated", id ?? undefined));
    if (id) ids.add(id);
    for (const key of ["title", "objective", "successCondition", "expectedOutcome", "reasonRequired"] as const) if (!text(raw[key])) issues.push(issue(`$.missions[${index}].${key}`, "required", `${key} is required`, id ?? undefined));
    if (!Array.isArray(raw.coveredSuccessConditions) || raw.coveredSuccessConditions.length < 1) issues.push(issue(`$.missions[${index}].coveredSuccessConditions`, "required", "A Mission must cover a success condition", id ?? undefined));
    if (!integerBetween(raw.childTaskEstimate, 1, 30)) issues.push(issue(`$.missions[${index}].childTaskEstimate`, "range", "childTaskEstimate is invalid", id ?? undefined));
    if (!Array.isArray(raw.dependencies)) issues.push(issue(`$.missions[${index}].dependencies`, "type", "Dependencies must be an array", id ?? undefined));
  }
  const typed = missions.filter(isRouteMission);
  for (const mission of typed) for (const dependency of mission.dependencies) if (!ids.has(dependency) || dependency === mission.clientId) issues.push(issue("$.missions.dependencies", "invalid_dependency", "Mission dependency is invalid", mission.clientId));
  if (hasCycle(typed as Mission[])) issues.push(issue("$.missions", "dependency_cycle", "Mission dependency graph contains a cycle"));
  return { valid: issues.length === 0, issues };
}

export function validateMissionArchitectureSemantics(value: unknown, questText: string, successContract: unknown, granularity: unknown, coverage: unknown): ValidationResult {
  if (!isRecord(value) || !Array.isArray(value.missions)) return invalid("$.missions", "type", "Missions are required");
  const issues: ValidationIssue[] = [];
  const normalizedQuest = normalize(questText);
  const actionOnly = /^(調べる|確認する|予約する|比較する|書く|練習する|購入する|申し込む|電話する)(こと)?$/;
  const internalPlanningArtifact = /^(達成したと分かる状態を決める|今の条件と不明点を分ける|Questの成功条件を決める|成功条件を明確にする|計画の前提を整理する)$/;
  const titles = new Map<string, string>();
  for (const raw of value.missions) {
    if (!isRecord(raw)) continue;
    const id = text(raw.clientId);
    const title = text(raw.title) ?? "";
    const normalizedTitle = normalize(title);
    if (actionOnly.test(title.trim())) issues.push(issue("$.missions.title", "task_granularity", "Standalone actions must be Tasks", id ?? undefined));
    if (internalPlanningArtifact.test(title.trim())) issues.push(issue("$.missions.title", "internal_planning_artifact", "Internal planning work must not be exposed as a Mission", id ?? undefined));
    if (Number(raw.childTaskEstimate) < 2 && raw.required !== false) issues.push(issue("$.missions.childTaskEstimate", "task_granularity", "A Mission should normally contain multiple Tasks", id ?? undefined));
    if (normalizedTitle === normalizedQuest || normalizedQuest.includes(normalizedTitle) && normalizedTitle.length >= normalizedQuest.length * 0.8) issues.push(issue("$.missions.title", "quest_paraphrase", "Mission title is only a Quest paraphrase", id ?? undefined));
    const fingerprint = normalizedTitle.replace(/(を|の|に|へ|と|が|する|完了|確定)/g, "");
    if (fingerprint.length >= 3 && titles.has(fingerprint)) issues.push(issue("$.missions.title", "semantic_duplicate", "Mission outcomes overlap", id ?? undefined));
    if (fingerprint.length >= 3 && id) titles.set(fingerprint, id);
  }
  if (isRecord(granularity) && Array.isArray(granularity.classifications)) {
    for (const raw of granularity.classifications) {
      if (!isRecord(raw) || raw.classification === "mission") continue;
      if (typeof raw.candidateId === "string") issues.push(issue("$.granularity", `classified_${String(raw.classification)}`, "Candidate is not Mission-granularity", raw.candidateId));
    }
  }
  if (isRecord(coverage)) {
    if (coverage.passed !== true) issues.push(issue("$.coverage", "coverage_failed", "Success Contract coverage is incomplete"));
    if (Array.isArray(coverage.successConditionCoverage) && coverage.successConditionCoverage.some((raw) => isRecord(raw) && raw.coverageStatus !== "covered")) issues.push(issue("$.coverage.successConditionCoverage", "missing_success_condition", "Every required success condition must be covered"));
  }
  if (isRecord(successContract) && Array.isArray(successContract.requiredConditions) && successContract.requiredConditions.length > 0) {
    const covered = new Set<string>();
    for (const raw of value.missions) if (isRecord(raw) && Array.isArray(raw.coveredSuccessConditions)) for (const condition of raw.coveredSuccessConditions) if (typeof condition === "string") covered.add(normalize(condition));
    for (const condition of successContract.requiredConditions) if (typeof condition === "string" && ![...covered].some((item) => item === normalize(condition))) issues.push(issue("$.missions.coveredSuccessConditions", "required_condition_unmapped", "A required Success Contract condition is not mapped to a Mission"));
  }
  return { valid: issues.length === 0, issues };
}

export function validateTaskPlan(value: unknown, expectedQuestId: string, missionClientId: string): ValidationResult {
  if (!isRecord(value) || !Array.isArray(value.tasks)) return invalid("$.tasks", "type", "Tasks are required");
  const issues: ValidationIssue[] = [];
  if (value.tasks.length < 1 || value.tasks.length > 30) issues.push(issue("$.tasks", "count", "Task count must be between 1 and 30"));
  if (value.questId !== expectedQuestId) issues.push(issue("$.questId", "quest_mismatch", "Quest ID does not match"));
  if (value.missionClientId !== missionClientId) issues.push(issue("$.missionClientId", "mission_mismatch", "Mission ID does not match"));
  const ids = new Set<string>();
  for (const [index, raw] of (value.tasks as unknown[]).entries()) {
    if (!isRecord(raw)) { issues.push(issue(`$.tasks[${index}]`, "type", "Task must be an object")); continue; }
    const id = text(raw.clientId);
    if (!id || ids.has(id)) issues.push(issue(`$.tasks[${index}].clientId`, "duplicate", "Task clientId is missing or duplicated", id ?? undefined));
    if (id) ids.add(id);
    for (const key of ["title", "action", "purpose", "doneCondition", "expectedOutput"] as const) if (!text(raw[key])) issues.push(issue(`$.tasks[${index}].${key}`, "required", `${key} is required`, id ?? undefined));
    if (!integerBetween(raw.estimatedEffortMinutes, 1, 1440)) issues.push(issue(`$.tasks[${index}].estimatedEffortMinutes`, "range", "Task effort is invalid", id ?? undefined));
    if (!Array.isArray(raw.dependencies)) issues.push(issue(`$.tasks[${index}].dependencies`, "type", "Task dependencies must be an array", id ?? undefined));
    if (typeof raw.required !== "boolean") issues.push(issue(`$.tasks[${index}].required`, "type", "required must be boolean", id ?? undefined));
    if (typeof raw.confidence !== "number" || raw.confidence < 0 || raw.confidence > 1) issues.push(issue(`$.tasks[${index}].confidence`, "range", "confidence must be from 0 to 1", id ?? undefined));
  }
  const typed = (value.tasks as unknown[]).filter(isMission);
  for (const task of typed) for (const dependency of task.dependencies) {
    if (!ids.has(dependency)) issues.push(issue("$.tasks.dependencies", "missing_dependency", `Dependency ${dependency} does not exist`, task.clientId));
    if (dependency === task.clientId) issues.push(issue("$.tasks.dependencies", "self_dependency", "Task cannot depend on itself", task.clientId));
  }
  if (hasCycle(typed)) issues.push(issue("$.tasks", "dependency_cycle", "Task dependency graph contains a cycle"));
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
function isRouteMission(value: unknown): value is Mission {
  return isRecord(value) && typeof value.clientId === "string" && Array.isArray(value.dependencies) && value.dependencies.every((item) => typeof item === "string");
}
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null; }
function text(value: unknown) { return typeof value === "string" && value.trim() ? value.trim() : null; }
function normalize(value: string) { return value.toLowerCase().replace(/[\s、。,.!！?？「」『』()（）]/g, ""); }
function integerBetween(value: unknown, min: number, max: number) { return Number.isInteger(value) && Number(value) >= min && Number(value) <= max; }
function issue(path: string, code: string, message: string, missionClientId?: string): ValidationIssue { return { path, code, message, missionClientId }; }
function invalid(path: string, code: string, message: string): ValidationResult { return { valid: false, issues: [issue(path, code, message)] }; }
function tokens(value: string) { return [...new Set(value.toLowerCase().split(/[\s、。,.!！?？「」『』()（）]+/).filter((part) => part.length >= 2))].slice(0, 12); }
