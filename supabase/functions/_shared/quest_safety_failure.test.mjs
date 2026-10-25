import assert from 'node:assert/strict';
import test from 'node:test';

const userId = '33333333-3333-4333-8333-333333333333';

test('moderation outage does not approve an unclassified Quest', async () => {
  const previousDeno = globalThis.Deno;
  const previousFetch = globalThis.fetch;
  let handler;
  const calls = [];
  const env = {
    SUPABASE_URL: 'https://example.supabase.co',
    SUPABASE_ANON_KEY: 'test-anon',
    SUPABASE_SERVICE_ROLE_KEY: 'test-service-role',
    AI_PROVIDER: 'openai',
  };
  globalThis.Deno = {
    env: { get: (name) => env[name] },
    serve: (callback) => { handler = callback; },
  };
  globalThis.fetch = async (url) => {
    calls.push(String(url));
    if (String(url).endsWith('/auth/v1/user')) return Response.json({ id: userId });
    if (String(url).endsWith('/rpc/has_current_ai_legal_acceptance')) {
      return Response.json(true);
    }
    if (String(url).endsWith('/rest/v1/ai_usage_events')) {
      return new Response(null, { status: 201 });
    }
    throw new Error('Unexpected external request');
  };
  try {
    await import('../moderate-quest-intent/index.ts');
    const response = await handler(new Request(
      'https://example.supabase.co/functions/v1/moderate-quest-intent', {
        method: 'POST',
        headers: { Authorization: 'Bearer a.b.c' },
        body: JSON.stringify({ input: '料理を学びたい' }),
      },
    ));
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { error: 'safety_check_unavailable' });
    assert.ok(calls.some((url) => url.endsWith('/rpc/has_current_ai_legal_acceptance')));
    assert.ok(!calls.some((url) => url.includes('generativelanguage.googleapis.com')));
  } finally {
    globalThis.fetch = previousFetch;
    if (previousDeno === undefined) delete globalThis.Deno;
    else globalThis.Deno = previousDeno;
  }
});
