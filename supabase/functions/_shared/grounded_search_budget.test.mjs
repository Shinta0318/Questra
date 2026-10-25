import assert from 'node:assert/strict';
import test from 'node:test';

import { groundedMissionSearch } from './grounded_search_provider.ts';

const userId = '00000000-0000-4000-8000-000000000001';
const config = {
  GEMINI_API_KEY: 'test-model-key',
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'test-server-key',
};

async function withMock(fetchImpl, action, environment = config) {
  const previousDeno = globalThis.Deno;
  const previousFetch = globalThis.fetch;
  globalThis.Deno = { env: { get: (name) => environment[name] } };
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

test('grounded search requires an authenticated user before any request', async () => {
  let calls = 0;
  await withMock(async () => { calls++; throw new Error('Unexpected call'); }, async () => {
    assert.equal(await groundedMissionSearch({}, {
      userId: 'invalid-user',
      operation: 'mission_research',
    }), null);
  });
  assert.equal(calls, 0);
});

test('grounding budget denial prevents the Google Search tool call', async () => {
  const urls = [];
  await withMock(async (url) => {
    urls.push(url);
    if (url.endsWith('/reserve_ai_usage_budget_v2')) {
      return Response.json({ allowed: false, reason: 'monthly_limit' });
    }
    throw new Error('Unexpected request');
  }, async () => {
    assert.equal(await groundedMissionSearch({}, {
      userId,
      operation: 'mission_research',
    }), null);
  });
  assert.equal(urls.length, 1);
});

test('grounded search reserves query budget and settles verified tokens and query count', async () => {
  const calls = [];
  await withMock(async (url, init) => {
    calls.push({ url, body: init?.body ? JSON.parse(init.body) : null });
    if (url.endsWith('/reserve_ai_usage_budget_v2')) {
      return Response.json({ allowed: true, reservation_id: 'reservation-1' });
    }
    if (url.endsWith('/reserve_ai_grounding_budget')) {
      return Response.json({ allowed: true });
    }
    if (url.includes('generativelanguage.googleapis.com')) {
      return Response.json({
        id: 'interaction-1',
        status: 'completed',
        steps: [
          { type: 'google_search_call', arguments: { queries: ['official travel advice'] } },
          { type: 'google_search_result', sources: [{
            uri: 'https://www.example.org/travel', title: 'Official guidance',
          }] },
          { type: 'model_output', content: [{ text: JSON.stringify({
            summary: 'Check the official source.', checkpoints: ['Read guidance'], cautions: [],
          }) }] },
        ],
        usage: { total_input_tokens: 22, total_output_tokens: 11 },
      });
    }
    if (url.endsWith('/record_ai_provider_execution_receipt_v3')) {
      return Response.json({ recorded: true });
    }
    if (url.endsWith('/settle_ai_usage_budget')) {
      return Response.json({ settled: true });
    }
    throw new Error(`Unexpected request: ${url}`);
  }, async () => {
    const result = await groundedMissionSearch({ mission: 'Plan a trip' }, {
      userId,
      operation: 'mission_research',
    });
    assert.equal(result?.sourceType, 'gemini_google_search_grounding');
    assert.equal(result?.sources[0].url, 'https://www.example.org/travel');
  });
  const urls = calls.map(({ url }) => url);
  assert.ok(urls.findIndex((url) => url.endsWith('/reserve_ai_grounding_budget')) <
    urls.findIndex((url) => url.includes('generativelanguage.googleapis.com')));
  const receipt = calls.find(({ url }) => url.endsWith('/record_ai_provider_execution_receipt_v3'));
  assert.equal(receipt.body.p_grounding_query_count, 1);
  assert.equal(receipt.body.p_input_tokens, 22);
  const reservation = calls.find(({ url }) => url.endsWith('/reserve_ai_usage_budget_v2'));
  assert.equal(reservation.body.p_operation, 'detailed_progress_review');
});

test('search output without a source is not presented as grounded guidance', async () => {
  await withMock(async (url) => {
    if (url.endsWith('/reserve_ai_usage_budget_v2')) {
      return Response.json({ allowed: true, reservation_id: 'reservation-2' });
    }
    if (url.endsWith('/reserve_ai_grounding_budget')) {
      return Response.json({ allowed: true });
    }
    if (url.includes('generativelanguage.googleapis.com')) {
      return Response.json({
        status: 'completed',
        steps: [
          { type: 'google_search_call', query: 'official source' },
          { type: 'model_output', content: [{ text: JSON.stringify({
            summary: 'Unverifiable.', checkpoints: [], cautions: [],
          }) }] },
        ],
        usage: { total_input_tokens: 10, total_output_tokens: 5 },
      });
    }
    if (url.endsWith('/record_ai_provider_execution_receipt_v3')) {
      return Response.json({ recorded: true });
    }
    if (url.endsWith('/settle_ai_usage_budget')) {
      return Response.json({ settled: true });
    }
    throw new Error(`Unexpected request: ${url}`);
  }, async () => {
    assert.equal(await groundedMissionSearch({}, {
      userId,
      operation: 'arc_grounded_search',
    }), null);
  });
});

test('query-less search call does not silently settle as zero billable queries', async () => {
  const calls = [];
  await withMock(async (url) => {
    calls.push(url);
    if (url.endsWith('/reserve_ai_usage_budget_v2')) {
      return Response.json({ allowed: true, reservation_id: 'reservation-3' });
    }
    if (url.endsWith('/reserve_ai_grounding_budget')) {
      return Response.json({ allowed: true });
    }
    if (url.includes('generativelanguage.googleapis.com')) {
      return Response.json({
        status: 'completed',
        steps: [
          { type: 'google_search_call', id: 'search-1' },
          { type: 'google_search_result', sources: [{ uri: 'https://www.example.org/source' }] },
          { type: 'model_output', content: [{ text: JSON.stringify({
            summary: 'Unknown billing.', checkpoints: [], cautions: [],
          }) }] },
        ],
        usage: { total_input_tokens: 10, total_output_tokens: 5 },
      });
    }
    throw new Error(`Unexpected request: ${url}`);
  }, async () => {
    assert.equal(await groundedMissionSearch({}, {
      userId,
      operation: 'mission_research',
    }), null);
  });
  assert.ok(calls.some((url) => url.includes('generativelanguage.googleapis.com')));
  assert.ok(!calls.some((url) => url.endsWith('/settle_ai_usage_budget')));
});
