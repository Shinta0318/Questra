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
