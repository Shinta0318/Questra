export type SafetyAction = "allow" | "reframe" | "block";

export type SafetyAssessment = {
  action: SafetyAction;
  category: string;
  severity: number;
  confidence: number;
  reason_code: string;
  user_message: string;
  safe_alternative?: string;
  policy_version: string;
  source_type: string;
};

const POLICY_VERSION = "2026-07-24.v1";
const benignContext = /(被害|防止|予防|相談|通報|小説|創作|研究|歴史|ニュース|教育|安全|助け)/;
const minorSexual = /(未成年|児童|子ども|子供).{0,20}(性的|性行為|裸|ポルノ|わいせつ)|(性的|性行為|裸|ポルノ|わいせつ).{0,20}(未成年|児童|子ども|子供)/;
const nonConsensual = /(同意なし|無理やり|睡眠中|酔わせ).{0,20}(性行為|性的|触る|撮影)/;
const violent = /(人を殺|殺し方|刺し方|爆弾.{0,12}(作|製造)|放火.{0,12}(方法|やり方))/;
const illegal = /(強盗|詐欺|不正アクセス|クレカ.{0,8}(盗|悪用)|違法薬物).{0,24}(方法|やり方|成功|ばれない|作り方)/;
const selfHarm = /(自殺したい|死にたい|自傷したい)/;

export function deterministicSafetyAssessment(
  input: string,
): SafetyAssessment | null {
  const text = input.trim().slice(0, 4_000);
  if (!text) return null;
  if (selfHarm.test(text)) {
    return {
      action: "reframe",
      category: "selfHarm",
      severity: 4,
      confidence: 0.96,
      reason_code: "self_harm_distress",
      user_message:
        "今はQuestにするより、あなたの安全を最優先にしたい。ひとりで抱えず、近くの信頼できる人や地域の緊急窓口へつながってね。",
      safe_alternative: "今この瞬間を安全に過ごすため、連絡できる人を一人選ぶ",
      policy_version: POLICY_VERSION,
      source_type: "deterministic_safety",
    };
  }
  if (minorSexual.test(text)) return blocked("sexualExploitation", "sexual_minor_exploitation");
  if (nonConsensual.test(text)) return blocked("nonConsensualSexual", "non_consensual_sexual");
  if (!benignContext.test(text) && violent.test(text)) {
    return blocked("violentWrongdoing", "violent_wrongdoing");
  }
  if (!benignContext.test(text) && illegal.test(text)) {
    return blocked("illegalWrongdoing", "illegal_wrongdoing");
  }
  return null;
}

export function safeAssessment(sourceType = "deterministic_safety"): SafetyAssessment {
  return {
    action: "allow",
    category: "safe",
    severity: 0,
    confidence: 1,
    reason_code: "safe",
    user_message: "",
    policy_version: POLICY_VERSION,
    source_type: sourceType,
  };
}

function blocked(category: string, reasonCode: string): SafetyAssessment {
  return {
    action: "block",
    category,
    severity: 4,
    confidence: 0.98,
    reason_code: reasonCode,
    user_message:
      "その内容を実行するための航路は作れないよ。誰かを傷つけない、安全で合法な目的なら一緒に考え直せる。",
    safe_alternative: "安全で合法な目的に言い換える",
    policy_version: POLICY_VERSION,
    source_type: "deterministic_safety",
  };
}
