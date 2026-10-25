import assert from 'node:assert/strict';
import test from 'node:test';

import {
  HostedLoginCheckError,
  verifyHostedLoginRoundTrip,
} from './verify_hosted_login_roundtrip.mjs';

const userId = '12345678-1234-4234-8234-123456789abc';
const config = {
  url: 'https://example.supabase.co',
  publishableKey: `sb_publishable_${'a'.repeat(20)}`,
  identifier: 'test-id',
  password: 'example-test-password',
};

test('verifies login, Auth user, and owner profile without returning secrets', async () => {
  const calls = [];
  const result = await verifyHostedLoginRoundTrip({
    ...config,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith('/auth-login')) {
        return Response.json({ access_token: 'token', refresh_token: 'refresh' });
      }
      if (url.endsWith('/auth/v1/user')) return Response.json({ id: userId });
      return Response.json([{ id: userId }]);
    },
  });
  assert.deepEqual(result, {
    login: 'passed', authUser: 'passed', ownerProfile: 'passed',
  });
  assert.equal(calls.length, 3);
  assert.equal(calls[0].options.headers.Authorization, `Bearer ${config.publishableKey}`);
  assert.equal(calls[1].options.headers.Authorization, 'Bearer token');
  assert.equal(calls[2].options.headers.Authorization, 'Bearer token');
  assert.ok(calls[2].url.includes('user_profiles'));
  assert.ok(calls[2].url.includes(encodeURIComponent(`eq.${userId}`)));
  assert.ok(!JSON.stringify(result).includes('token'));
});

test('bad credentials stop before Auth and profile probes', async () => {
  let calls = 0;
  await assert.rejects(verifyHostedLoginRoundTrip({
    ...config,
    fetchImpl: async () => {
      calls++;
      return Response.json({ code: 'invalid_credentials' }, { status: 401 });
    },
  }), (error) => error instanceof HostedLoginCheckError &&
    error.stage === 'login' && error.status === 401 &&
    !error.message.includes(config.password));
  assert.equal(calls, 1);
});

test('Auth rejection and missing owner profile fail independently', async () => {
  for (const stopAt of ['auth_user', 'profile']) {
    let calls = 0;
    await assert.rejects(verifyHostedLoginRoundTrip({
      ...config,
      fetchImpl: async (url) => {
        calls++;
        if (url.endsWith('/auth-login')) {
          return Response.json({ access_token: 'token', refresh_token: 'refresh' });
        }
        if (url.endsWith('/auth/v1/user')) {
          return stopAt === 'auth_user'
            ? Response.json({}, { status: 401 })
            : Response.json({ id: userId });
        }
        return Response.json([]);
      },
    }), (error) => error instanceof HostedLoginCheckError && error.stage === stopAt);
    assert.equal(calls, stopAt === 'auth_user' ? 2 : 3);
  }
});

test('malformed success and transport failures fail closed without credential output', async () => {
  await assert.rejects(verifyHostedLoginRoundTrip({
    ...config,
    fetchImpl: async () => Response.json({ access_token: 'token' }),
  }), (error) => error.stage === 'login' &&
    !error.message.includes(config.identifier));
  await assert.rejects(verifyHostedLoginRoundTrip({
    ...config,
    fetchImpl: async () => { throw new Error(config.password); },
  }), (error) => error.stage === 'login' &&
    !error.message.includes(config.password));
  await assert.rejects(verifyHostedLoginRoundTrip({
    ...config,
    fetchImpl: async () => Response.json(null),
  }), (error) => error.stage === 'login');
  await assert.rejects(verifyHostedLoginRoundTrip({
    ...config,
    fetchImpl: async (url) => url.endsWith('/auth-login')
      ? Response.json({ access_token: 'token', refresh_token: 'refresh' })
      : Response.json(null),
  }), (error) => error.stage === 'auth_user');
});

test('rejects local or non-Supabase targets and missing credentials', async () => {
  for (const override of [
    { url: 'http://127.0.0.1:54321' },
    { url: 'https://example.supabase.co/other' },
    { url: 'https://example.supabase.co:8443/' },
    { url: 'https://user@example.supabase.co/' },
    { publishableKey: 'service-role-key' },
    { password: '' },
  ]) {
    await assert.rejects(verifyHostedLoginRoundTrip({
      ...config, ...override,
      fetchImpl: () => { throw new Error('must not call'); },
    }), (error) => error.stage === 'configuration');
  }
});
