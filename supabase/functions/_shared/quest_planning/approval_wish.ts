export function previewWithPlanningWish(
  preview: unknown,
  wish: string,
): Record<string, unknown> | null {
  if (
    !preview || typeof preview !== "object" || Array.isArray(preview) ||
    !wish.trim() || wish.length > 1_200
  ) return null;
  return { ...preview, planningWish: wish };
}

export function approvalPlanningWish(
  preview: Record<string, unknown>,
): string | null {
  const wish = preview.planningWish;
  return typeof wish === "string" && wish.trim() &&
      wish.length <= 1_200
    ? wish
    : null;
}
