import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

import { currentAiLegalGate } from './ai_legal_gate.ts';
import { callGeminiInteraction } from './quest_planning/interactions_adapter.ts';

const userId = '33333333-3333-4333-8333-333333333333';
const base = {
  supabaseUrl: 'https://example.supabase.co',
  serviceRoleKey: 'test-service-role',
};

test('legal gate rejects an invalid user without a database call', async () => {
  let calls = 0;
  assert.equal(await currentAiLegalGate('not-a-user', {
    ...base,
    fetchImpl: async () => {
      calls++;
      return Response.json(true);
    },
  }), 'denied');
  assert.equal(calls, 0);
});

test('legal gate accepts only an explicit true from the service-only RPC', async () => {
  const requests = [];
  const fetchImpl = async (url, init) => {
    requests.push({ url, init });
    return Response.json(true);
  };
  assert.equal(await currentAiLegalGate(userId, { ...base, fetchImpl }), 'granted');
  assert.equal(requests[0].url,
    'https://example.supabase.co/rest/v1/rpc/has_current_ai_legal_acceptance');
  assert.equal(requests[0].init.method, 'POST');
  assert.deepEqual(JSON.parse(requests[0].init.body), { p_user_id: userId });
  assert.equal(requests[0].init.headers.Authorization, 'Bearer test-service-role');

  for (const body of [false, null, { allowed: true }]) {
    const result = await currentAiLegalGate(userId, {
      ...base,
      fetchImpl: async () => Response.json(body),
    });
    assert.equal(result, body === false ? 'denied' : 'unavailable');
  }
});

test('legal gate fails closed when the database is unavailable', async () => {
  assert.equal(await currentAiLegalGate(userId, {
    ...base,
    fetchImpl: async () => Response.json({ error: 'missing_rpc' }, { status: 404 }),
  }), 'unavailable');
  assert.equal(await currentAiLegalGate(userId, {
    ...base,
    fetchImpl: async () => { throw new Error('network unavailable'); },
  }), 'unavailable');
});

test('Arc HTTP guard returns distinct consent and availability errors', async () => {
  const previousDeno = globalThis.Deno;
  const previousFetch = globalThis.fetch;
  globalThis.Deno = {
    env: { get: (name) => ({
      SUPABASE_URL: base.supabaseUrl,
      SUPABASE_SERVICE_ROLE_KEY: base.serviceRoleKey,
    })[name] },
  };
  try {
    const { aiLegalFailureResponse } = await import('./ai_legal_http.ts');
    for (const [rpcBody, expectedStatus, expectedError] of [
      [false, 403, 'consent_required'],
      [null, 503, 'consent_check_unavailable'],
    ]) {
      globalThis.fetch = async () => Response.json(rpcBody);
      const response = await aiLegalFailureResponse(userId);
      assert.equal(response?.status, expectedStatus);
      assert.deepEqual(await response.json(), { error: expectedError });
    }
    globalThis.fetch = async () => Response.json(true);
    assert.equal(await aiLegalFailureResponse(userId), null);
  } finally {
    globalThis.fetch = previousFetch;
    if (previousDeno === undefined) delete globalThis.Deno;
    else globalThis.Deno = previousDeno;
  }
});

