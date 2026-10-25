import assert from 'node:assert/strict';
import test from 'node:test';

import {
  hasExpectedAiAuthStatuses,
  hasExpectedMissingConsentDenialStatuses,
  verifyHostedAiAuthBoundary,
  verifyHostedMissingConsentDenial,
  verifyHostedSignedInAiPath,
} from './verify_hosted_ai_auth_boundary.mjs';

const config = {
  url: 'https://example.supabase.co',
  publishableKey: `sb_publishable_${'a'.repeat(20)}`,
};
const fixtureQuestId = '11111111-1111-4111-8111-111111111111';
const fixtureMissionId = '22222222-2222-4222-8222-222222222222';
const testUserToken = 'header.payload.signature';

test('probe sends only malformed input and reports every function status', async () => {
  const calls = [];
  const results = await verifyHostedAiAuthBoundary({
    ...config,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      return new Response(null, { status: 401 });
    },
  });
  assert.equal(results.length, 10);
  assert.equal(calls.length, 10);
  assert.ok(results.every(({ status }) => status === 401));
  assert.equal(hasExpectedAiAuthStatuses(results), true);
  assert.ok(calls.every(({ options }) => options.body === '{'));
  assert.ok(calls.every(({ options }) => options.headers.Authorization === `Bearer ${config.publishableKey}`));
});

test('probe rejects non-hosted URLs and non-publishable keys', async () => {
  await assert.rejects(verifyHostedAiAuthBoundary({ ...config, url: 'http://localhost:54321' }));
  await assert.rejects(verifyHostedAiAuthBoundary({ ...config, publishableKey: 'service-role-key' }));
});

test('signed-in probe verifies Auth before reaching the functions', async () => {
  const token = 'header.payload.signature';
  const calls = [];
  const results = await verifyHostedSignedInAiPath({
    ...config,
    userAccessToken: token,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith('/auth/v1/user')) {
        return Response.json({ id: 'test-user' });
      }
      return new Response(null, {
        status: url.endsWith('/moderate-quest-intent') ? 200 : 400,
      });
    },
  });
  assert.equal(calls.length, 11);
  assert.ok(calls[0].url.endsWith('/auth/v1/user'));
  assert.equal(results.length, 10);
  assert.equal(hasExpectedAiAuthStatuses(results, true), true);
  assert.ok(calls.slice(1).every(({ options }) =>
    options.body === '{' && options.headers.Authorization === `Bearer ${token}`));
});

test('rejected or malformed user token never reaches AI functions', async () => {
  let calls = 0;
  await assert.rejects(verifyHostedSignedInAiPath({
    ...config,
    userAccessToken: 'not-a-user-token',
    fetchImpl: async () => { calls++; return Response.json({ id: 'test-user' }); },
  }));
  assert.equal(calls, 0);

  await assert.rejects(verifyHostedSignedInAiPath({
    ...config,
    userAccessToken: 'header.payload.signature',
    fetchImpl: async () => { calls++; return new Response(null, { status: 401 }); },
  }));
  assert.equal(calls, 1);
});

test('release contract rejects a missing function or a signed-in 401', () => {
  const names = [
    'arc-chat', 'arc-quest-guide', 'generate-arc-advice', 'generate-mission',
    'generate-quest-guides', 'generate-star-map', 'moderate-quest-intent',
    'quest-planning-tools',
    'quest-planning-v2', 'research-mission-resources',
  ];
  const anonymous = names.map((functionName) => ({ functionName, status: 401 }));
  const signedIn = names.map((functionName) => ({
    functionName,
    status: functionName === 'moderate-quest-intent' ? 200 : 400,
  }));
  assert.equal(hasExpectedAiAuthStatuses(anonymous), true);
  assert.equal(hasExpectedAiAuthStatuses(signedIn, true), true);
  const missingConsent = signedIn.map((item) => item.functionName === 'arc-chat'
    ? { ...item, status: 403 }
    : item);
  assert.equal(hasExpectedAiAuthStatuses(missingConsent, true, 'missing'), true);
  assert.equal(hasExpectedAiAuthStatuses(missingConsent, true, 'granted'), false);
  assert.equal(hasExpectedAiAuthStatuses(missingConsent, true, 'unknown'), false);
  assert.equal(hasExpectedAiAuthStatuses([
    { ...missingConsent[0], status: 503 }, ...missingConsent.slice(1),
  ], true, 'missing'), false);
  assert.equal(hasExpectedAiAuthStatuses(anonymous.slice(1)), false);
  assert.equal(hasExpectedAiAuthStatuses([
    ...anonymous.slice(0, -1), anonymous[0],
  ]), false);
  assert.equal(hasExpectedAiAuthStatuses([
    { ...signedIn[0], status: 401 }, ...signedIn.slice(1),
  ], true), false);
});

