import assert from 'node:assert/strict';
import test from 'node:test';

import { authenticatedAiUser } from './ai_auth.ts';
import { generateAiText } from './ai_provider.ts';

const userId = '00000000-0000-4000-8000-000000000001';
const fakeJwt = 'header.payload.signature';
const config = {
  supabaseUrl: 'https://example.supabase.co',
  anonKey: 'test-anon-key',
};

test('AI auth rejects missing and publishable credentials without contacting Auth', async () => {
  let calls = 0;
  const fetchImpl = async () => {
    calls++;
    return Response.json({ id: userId });
  };
  for (const authorization of [null, 'Bearer sb_publishable_testkey']) {
    const headers = authorization ? { Authorization: authorization } : {};
    const request = new Request('https://example.com', { headers });
    assert.equal(await authenticatedAiUser(request, { ...config, fetchImpl }), null);
  }
  assert.equal(calls, 0);
});

test('AI auth accepts only a user confirmed by Supabase Auth', async () => {
  const request = new Request('https://example.com', {
    headers: { Authorization: `Bearer ${fakeJwt}` },
  });
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({ url, options });
    return Response.json({ id: userId });
  };
  assert.equal(await authenticatedAiUser(request, { ...config, fetchImpl }), userId);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://example.supabase.co/auth/v1/user');
  assert.equal(calls[0].options.headers.Authorization, `Bearer ${fakeJwt}`);
});

test('AI auth fails closed on invalid user, rejected token, or network failure', async () => {
  const request = new Request('https://example.com', {
    headers: { Authorization: `Bearer ${fakeJwt}` },
  });
  for (const fetchImpl of [
    async () => Response.json({ id: 'not-a-user-id' }),
    async () => Response.json({ error: 'invalid_token' }, { status: 401 }),
    async () => { throw new Error('network unavailable'); },
  ]) {
    assert.equal(await authenticatedAiUser(request, { ...config, fetchImpl }), null);
  }
});

test('shared AI provider does not call a model without a verified user ID', async () => {
  assert.equal(await generateAiText({ systemInstruction: 'test', input: {} }), null);
});

test('all direct AI functions reject an API key without a user session', async () => {
  const previousDeno = globalThis.Deno;
  const previousFetch = globalThis.fetch;
  const handlers = [];
  let userLookups = 0;
  globalThis.Deno = {
    env: { get: (name) => ({
      SUPABASE_URL: config.supabaseUrl,
      SUPABASE_ANON_KEY: config.anonKey,
    })[name] },
    serve: (handler) => handlers.push(handler),
  };
  try {
    for (const name of [
      'arc-chat',
      'arc-quest-guide',
      'generate-arc-advice',
      'generate-mission',
      'generate-quest-guides',
      'generate-star-map',
      'moderate-quest-intent',
    ]) {
      const before = handlers.length;
      await import(`../${name}/index.ts`);
      assert.equal(handlers.length, before + 1, `${name} registered a handler`);
      const request = new Request('https://example.com/functions/v1/' + name, {
        method: 'POST',
        headers: {
          apikey: 'sb_publishable_testkey',
          Authorization: 'Bearer sb_publishable_testkey',
          'Content-Type': 'application/json',
        },
        body: '{}',
      });
      const response = await handlers.at(-1)(request);
      assert.equal(response.status, 401, `${name} must reject anonymous AI use`);
      assert.equal((await response.json()).error, 'authentication_required');

      globalThis.fetch = async (url) => {
        assert.equal(String(url), 'https://example.supabase.co/auth/v1/user');
        userLookups++;
        return Response.json({ id: userId });
      };
      const signedInRequest = new Request('https://example.com/functions/v1/' + name, {
        method: 'POST',
        headers: {
          apikey: 'sb_publishable_testkey',
          Authorization: `Bearer ${fakeJwt}`,
          'Content-Type': 'application/json',
        },
        body: '{}',
      });
      const signedInResponse = await handlers.at(-1)(signedInRequest);
      assert.notEqual(signedInResponse.status, 401, `${name} must admit a verified user`);
      globalThis.fetch = previousFetch;
    }
    assert.equal(userLookups, 7);
  } finally {
    globalThis.Deno = previousDeno;
    globalThis.fetch = previousFetch;
  }
});
