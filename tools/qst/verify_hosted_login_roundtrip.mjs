import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const timeoutMs = 10000;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class HostedLoginCheckError extends Error {
  constructor(stage, status) {
    super(`Hosted login check stopped at ${stage}${status ? ` (HTTP ${status})` : ''}.`);
    this.name = 'HostedLoginCheckError';
    this.stage = stage;
    this.status = status;
  }
}

export async function verifyHostedLoginRoundTrip({
  url,
  publishableKey,
  identifier,
  password,
  fetchImpl = fetch,
}) {
  const project = validateProject(url, publishableKey);
  if (typeof identifier !== 'string' || !identifier.trim() ||
      typeof password !== 'string' || !password) {
    throw new HostedLoginCheckError('configuration');
  }

  const loginResponse = await request(fetchImpl, 'login',
    `${project.origin}/functions/v1/auth-login`, {
      method: 'POST',
      headers: {
        apikey: publishableKey,
        Authorization: `Bearer ${publishableKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ identifier: identifier.trim(), password }),
    });
  const login = await readJson(loginResponse, 'login');
  if (!loginResponse.ok || typeof login?.access_token !== 'string' ||
      !login.access_token || typeof login.refresh_token !== 'string' ||
      !login.refresh_token) {
    throw new HostedLoginCheckError('login', loginResponse.status);
  }

  const headers = {
    apikey: publishableKey,
    Authorization: `Bearer ${login.access_token}`,
  };
  const authResponse = await request(fetchImpl, 'auth_user',
    `${project.origin}/auth/v1/user`, { headers });
  const user = await readJson(authResponse, 'auth_user');
  if (!authResponse.ok || typeof user?.id !== 'string' ||
      !uuidPattern.test(user.id)) {
    throw new HostedLoginCheckError('auth_user', authResponse.status);
  }

  const profileUrl = new URL('/rest/v1/user_profiles', project);
  profileUrl.searchParams.set('select', 'id');
  profileUrl.searchParams.set('id', `eq.${user.id}`);
  const profileResponse = await request(fetchImpl, 'profile',
    profileUrl.toString(), { headers });
  const profiles = await readJson(profileResponse, 'profile');
  if (!profileResponse.ok || !Array.isArray(profiles) ||
      profiles.length !== 1 || profiles[0]?.id !== user.id) {
    throw new HostedLoginCheckError('profile', profileResponse.status);
  }

  return { login: 'passed', authUser: 'passed', ownerProfile: 'passed' };
}

function validateProject(url, publishableKey) {
  let project;
  try {
    project = new URL(url);
  } catch (_) {
    throw new HostedLoginCheckError('configuration');
  }
  if (project.protocol !== 'https:' ||
      !/^[a-z0-9-]+\.supabase\.co$/.test(project.hostname) ||
      project.username || project.password || project.port ||
      project.pathname !== '/' || project.search || project.hash ||
      !/^sb_publishable_[A-Za-z0-9_-]{20,}$/.test(publishableKey ?? '')) {
    throw new HostedLoginCheckError('configuration');
  }
  return project;
}

async function request(fetchImpl, stage, url, options) {
  try {
    return await fetchImpl(url, {
      ...options,
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (_) {
    throw new HostedLoginCheckError(stage);
  }
}

async function readJson(response, stage) {
  try {
    return await response.json();
  } catch (_) {
    throw new HostedLoginCheckError(stage, response.status);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const result = await verifyHostedLoginRoundTrip({
      url: process.env.SUPABASE_URL,
      publishableKey: process.env.SUPABASE_ANON_KEY,
      identifier: process.env.QST_TEST_LOGIN_ID,
      password: process.env.QST_TEST_PASSWORD,
    });
    console.log(`Hosted login round trip: PASS (${Object.keys(result).join(', ')}).`);
  } catch (error) {
    const safeError = error instanceof HostedLoginCheckError
      ? error : new HostedLoginCheckError('unknown');
    console.error(`Hosted login round trip: FAIL (${safeError.message})`);
    process.exitCode = 1;
  }
}
