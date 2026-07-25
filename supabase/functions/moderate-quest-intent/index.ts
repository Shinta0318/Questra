import { generateAiText } from "../_shared/ai_provider.ts";
import { jsonResponse, preflightResponse, readJson } from "../_shared/http.ts";
import {
  deterministicSafetyAssessment,
  safeAssessment,
  type SafetyAssessment,
} from "../_shared/safety_guard.ts";

Deno.serve(async (req) => {
  const preflight = preflightResponse(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, { status: 405 });
  }
  const payload = await readJson<{ input?: string }>(req);
  const input = payload?.input?.trim().slice(0, 4_000) ?? "";
  if (!input) return jsonResponse(safeAssessment());

  const deterministic = deterministicSafetyAssessment(input);
  if (deterministic) return jsonResponse(deterministic);

  try {
    const result = await generateAiText({
      systemInstruction:
        "Classify whether a proposed life Quest requests operational facilitation of serious wrongdoing or exploitation. Return JSON only. Do not block legitimate prevention, victim support, health, education, consensual adult wellbeing, fiction, research, or ambitious harmless goals merely for containing sensitive words. Block violent wrongdoing, illegal operational wrongdoing, sexual exploitation of minors, and non-consensual sexual conduct. Reframe acute self-harm distress toward immediate safety. Do not decide account bans.",
      input: { proposed_quest: input },
      responseSchema: safetySchema,
      maxOutputTokens: 350,
      temperature: 0,
    });
    if (!result) return jsonResponse(safeAssessment("safety_fallback"));
    const parsed = JSON.parse(stripFence(result.text)) as Record<string, unknown>;
    return jsonResponse(normalizeAssessment(parsed, result.sourceType));
  } catch (_) {
    return jsonResponse(safeAssessment("safety_fallback"));
  }
});

const safetySchema = {
  type: "object",
  properties: {
    action: { type: "string", enum: ["allow", "reframe", "block"] },
    category: {
      type: "string",
      enum: [
        "safe",
        "violentWrongdoing",
        "illegalWrongdoing",
        "sexualExploitation",
        "nonConsensualSexual",
        "selfHarm",
        "highRiskAdvice",
        "other",
      ],
    },
    severity: { type: "integer", minimum: 0, maximum: 4 },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    reason_code: { type: "string" },
    user_message: { type: "string" },
    safe_alternative: { type: "string" },
  },
  required: [
    "action",
    "category",
    "severity",
    "confidence",
    "reason_code",
    "user_message",
  ],
};

function normalizeAssessment(
  data: Record<string, unknown>,
  sourceType: string,
): SafetyAssessment {
  const allowedActions = ["allow", "reframe", "block"];
  const action = allowedActions.includes(String(data.action))
    ? String(data.action) as SafetyAssessment["action"]
    : "block";
  const severity = Math.max(0, Math.min(4, Number(data.severity ?? 3)));
  return {
    action,
    category: String(data.category ?? "other"),
    severity,
    confidence: Math.max(0, Math.min(1, Number(data.confidence ?? 0))),
    reason_code: String(data.reason_code ?? "provider_invalid"),
    user_message: action === "allow"
      ? ""
      : String(data.user_message ||
        "安全を確認できなかったため、今はこの航路を作れないよ。"),
    safe_alternative: typeof data.safe_alternative === "string"
      ? data.safe_alternative.slice(0, 160)
      : undefined,
    policy_version: "2026-07-24.v1",
    source_type: sourceType,
  };
}

function stripFence(value: string) {
  return value.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
}
