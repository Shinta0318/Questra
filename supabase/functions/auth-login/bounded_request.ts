export type BoundedJsonResult =
  | { kind: "ok"; value: Record<string, unknown> }
  | { kind: "invalid" | "too_large" | "timed_out" };

export async function readBoundedJsonObject(
  request: Request,
  maxBytes: number,
  maxWaitMs = 10_000,
): Promise<BoundedJsonResult> {
  const declaredLength = Number(request.headers.get("content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    return { kind: "too_large" };
  }
  if (!request.body) return { kind: "invalid" };

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  let timer: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<null>((resolve) => {
    timer = setTimeout(() => resolve(null), maxWaitMs);
  });
  try {
    while (true) {
      const result = await Promise.race([reader.read(), deadline]);
      if (result === null) {
        void reader.cancel().catch(() => {});
        return { kind: "timed_out" };
      }
      const { done, value } = result;
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        void reader.cancel().catch(() => {});
        return { kind: "too_large" };
      }
      chunks.push(value);
    }
  } catch (_) {
    return { kind: "invalid" };
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    const value: unknown = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
    if (value === null || typeof value !== "object" || Array.isArray(value)) {
      return { kind: "invalid" };
    }
    return { kind: "ok", value: value as Record<string, unknown> };
  } catch (_) {
    return { kind: "invalid" };
  }
}
