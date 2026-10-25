import assert from 'node:assert/strict';
import test from 'node:test';

import { readBoundedJsonObject } from './bounded_request.ts';

function request(body, headers) {
  return new Request('https://example.supabase.co/functions/v1/auth-login', {
    method: 'POST', body, headers,
  });
}

test('accepts a bounded JSON object', async () => {
  assert.deepEqual(await readBoundedJsonObject(
    request(JSON.stringify({ identifier: 'test-id', password: 'secret' })), 4096,
  ), {
    kind: 'ok', value: { identifier: 'test-id', password: 'secret' },
  });
});

test('rejects null, array, and malformed JSON without throwing', async () => {
  for (const body of ['null', '[]', '{']) {
    assert.deepEqual(await readBoundedJsonObject(request(body), 4096), {
      kind: 'invalid',
    });
  }
});

test('enforces actual byte length even when the declared length is smaller', async () => {
  const body = new ReadableStream({
    pull(controller) {
      controller.enqueue(new TextEncoder().encode('あ'.repeat(1500)));
    },
  });
  const input = new Request('https://example.supabase.co/functions/v1/auth-login', {
    method: 'POST', body, duplex: 'half',
    headers: { 'content-length': '1' },
  });
  assert.deepEqual(await readBoundedJsonObject(input, 4096), {
    kind: 'too_large',
  });
});

test('rejects a declared oversized body before reading it', async () => {
  const body = new ReadableStream({
    pull(controller) {
      controller.enqueue(new Uint8Array([123, 125]));
      controller.close();
    },
  });
  const input = new Request('https://example.supabase.co/functions/v1/auth-login', {
    method: 'POST', body, duplex: 'half',
    headers: { 'content-length': '4097' },
  });
  assert.deepEqual(await readBoundedJsonObject(input, 4096), {
    kind: 'too_large',
  });
});

test('counts UTF-8 bytes and rejects invalid encoding', async () => {
  assert.deepEqual(await readBoundedJsonObject(request('あ'), 2), {
    kind: 'too_large',
  });
  assert.deepEqual(await readBoundedJsonObject(
    request(new Uint8Array([0xff])), 4096,
  ), { kind: 'invalid' });
});

test('slow incomplete request reaches the total read deadline', async () => {
  const body = new ReadableStream({
    pull() { return new Promise(() => {}); },
  });
  const input = new Request('https://example.supabase.co/functions/v1/auth-login', {
    method: 'POST', body, duplex: 'half',
  });
  assert.deepEqual(await readBoundedJsonObject(input, 4096, 20), {
    kind: 'timed_out',
  });
});
