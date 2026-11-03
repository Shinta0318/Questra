import { planningInputFingerprint } from "./preview_persistence.ts";

type ServiceFetch = (
  path: string,
  init?: RequestInit,
) => Promise<Response | null>;

async function rows(
  serviceFetch: ServiceFetch,
  path: string,
  max: number,
  init?: RequestInit,
): Promise<unknown[] | null> {
  const response = await serviceFetch(path, {
    ...init,
    signal: AbortSignal.timeout(5_000),
  });
  if (!response?.ok) return null;
  const data = await response.json();
  return Array.isArray(data) && data.length <= max ? data : null;
}

export type PlanningToolContextSnapshot = {
  fingerprint: string;
  planningConsentGranted: boolean;
};

export async function planningToolContextSnapshot(
  serviceFetch: ServiceFetch,
  ownerId: string,
  questId: string,
): Promise<PlanningToolContextSnapshot | null> {
  try {
    const questQuery = new URLSearchParams({
      id: `eq.${questId}`,
      owner_id: `eq.${ownerId}`,
      select:
        "id,title,description,status,target_date,requested_target_month,difficulty_score,estimated_duration_days,quest_dna,quest_dna_version,quest_dna_evaluated_at",
      limit: "1",
    });
    const missionQuery = new URLSearchParams({
      quest_id: `eq.${questId}`,
      select:
        "id,title,status,sort_order,dependency_ids,estimated_duration_days,updated_at",
      order: "sort_order.asc,id.asc",
      limit: "31",
    });
    const availabilityQuery = new URLSearchParams({
      user_id: `eq.${ownerId}`,
      select:
        "planning_consent_granted,monday_minutes,tuesday_minutes,wednesday_minutes,thursday_minutes,friday_minutes,saturday_minutes,budget_label,location,experience,updated_at",
      limit: "1",
    });
    const [quests, missions, availability, memories] = await Promise.all([
      rows(serviceFetch, `/rest/v1/quests?${questQuery}`, 1),
      rows(serviceFetch, `/rest/v1/missions?${missionQuery}`, 30),
      rows(
        serviceFetch,
        `/rest/v1/weekly_availability?${availabilityQuery}`,
        1,
      ),
      rows(serviceFetch, "/rest/v1/rpc/get_relevant_arc_memories", 5, {
        method: "POST",
        body: JSON.stringify({
          p_user_id: ownerId,
          p_quest_id: questId,
          p_limit: 5,
        }),
      }),
    ]);
    if (
      quests?.length !== 1 || !missions || !availability || !memories
    ) return null;
    // Only the digest is retained; raw preferences and Memory stay on the server.
    const fingerprint = await planningInputFingerprint({
      quest: quests[0],
      missions,
      availability,
      memories,
    });
    const preference = availability[0];
    return {
      fingerprint,
      planningConsentGranted: Boolean(
        preference && typeof preference === "object" &&
          (preference as Record<string, unknown>).planning_consent_granted ===
            true,
      ),
    };
  } catch {
    return null;
  }
}

export async function planningToolContextFingerprint(
  serviceFetch: ServiceFetch,
  ownerId: string,
  questId: string,
): Promise<string | null> {
  return (await planningToolContextSnapshot(serviceFetch, ownerId, questId))
    ?.fingerprint ?? null;
}
