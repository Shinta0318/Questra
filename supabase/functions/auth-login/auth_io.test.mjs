import assert from 'node:assert/strict';
import test from 'node:test';

import { requestPasswordGrant, runLoginDecisionRpc } from './auth_io.ts';

test('password grant uses the configured Auth endpoint and does not log input', async () => {
  const calls = [];
  const response = await requestPasswordGrant(
    'https://example.supabase.co',
    'public-key',
    'test@example.com',
    'test-password',
    async (url, options) => {
      calls.push({ url, options });
      return Response.json({ access_token: 'token' });
    },
  );
  assert.equal(response.status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://example.supabase.co/auth/v1/token?grant_type=password');
  assert.deepEqual(JSON.parse(calls[0].options.body), {
    email: 'test@example.com', password: 'test-password',
  });
  assert.equal(calls[0].options.headers.apikey, 'public-key');
  assert.equal(calls[0].options.headers.authorization, undefined);
  assert.ok(calls[0].options.signal instanceof AbortSignal);
});

test('password grant returns no response when transport fails', async () => {
  const response = await requestPasswordGrant(
    'https://example.supabase.co', 'public-key', 'test@example.com',
    'test-password', async () => { throw new Error('test-password'); },
  );
  assert.equal(response, null);
});

test('login decision requires an explicit updated row result', async () => {
  assert.equal(await runLoginDecisionRpc(async () => ({ data: { status: 'recorded' }, error: null })), 'recorded');
  assert.equal(await runLoginDecisionRpc(async () => ({ data: { status: 'locked' }, error: null })), 'locked');
  assert.equal(await runLoginDecisionRpc(async () => ({ data: { status: 'missing' }, error: null })), 'unavailable');
  assert.equal(await runLoginDecisionRpc(async () => ({ data: null, error: null })), 'unavailable');
  assert.equal(await runLoginDecisionRpc(async () => ({ data: { status: 'recorded' }, error: new Error('db') })), 'unavailable');
  assert.equal(await runLoginDecisionRpc(async () => { throw new Error('db'); }), 'unavailable');
});
