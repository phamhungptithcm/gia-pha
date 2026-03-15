import assert from 'node:assert/strict';
import test from 'node:test';

import { shouldExpireInvite } from '../scheduled/invite-expiration';

test('invite expiration contract: pending and active invites expire at/after threshold', () => {
  const nowMillis = Date.UTC(2026, 2, 15, 12, 0, 0);

  assert.equal(
    shouldExpireInvite(
      {
        status: 'pending',
        expiresAt: new Date(nowMillis - 1),
      },
      nowMillis,
    ),
    true,
  );
  assert.equal(
    shouldExpireInvite(
      {
        status: 'active',
        expiresAt: new Date(nowMillis),
      },
      nowMillis,
    ),
    true,
  );
  assert.equal(
    shouldExpireInvite(
      {
        status: 'active',
        expiresAt: new Date(nowMillis + 60_000),
      },
      nowMillis,
    ),
    false,
  );
});

test('invite expiration contract: consumed or missing-expiry invites do not expire', () => {
  const nowMillis = Date.UTC(2026, 2, 15, 12, 0, 0);

  assert.equal(
    shouldExpireInvite(
      {
        status: 'consumed',
        expiresAt: new Date(nowMillis - 60_000),
      },
      nowMillis,
    ),
    false,
  );
  assert.equal(
    shouldExpireInvite(
      {
        status: 'pending',
        expiresAt: null,
      },
      nowMillis,
    ),
    false,
  );
});