test('missing-consent probe sends synthetic valid inputs and requires the exact denial code', async () => {
  const calls = [];
  const results = await verifyHostedMissingConsentDenial({
    ...config,
    userAccessToken: 'header.payload.signature',
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith('/auth/v1/user')) return Response.json({ id: 'test-user' });
      return Response.json({ error: 'consent_required' }, { status: 403 });
    },
  });
  assert.equal(calls.length, 9);
  assert.equal(results.length, 8);
  assert.equal(hasExpectedMissingConsentDenialStatuses(results), true);
  assert.ok(calls.slice(1).every(({ options }) => {
    const payload = JSON.parse(options.body);
    return options.headers.Authorization === `Bearer ${testUserToken}`
      && typeof payload === 'object' && payload !== null;
  }));
  assert.ok(calls.every(({ url }) => !url.endsWith('/quest-planning-v2')
    && !url.endsWith('/research-mission-resources')));
  assert.equal(hasExpectedMissingConsentDenialStatuses([
    { ...results[0], errorCode: null }, ...results.slice(1),
  ]), false);
  assert.equal(hasExpectedMissingConsentDenialStatuses([
    { ...results[0], status: 503 }, ...results.slice(1),
  ]), false);
  assert.equal(hasExpectedMissingConsentDenialStatuses(results.slice(1)), false);
});

test('missing-consent probe stops before other AI calls on the first unexpected response', async () => {
  const calls = [];
  const results = await verifyHostedMissingConsentDenial({
    ...config,
    userAccessToken: 'header.payload.signature',
    fetchImpl: async (url) => {
      calls.push(url);
      return url.endsWith('/auth/v1/user')
        ? Response.json({ id: 'test-user' })
        : Response.json({ message: 'unexpected AI result' });
    },
  });
  assert.equal(calls.length, 2);
  assert.equal(results.length, 1);
  assert.equal(hasExpectedMissingConsentDenialStatuses(results), false);
});

test('owned disposable fixtures extend the denial probe to planning and research', async () => {
  const calls = [];
  const results = await verifyHostedMissingConsentDenial({
    ...config,
    userAccessToken: 'header.payload.signature',
    fixtureQuestId,
    fixtureMissionId,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      return url.endsWith('/auth/v1/user')
        ? Response.json({ id: 'test-user' })
        : Response.json({ error: 'consent_required' }, { status: 403 });
    },
  });
  assert.equal(calls.length, 11);
  assert.equal(results.length, 10);
  assert.equal(hasExpectedMissingConsentDenialStatuses(results, true), true);
  assert.equal(hasExpectedMissingConsentDenialStatuses(results), false);
  const planning = calls.find(({ url }) => url.endsWith('/quest-planning-v2'));
  const research = calls.find(({ url }) => url.endsWith('/research-mission-resources'));
  assert.equal(JSON.parse(planning.options.body).quest_id, fixtureQuestId);
  assert.equal(JSON.parse(research.options.body).mission.id, fixtureMissionId);
  assert.equal(JSON.parse(research.options.body).force_refresh, true);
});

test('incomplete or malformed owned fixtures fail before Auth or AI requests', async () => {
  let calls = 0;
  for (const fixtures of [
    { fixtureQuestId },
    { fixtureMissionId },
    { fixtureQuestId: 'not-a-uuid', fixtureMissionId },
  ]) {
    await assert.rejects(verifyHostedMissingConsentDenial({
      ...config,
      ...fixtures,
      userAccessToken: 'header.payload.signature',
      fetchImpl: async () => { calls++; return Response.json({ id: 'test-user' }); },
    }));
  }
  assert.equal(calls, 0);
});
