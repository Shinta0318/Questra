import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const functionNames = [
  'arc-chat',
  'arc-quest-guide',
  'generate-arc-advice',
  'generate-mission',
  'generate-quest-guides',
  'generate-star-map',
  'moderate-quest-intent',
  'quest-planning-tools',
  'quest-planning-v2',
  'research-mission-resources',
];

const missingConsentProbeBodies = {
  'arc-chat': { message: '短い散歩を続けたい' },
  'arc-quest-guide': { mode: 'quest_intent', wish: '短い散歩を続けたい' },
  'generate-arc-advice': { quest: { title: '散歩する' }, guide: {} },
  'generate-mission': { quest: { title: '散歩する' }, guide: {} },
  'generate-quest-guides': { quest: { title: '散歩する' } },
  'generate-star-map': { quest: { title: '散歩する' }, guide: {} },
  'moderate-quest-intent': { input: '散歩を続けたい' },
  'quest-planning-tools': { tool: 'get_user_planning_preferences', arguments: {} },
};

export async function verifyHostedAiAuthBoundary({ url, publishableKey, fetchImpl = fetch }) {
  const project = validateProject(url, publishableKey);
  return probeFunctions(project, publishableKey, publishableKey, fetchImpl);
}

export async function verifyHostedSignedInAiPath({
  url,
  publishableKey,
  userAccessToken,
  fetchImpl = fetch,
}) {
  const project = validateProject(url, publishableKey);
  await verifySignedInUser(project, publishableKey, userAccessToken, fetchImpl);
  return probeFunctions(project, publishableKey, userAccessToken, fetchImpl);
}

