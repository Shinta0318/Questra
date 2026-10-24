import { currentAiLegalGate } from "./ai_legal_gate.ts";
import { jsonResponse } from "./http.ts";

export async function aiLegalFailureResponse(userId: string): Promise<Response | null> {
  const status = await currentAiLegalGate(userId);
  if (status === "granted") return null;
  return status === "denied"
    ? jsonResponse({ error: "consent_required" }, { status: 403 })
    : jsonResponse({ error: "consent_check_unavailable" }, { status: 503 });
}