test('AI entrypoints retain the server consent guard', () => {
  for (const name of [
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
  ]) {
    const source = readFileSync(new URL(`../${name}/index.ts`, import.meta.url), 'utf8');
    assert.match(source, /await aiLegalFailureResponse\(/, `${name} must verify consent`);
    const guard = source.indexOf('await aiLegalFailureResponse(');
    const provider = [
      'await generateAiText(',
      'await groundedMissionSearch(',
      'await runQuestPlanningPipeline(',
      'await runTaskExpansionPipeline(',
      'await executeQuestraTool(',
    ].map((needle) => source.indexOf(needle)).filter((index) => index >= 0);
    assert.ok(provider.every((index) => guard < index), `${name} must guard before AI work`);
  }
  const planning = readFileSync(new URL('../quest-planning-v2/index.ts', import.meta.url), 'utf8');
  assert.equal(planning.match(/await aiLegalFailureResponse\(/g)?.length, 2);
  assert.ok(planning.indexOf('if (payload.mode === "approve")') < planning.indexOf('await aiLegalFailureResponse('));
  const research = readFileSync(new URL('../research-mission-resources/index.ts', import.meta.url), 'utf8');
  assert.ok(research.indexOf('loadCachedResearch(user.id, mission.id)') < research.indexOf('await aiLegalFailureResponse('));
  assert.ok(research.indexOf('await aiLegalFailureResponse(') < research.indexOf('withinRateLimit(user.id)'));
});

test('direct planning tool calls stop before reading user data without AI consent', async () => {
  const previousDeno = globalThis.Deno;
  const previousFetch = globalThis.fetch;
  let handler;
  const calls = [];
  globalThis.Deno = {
    env: { get: (name) => ({
      SUPABASE_URL: base.supabaseUrl,
      SUPABASE_ANON_KEY: 'test-anon',
      SUPABASE_SERVICE_ROLE_KEY: base.serviceRoleKey,
    })[name] },
    serve: (callback) => { handler = callback; },
  };
  try {
    await import('../quest-planning-tools/index.ts');
    for (const [rpcBody, expectedStatus, expectedError] of [
      [false, 403, 'consent_required'],
      [null, 503, 'consent_check_unavailable'],
    ]) {
      calls.length = 0;
      globalThis.fetch = async (url) => {
        calls.push(String(url));
        if (String(url).endsWith('/auth/v1/user')) return Response.json({ id: userId });
        if (String(url).endsWith('/rest/v1/rpc/has_current_ai_legal_acceptance')) {
          return Response.json(rpcBody);
        }
        throw new Error('tool data must not be read before legal acceptance');
      };
      const response = await handler(new Request('https://example.supabase.co/functions/v1/quest-planning-tools', {
        method: 'POST',
        headers: { Authorization: 'Bearer test-user', 'Content-Type': 'application/json' },
        body: JSON.stringify({ tool: 'get_relevant_arc_memory', arguments: {} }),
      }));
      assert.equal(response.status, expectedStatus);
      assert.deepEqual(await response.json(), { error: expectedError });
      assert.equal(calls.length, 2);
    }
  } finally {
    globalThis.fetch = previousFetch;
    if (previousDeno === undefined) delete globalThis.Deno;
    else globalThis.Deno = previousDeno;
  }
});

test('Gemini adapter checks legal acceptance before budget or model calls', async () => {
  const previousDeno = globalThis.Deno;
  const previousFetch = globalThis.fetch;
  const env = {
    SUPABASE_URL: base.supabaseUrl,
    SUPABASE_SERVICE_ROLE_KEY: base.serviceRoleKey,
    GEMINI_API_KEY: 'test-key',
  };
  const request = {
    operation: 'test',
    modelRole: 'quest_understanding',
    promptVersion: 'test-v1',
    schemaVersion: 'test-v1',
    systemInstruction: 'test',
    input: { wish: 'test' },
    idempotencyKey: 'test-key',
    traceId: '22222222-2222-4222-8222-222222222222',
    userId,
  };
  globalThis.Deno = { env: { get: (name) => env[name] } };
  try {
    for (const [rpcBody, expectedCode] of [[false, 'consent_required'],
      [null, 'unavailable']]) {
      const calls = [];
      globalThis.fetch = async (url) => {
        calls.push(String(url));
        return Response.json(rpcBody);
      };
      const result = await callGeminiInteraction(request);
      assert.equal(result.error?.code, expectedCode);
      assert.equal(calls.length, 1);
      assert.ok(calls[0].endsWith('/rpc/has_current_ai_legal_acceptance'));
    }

    const calls = [];
    globalThis.fetch = async (url) => {
      calls.push(String(url));
      if (String(url).endsWith('/rpc/has_current_ai_legal_acceptance')) {
        return Response.json(true);
      }
      if (String(url).endsWith('/rpc/reserve_ai_usage_budget_v2')) {
        return Response.json({ allowed: false, reason: 'quota_exhausted' });
      }
      throw new Error('No Gemini call should occur when budget denies');
    };
    const result = await callGeminiInteraction(request);
    assert.equal(result.error?.code, 'budget_exhausted');
    assert.equal(calls.length, 2);
  } finally {
    globalThis.fetch = previousFetch;
    if (previousDeno === undefined) delete globalThis.Deno;
    else globalThis.Deno = previousDeno;
  }
});
