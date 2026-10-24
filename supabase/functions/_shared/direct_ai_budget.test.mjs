import assert from 'node:assert/strict';
import test from 'node:test';

import { generateAiText } from './ai_provider.ts';

const userId = '00000000-0000-4000-8000-000000000001';
const options = {
  userId,
  feature: 'arc_chat',
  promptVersion: 'arc_chat_v2',
  systemInstruction: 'Answer concisely.',
  input: { message: 'test wish' },
  maxOutputTokens: 256,
};

async function withProviderEnvironment(values, fetchImpl, action) {
  const previousDeno = globalThis.Deno;
  const previousFetch = globalThis.fetch;
  globalThis.Deno = { env: { get: (name) => values[name] } };
  globalThis.fetch = (url, init) => url.endsWith('/has_current_ai_legal_acceptance')
    ? Response.json(true)
    : fetchImpl(url, init);
  try {
    return await action();
  } finally {
    globalThis.Deno = previousDeno;
    globalThis.fetch = previousFetch;
  }
}

const baseEnvironment = {
  GEMINI_API_KEY: 'test-model-key',
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'test-server-key',
};

test('budget denial stops a direct Arc call before Gemini', async () => {
  const calls = [];
  await withProviderEnvironment(baseEnvironment, async (url) => {
    calls.push(url);
    if (url.endsWith('/reserve_ai_usage_budget_v2')) {
      return Response.json({ allowed: false, reason: 'monthly_limit' });
    }
    return new Response(null, { status: 201 });
  }, async () => {
    assert.equal(await generateAiText(options), null);
  });
  assert.equal(calls.filter((url) => url.includes('generativelanguage.googleapis.com')).length, 0);
  assert.equal(calls.filter((url) => url.endsWith('/reserve_ai_usage_budget_v2')).length, 1);
});

test('missing budget service configuration fails before the model call', async () => {
  let calls = 0;
  await withProviderEnvironment({ GEMINI_API_KEY: 'test-model-key' }, async () => {
    calls++;
    throw new Error('Unexpected network call');
  }, async () => {
    assert.equal(await generateAiText(options), null);
  });
  assert.equal(calls, 0);
});

test('direct Arc call reserves budget, calls Gemini, and settles actual usage', async () => {
  const calls = [];
  await withProviderEnvironment(baseEnvironment, async (url, init) => {
    calls.push({ url, body: init?.body ? JSON.parse(init.body) : null });
    if (url.endsWith('/reserve_ai_usage_budget_v2')) {
      return Response.json({ allowed: true, reservation_id: 'reservation-1' });
    }
    if (url.includes('generativelanguage.googleapis.com')) {
      return Response.json({
        id: 'interaction-1',
        status: 'completed',
        steps: [{ type: 'model_output', content: [{ text: 'A useful reply.' }] }],
        usage: { total_input_tokens: 20, total_output_tokens: 10 },
      });
    }
    if (url.endsWith('/record_ai_provider_execution_receipt_v3')) {
      return Response.json({ recorded: true });
    }
    if (url.endsWith('/settle_ai_usage_budget')) {
      return Response.json({ settled: true });
    }
    return new Response(null, { status: 201 });
  }, async () => {
    const result = await generateAiText(options);
    assert.equal(result?.text, 'A useful reply.');
    assert.equal(result?.sourceType, 'gemini_interactions');
  });
  const urls = calls.map(({ url }) => url);
  assert.ok(urls.findIndex((url) => url.endsWith('/reserve_ai_usage_budget_v2')) <
    urls.findIndex((url) => url.includes('generativelanguage.googleapis.com')));
  assert.ok(urls.findIndex((url) => url.includes('generativelanguage.googleapis.com')) <
    urls.findIndex((url) => url.endsWith('/settle_ai_usage_budget')));
  const receipt = calls.find(({ url }) => url.endsWith('/record_ai_provider_execution_receipt_v3'));
  assert.equal(receipt.body.p_input_tokens, 20);
  assert.equal(receipt.body.p_output_tokens, 10);
  const reservation = calls.find(({ url }) => url.endsWith('/reserve_ai_usage_budget_v2'));
  assert.equal(reservation.body.p_user_id, userId);
  assert.equal(reservation.body.p_operation, 'arc_consultation');
});

test('direct OpenAI path stays closed until budget admission exists', async () => {
  let modelCalls = 0;
  await withProviderEnvironment({ ...baseEnvironment, AI_PROVIDER: 'openai' }, async () => {
    modelCalls++;
    return new Response(null, { status: 201 });
  }, async () => {
    assert.equal(await generateAiText(options), null);
  });
  assert.equal(modelCalls, 1); // Usage telemetry only.
});

test('provider response without billable usage is not returned as a success', async () => {
  const calls = [];
  await withProviderEnvironment(baseEnvironment, async (url) => {
    calls.push(url);
    if (url.endsWith('/reserve_ai_usage_budget_v2')) {
      return Response.json({ allowed: true, reservation_id: 'reservation-2' });
    }
    if (url.includes('generativelanguage.googleapis.com')) {
      return Response.json({
        id: 'interaction-2',
        status: 'completed',
        steps: [{ type: 'model_output', content: [{ text: 'Unbilled reply.' }] }],
      });
    }
    return new Response(null, { status: 201 });
  }, async () => {
    assert.equal(await generateAiText(options), null);
  });
  assert.ok(calls.some((url) => url.includes('generativelanguage.googleapis.com')));
  assert.ok(!calls.some((url) => url.endsWith('/settle_ai_usage_budget')));
});
