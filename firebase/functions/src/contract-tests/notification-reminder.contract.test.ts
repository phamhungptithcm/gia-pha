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

test('notification reminder contract: due-window resolver includes only reminders inside window', () => {
  const now = new Date(Date.UTC(2026, 2, 20, 7, 0, 0));
  const windowStart = new Date(Date.UTC(2026, 2, 20, 6, 0, 0));
  const startsAt = new Date(Date.UTC(2026, 2, 20, 8, 0, 0));
  const due = __testOnly.resolveDueRemindersForWindow({
    startsAt,
    recurrenceRule: null,
    isRecurring: false,
    offsets: [180, 120, 60],
    windowStart,
    now,
  });

  assert.deepEqual(
    due.map((entry) => entry.offsetMinutes),
    [120, 60],
  );
  assert.deepEqual(
    due.map((entry) => entry.reminderAt.toISOString()),
    ['2026-03-20T06:00:00.000Z', '2026-03-20T07:00:00.000Z'],
  );
});

test('notification reminder contract: cursor resolver returns next future reminder', () => {
  const startsAt = new Date(Date.UTC(2026, 2, 20, 8, 0, 0));
  const pointer = __testOnly.resolveNextReminderPointer({
    startsAt,
    recurrenceRule: null,
    isRecurring: false,
    offsets: [180, 120, 60],
    baseline: new Date(Date.UTC(2026, 2, 20, 6, 10, 0)),
  });

  assert.equal(pointer?.offsetMinutes, 60);
  assert.equal(pointer?.reminderAt.toISOString(), '2026-03-20T07:00:00.000Z');
  assert.equal(
    pointer?.occurrenceStartsAt.toISOString(),
    '2026-03-20T08:00:00.000Z',
  );
});

test('notification reminder contract: yearly cursor resolves for next cycle window', () => {
  const startsAt = new Date(Date.UTC(2024, 0, 10, 9, 0, 0));
  const pointer = __testOnly.resolveNextReminderPointer({
    startsAt,
    recurrenceRule: 'FREQ=YEARLY',
    isRecurring: true,
    offsets: [1440, 120],
    baseline: new Date(Date.UTC(2026, 11, 15, 0, 0, 0)),
  });

  assert.equal(
    pointer?.occurrenceStartsAt.toISOString(),
    '2027-01-10T09:00:00.000Z',
  );
  assert.equal(pointer?.offsetMinutes, 1440);
  assert.equal(pointer?.reminderAt.toISOString(), '2027-01-09T09:00:00.000Z');
});
