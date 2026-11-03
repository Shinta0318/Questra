export function planningTargetDate(value: unknown): string | null | undefined {
  if (value == null || value === "") return null;
  if (typeof value !== "string") return undefined;
  const match =
    /^(\d{4}-\d{2}-\d{2})(?:T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?)?$/
      .exec(value.trim());
  if (!match) return undefined;
  const date = match[1];
  const parsed = new Date(`${date}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) &&
      parsed.toISOString().slice(0, 10) === date
    ? date
    : undefined;
}
