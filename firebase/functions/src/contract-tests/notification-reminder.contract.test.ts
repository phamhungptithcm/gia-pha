import assert from 'node:assert/strict';
import test from 'node:test';

import { __testOnly } from '../events/event-triggers';

test('notification reminder contract: reminder offsets stay unique, positive, and bounded', () => {
  const offsets = __testOnly.normalizeReminderOffsets([
    1440,
    120,
    120,
    -1,
    '60',
    'abc',
    999999,
  ]);
  assert.deepEqual(offsets, [1440, 120, 60]);
});

test('notification reminder contract: yearly recurrence resolves to next upcoming cycle', () => {
  const startsAt = new Date(Date.UTC(2024, 2, 15, 14, 30, 0));
  const now = new Date(Date.UTC(2026, 2, 20, 8, 0, 0));
  const resolved = __testOnly.resolveReminderOccurrenceStart({
    startsAt,
    recurrenceRule: 'FREQ=YEARLY',
    isRecurring: true,
    now,
  });
  assert.equal(resolved?.toISOString(), '2027-03-15T14:30:00.000Z');
});

test('notification reminder contract: dispatch id is deterministic by event+offset+time', () => {
  const left = __testOnly.buildReminderDispatchId({
    eventId: 'event_demo_001',
    reminderAt: new Date(Date.UTC(2026, 2, 20, 7, 0, 0)),
    offsetMinutes: 120,
  });
  const right = __testOnly.buildReminderDispatchId({
    eventId: 'event_demo_001',
    reminderAt: new Date(Date.UTC(2026, 2, 20, 7, 0, 0)),
    offsetMinutes: 120,
  });
  const different = __testOnly.buildReminderDispatchId({
    eventId: 'event_demo_001',
    reminderAt: new Date(Date.UTC(2026, 2, 20, 7, 0, 0)),
    offsetMinutes: 60,
  });

  assert.equal(left, right);
  assert.notEqual(left, different);
});