export async function verifyHostedMissingConsentDenial({
  url,
  publishableKey,
  userAccessToken,
  fixtureQuestId,
  fixtureMissionId,
  fetchImpl = fetch,
}) {
  const project = validateProject(url, publishableKey);
  const hasOwnedFixture = Boolean(fixtureQuestId || fixtureMissionId);
  if (hasOwnedFixture && (!validUuid(fixtureQuestId) || !validUuid(fixtureMissionId))) {
    throw new Error('Both disposable, owned Quest and Mission UUIDs are required for owner-scoped denial probes.');
  }
  const probeBodies = {
    ...missingConsentProbeBodies,
    ...(hasOwnedFixture ? {
      'quest-planning-v2': {
        mode: 'plan',
        quest_id: fixtureQuestId,
        wish: '短い散歩を続けたい',
        idempotency_key: `legal-denial-probe-${crypto.randomUUID()}`,
      },
      'research-mission-resources': {
        force_refresh: true,
        mission: {
          id: fixtureMissionId,
          quest_id: fixtureQuestId,
          title: '散歩の時間を決める',
          quest_title: '短い散歩を続ける',
        },
      },
    } : {}),
  };
  await verifySignedInUser(project, publishableKey, userAccessToken, fetchImpl);
  const results = [];
  for (const [name, body] of Object.entries(probeBodies)) {
    const response = await fetchImpl(`${project.origin}/functions/v1/${name}`, {
      method: 'POST',
      headers: {
        apikey: publishableKey,
        Authorization: `Bearer ${userAccessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(10000),
    });
    const payload = await response.json().catch(() => null);
    const result = {
      functionName: name,
      status: response.status,
      errorCode: payload?.error === 'consent_required' ? 'consent_required' : null,
    };
    results.push(result);
    if (result.status !== 403 || result.errorCode !== 'consent_required') break;
  }
  return results;
}

export function hasExpectedMissingConsentDenialStatuses(results, includeOwnedFixtures = false) {
  const names = includeOwnedFixtures ? functionNames : Object.keys(missingConsentProbeBodies);
  return Array.isArray(results) && results.length === names.length && names.every((name) => {
    const matches = results.filter((result) => result.functionName === name);
    return matches.length === 1 && matches[0].status === 403 && matches[0].errorCode === 'consent_required';
  });
}

function validUuid(value) {
  return typeof value === 'string'
    && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

async function verifySignedInUser(project, publishableKey, userAccessToken, fetchImpl) {
  if (!/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(userAccessToken ?? '')) {
    throw new Error('SUPABASE_USER_JWT must be a signed-in user access token.');
  }
  const userResponse = await fetchImpl(`${project.origin}/auth/v1/user`, {
    headers: {
      apikey: publishableKey,
      Authorization: `Bearer ${userAccessToken}`,
    },
    signal: AbortSignal.timeout(10000),
  });
  if (userResponse.status !== 200) {
    await userResponse.body?.cancel();
    throw new Error('The signed-in user token was rejected by Supabase Auth.');
  }
  const user = await userResponse.json().catch(() => null);
  if (typeof user?.id !== 'string' || !user.id) {
    throw new Error('Supabase Auth did not return a signed-in user.');
  }
}

function validateProject(url, publishableKey) {
  if (!url) throw new Error('SUPABASE_URL is required.');
  const project = new URL(url);
  if (project.protocol !== 'https:' || !/^[a-z0-9-]+\.supabase\.co$/.test(project.hostname)) {
    throw new Error('SUPABASE_URL must be a hosted HTTPS Supabase project URL.');
  }
  if (!/^sb_publishable_[A-Za-z0-9_-]{20,}$/.test(publishableKey)) {
    throw new Error('SUPABASE_ANON_KEY must be a publishable client key.');
  }
  return project;
}

async function probeFunctions(project, publishableKey, bearer, fetchImpl) {
  const results = [];
  for (const name of functionNames) {
    const response = await fetchImpl(`${project.origin}/functions/v1/${name}`, {
      method: 'POST',
      headers: {
        apikey: publishableKey,
        Authorization: `Bearer ${bearer}`,
        'Content-Type': 'application/json',
      },
      // Invalid JSON prevents valid planning input and model work in the current handlers.
      body: '{',
      signal: AbortSignal.timeout(10000),
    });
    results.push({ functionName: name, status: response.status });
    await response.body?.cancel();
  }
  return results;
}

export function hasExpectedAiAuthStatuses(results, signedIn = false, expectedConsent = 'granted') {
  if (!Array.isArray(results) || results.length !== functionNames.length) return false;
  if (signedIn && !['granted', 'missing'].includes(expectedConsent)) return false;
  return functionNames.every((name) => {
    const matches = results.filter((result) => result.functionName === name);
    const expectedStatus = !signedIn ? 401
      : name === 'arc-chat' && expectedConsent === 'missing' ? 403
      : name === 'moderate-quest-intent' ? 200 : 400;
    return matches.length === 1 && matches[0].status === expectedStatus;
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const config = {
      url: process.env.SUPABASE_URL ?? '',
      publishableKey: process.env.SUPABASE_ANON_KEY ?? '',
    };
    const results = await verifyHostedAiAuthBoundary(config);
    for (const result of results) {
      console.log(`anonymous/${result.functionName}: ${result.status}`);
    }
    const anonymousPassed = hasExpectedAiAuthStatuses(results);
    let signedInPassed = true;
    const runDenialProbe = process.env.SUPABASE_RUN_CONSENT_DENIAL_PROBE === 'true';
    const fixtureQuestId = process.env.SUPABASE_TEST_QUEST_ID;
    const fixtureMissionId = process.env.SUPABASE_TEST_MISSION_ID;
    if (runDenialProbe && (
      process.env.SUPABASE_USER_CONSENT_EXPECTED !== 'missing' || !process.env.SUPABASE_USER_JWT
    )) {
      throw new Error('The consent denial probe requires a disposable missing-consent user token and SUPABASE_USER_CONSENT_EXPECTED=missing.');
    }
    if (runDenialProbe && Boolean(fixtureQuestId) !== Boolean(fixtureMissionId)) {
      throw new Error('Provide both disposable owned fixture IDs, or neither.');
    }
    if (anonymousPassed && process.env.SUPABASE_USER_JWT) {
      const expectedConsent = process.env.SUPABASE_USER_CONSENT_EXPECTED ?? 'granted';
      const signedIn = await verifyHostedSignedInAiPath({
        ...config,
        userAccessToken: process.env.SUPABASE_USER_JWT,
      });
      for (const result of signedIn) {
        console.log(`signed_in/${result.functionName}: ${result.status}`);
      }
      signedInPassed = hasExpectedAiAuthStatuses(signedIn, true, expectedConsent);
      if (signedInPassed && runDenialProbe) {
        const denied = await verifyHostedMissingConsentDenial({
          ...config,
          userAccessToken: process.env.SUPABASE_USER_JWT,
          fixtureQuestId,
          fixtureMissionId,
        });
        for (const result of denied) {
          console.log(`missing_consent/${result.functionName}: ${result.status}`);
        }
        signedInPassed = hasExpectedMissingConsentDenialStatuses(denied, Boolean(fixtureQuestId));
      }
    }
    if (!anonymousPassed || !signedInPassed) {
      console.error('Hosted AI auth boundary: FAIL (anonymous rejection or signed-in access did not match the expected contract).');
      process.exitCode = 1;
    } else {
      console.log('Hosted AI auth boundary: PASS.');
    }
  } catch (error) {
    console.error(`Hosted AI auth boundary: unable to verify (${error.message}).`);
    process.exitCode = 1;
  }
}
