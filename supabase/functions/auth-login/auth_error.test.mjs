import assert from 'node:assert/strict';
import test from 'node:test';

import { authErrorCode, classifyAuthFailure } from './auth_error.ts';

test('recognizes current Supabase Auth REST error responses', () => {
  assert.equal(authErrorCode({ code: 400, error_code: 'invalid_credentials' }), 'invalid_credentials');
  assert.equal(authErrorCode({ code: 400, error_code: 'email_not_confirmed' }), 'email_not_confirmed');
});

test('supports legacy string codes without treating HTTP status as an error code', () => {
  assert.equal(authErrorCode({ code: 'invalid_credentials' }), 'invalid_credentials');
  assert.equal(authErrorCode({ code: 400 }), null);
  assert.equal(authErrorCode({}), null);
});

test('Auth 5xx and rate limits take precedence over a misleading body code', () => {
  const misleading = { error_code: 'invalid_credentials' };
  assert.equal(classifyAuthFailure(503, misleading), 'unavailable');
  assert.equal(classifyAuthFailure(429, misleading), 'rate_limited');
  assert.equal(classifyAuthFailure(400, misleading), 'invalid_credentials');
  assert.equal(classifyAuthFailure(400, { error_code: 'email_not_confirmed' }), 'unconfirmed');
  assert.equal(classifyAuthFailure(400, { error_code: 'unexpected_failure' }), 'other');
  assert.equal(classifyAuthFailure(401, {}), 'other');
});
