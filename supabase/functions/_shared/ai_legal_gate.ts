import { isValidUserId } from "./ai_auth.ts";

export type AiLegalGateStatus = "granted" | "denied" | "unavailable";

type LegalGateDependencies = {
  supabaseUrl?: string;
  serviceRoleKey?: string;
  fetchImpl?: typeof fetch;
};

export async function currentAiLegalGate(
  userId: unknown,
  dependencies: LegalGateDependencies = {},
): Promise<AiLegalGateStatus> {
  if (!isValidUserId(userId)) return "denied";
  const url = dependencies.supabaseUrl ?? Deno.env.get("SUPABASE_URL");
  const key = dependencies.serviceRoleKey ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return "unavailable";

  try {
    const response = await (dependencies.fetchImpl ?? fetch)(
      `${url.replace(/\/$/, "")}/rest/v1/rpc/has_current_ai_legal_acceptance`,
      {
        method: "POST",
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ p_user_id: userId }),
        signal: AbortSignal.timeout(5_000),
      },
    );
    if (!response.ok) return "unavailable";
    const result: unknown = await response.json();
    if (result === true) return "granted";
    return result === false ? "denied" : "unavailable";
  } catch {
    return "unavailable";
  }
}
