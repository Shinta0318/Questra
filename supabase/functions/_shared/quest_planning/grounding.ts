const REQUIRED_PATTERNS = [
  /旅行|入国|ビザ|パスポート|航空|交通|営業/, /資格|試験|申請|制度|法律|税|補助金/,
  /医療|健康|薬|治療|安全/, /価格|料金|費用|製品/, /天候|季節|イベント|ソフトウェア|API|仕様/,
];

export type GroundingDecision = {
  required: boolean;
  reason: string;
  requiredFacts: Array<{ factType: string; queryIntent: string; freshnessRequirement: string; preferredSourceType: "official" }>;
};

export function decideGrounding(questText: string): GroundingDecision {
  const matched = REQUIRED_PATTERNS.some((pattern) => pattern.test(questText));
  return matched
    ? {
      required: true,
      reason: "The Quest depends on current external facts.",
      requiredFacts: [{ factType: "current_requirement", queryIntent: sanitizeQueryIntent(questText), freshnessRequirement: "current", preferredSourceType: "official" }],
    }
    : { required: false, reason: "No freshness-sensitive fact was detected.", requiredFacts: [] };
}

export function sanitizeQueryIntent(value: string) {
  return value.replace(/[\w.+-]+@[\w.-]+/g, "[email]").replace(/\b\d{2,4}[- ]?\d{2,4}[- ]?\d{3,4}\b/g, "[phone]").slice(0, 500);
}

export function validateGroundingEvidence(
  decision: GroundingDecision,
  metadata: unknown,
) {
  if (!decision.required) return { valid: true, issues: [] as string[] };
  if (!isRecord(metadata)) return { valid: false, issues: ["grounding_metadata_missing"] };
  const queries = Array.isArray(metadata.queries)
    ? metadata.queries.filter((item): item is string => typeof item === "string" && item.trim().length > 0)
    : [];
  const sources = Array.isArray(metadata.sources)
    ? metadata.sources.filter((item) => isRecord(item) && typeof item.uri === "string" && isHttpsUri(item.uri))
    : [];
  const issues: string[] = [];
  if (queries.length === 0) issues.push("grounding_query_missing");
  if (sources.length === 0) issues.push("grounding_source_missing");
  if (typeof metadata.retrievedAt !== "string" || Number.isNaN(Date.parse(metadata.retrievedAt))) issues.push("grounding_retrieved_at_missing");
  return { valid: issues.length === 0, issues };
}

export function validateGroundedMissionReferences(
  plan: unknown,
  decision: GroundingDecision,
  metadata: unknown,
) {
  const issues: Array<{ path: string; code: string; message: string; missionClientId?: string }> = [];
  if (!isRecord(plan) || !Array.isArray(plan.missions)) return issues;
  const sourceIds = new Set(
    isRecord(metadata) && Array.isArray(metadata.sources)
      ? metadata.sources
        .filter(isRecord)
        .map((source) => source.id)
        .filter((id): id is string => typeof id === "string")
      : [],
  );
  let currentFactMissionCount = 0;
  for (const [index, raw] of plan.missions.entries()) {
    if (!isRecord(raw)) continue;
    const missionClientId = typeof raw.clientId === "string" ? raw.clientId : undefined;
    const refs = Array.isArray(raw.groundedFactRefs)
      ? raw.groundedFactRefs.filter((item): item is string => typeof item === "string")
      : [];
    if (raw.requiresCurrentFacts === true) currentFactMissionCount += 1;
    if (decision.required && raw.requiresCurrentFacts === true && refs.length === 0) {
      issues.push({ path: `$.missions[${index}].groundedFactRefs`, code: "grounded_claim_unlinked", message: "A required Mission must link to verified current sources", missionClientId });
    }
    for (const ref of refs) {
      if (!sourceIds.has(ref)) issues.push({ path: `$.missions[${index}].groundedFactRefs`, code: "grounding_source_unknown", message: "Mission references an unknown grounding source", missionClientId });
    }
  }
  if (decision.required && currentFactMissionCount === 0) {
    issues.push({ path: "$.missions", code: "grounded_claim_classification_missing", message: "A freshness-sensitive Quest must identify Missions that rely on current facts" });
  }
  return issues;
}

function isHttpsUri(value: string) {
  try {
    const uri = new URL(value);
    return uri.protocol === "https:" && !uri.username && !uri.password;
  } catch (_) {
    return false;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
