export async function planningPassIdempotencyKey(
  base: string,
  pass: string,
  input: unknown,
): Promise<string> {
  const canonical = JSON.stringify({ base, pass, input }, (_key, value) => {
    if (value && typeof value === "object" && !Array.isArray(value)) {
      return Object.fromEntries(
        Object.entries(value).sort(([left], [right]) =>
          left < right ? -1 : left > right ? 1 : 0
        ),
      );
    }
    return value;
  });
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(canonical),
  );
  const fingerprint = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return `${base.slice(0, 100)}:${pass}:${fingerprint.slice(0, 32)}`;
}
