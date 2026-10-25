const userIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type AuthDependencies = {
  supabaseUrl?: string;
  anonKey?: string;
  fetchImpl?: typeof fetch;
};

export function isValidUserId(value: unknown): value is string {
  return typeof value === "string" && userIdPattern.test(value);
}

export async function authenticatedAiUser(
  request: Request,
  dependencies: AuthDependencies = {},
): Promise<string | null> {
  const authorization = request.headers.get("Authorization");
  const token = /^Bearer ([A-Za-z0-9._~-]+)$/i.exec(authorization ?? "")?.[1];
  if (!token || token.length > 8192 || token.split(".").length !== 3) {
    return null;
  }

  const url = dependencies.supabaseUrl ?? Deno.env.get("SUPABASE_URL");
  const anonKey = dependencies.anonKey ?? Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) return null;

  try {
    const response = await (dependencies.fetchImpl ?? fetch)(
      `${url.replace(/\/$/, "")}/auth/v1/user`,
      {
        headers: { apikey: anonKey, Authorization: authorization! },
        signal: AbortSignal.timeout(5000),
      },
    );
    if (!response.ok) return null;
    const user = await response.json() as Record<string, unknown>;
    return isValidUserId(user.id) ? user.id : null;
  } catch {
    return null;
  }
}
