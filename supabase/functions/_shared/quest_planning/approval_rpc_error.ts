export type ApprovalRpcFailure = {
  error: string;
  status: number;
  state: "conflict" | "retryable_error" | "consent_required";
};

const conflicts = new Set([
  "route_changed_since_preview",
  "completed_mission_duplicate_in_plan",
  "preview_already_approved_with_different_selection",
  "approved_selection_not_found",
  "preview_not_approvable",
]);

export function approvalRpcFailure(body: unknown): ApprovalRpcFailure {
  const message = body && typeof body === "object" &&
      "message" in body && typeof body.message === "string"
    ? body.message
    : null;
  if (message && conflicts.has(message)) {
    return { error: message, status: 409, state: "conflict" };
  }
  if (message === "ai_legal_consent_required") {
    return { error: "consent_required", status: 403, state: "consent_required" };
  }
  return { error: "approval_failed", status: 503, state: "retryable_error" };
}
