import assert from "node:assert/strict";
import test from "node:test";

import {
  computeAiFeatureThrottleRemainingMs,
  readEventDraftInput,
  readProfileDraftInput,
  runAiTaskWithFallback,
} from "../ai/callables";

test("ai contract: timeout falls back without breaking the response shape", async () => {
  const result = await runAiTaskWithFallback({
    timeoutMs: 20,
    fallback: { summary: "fallback" },
    task: async () => {
      await new Promise((resolve) => setTimeout(resolve, 60));
      return { summary: "live" };
    },
  });

  assert.equal(result.usedFallback, true);
  assert.equal(result.fallbackReason, "timeout");
  assert.equal(result.output.summary, "fallback");
  assert.equal(result.elapsedMs >= 20, true);
});

test("ai contract: profile payload keeps only minimized signals", () => {
  const draft = readProfileDraftInput({
    fullName: "Nguyen Minh",
    nickName: "Minh",
    jobTitle: "Clan admin",
    hasPhone: true,
    hasEmail: false,
    hasAddress: true,
    bioWordCount: 14,
    socialLinkCount: 2,
    phoneInput: "+84901234567",
    email: "minh@example.com",
    addressText: "Da Nang, Viet Nam",
    bio: "Raw bio should never be consumed here",
    facebook: "fb.com/minh",
  });

  assert.deepEqual(draft, {
    fullName: "Nguyen Minh",
    nickName: "Minh",
    jobTitle: "Clan admin",
    hasPhone: true,
    hasEmail: false,
    hasAddress: true,
    bioWordCount: 14,
    socialLinkCount: 2,
  });
  assert.equal("phoneInput" in draft, false);
  assert.equal("email" in draft, false);
  assert.equal("addressText" in draft, false);
  assert.equal("bio" in draft, false);
});

test("ai contract: event payload no longer requires raw address or target name", () => {
  const draft = readEventDraftInput({
    clanId: "clan_demo_001",
    eventType: "death_anniversary",
    title: "Giỗ cụ tổ",
    description: "Nhắc cả nhà đến đúng giờ.",
    locationName: "Từ đường chi trưởng",
    hasLocationAddress: true,
    startsAtIso: "2026-04-12T12:00:00.000Z",
    timezone: "Asia/Ho_Chi_Minh",
    isRecurring: true,
    targetMemberName: "Should be ignored",
    locationAddress: "Should also be ignored",
  });

  assert.deepEqual(draft, {
    clanId: "clan_demo_001",
    eventType: "death_anniversary",
    title: "Giỗ cụ tổ",
    description: "Nhắc cả nhà đến đúng giờ.",
    locationName: "Từ đường chi trưởng",
    hasLocationAddress: true,
    startsAtIso: "2026-04-12T12:00:00.000Z",
    timezone: "Asia/Ho_Chi_Minh",
    isRecurring: true,
  });
  assert.equal("targetMemberName" in draft, false);
  assert.equal("locationAddress" in draft, false);
});

test("ai contract: throttle window reports remaining cooldown correctly", () => {
  assert.equal(
    computeAiFeatureThrottleRemainingMs({
      lastRequestedAtMs: 1_000,
      nowMs: 12_500,
      cooldownMs: 10_000,
    }),
    0,
  );
  assert.equal(
    computeAiFeatureThrottleRemainingMs({
      lastRequestedAtMs: 8_000,
      nowMs: 12_500,
      cooldownMs: 10_000,
    }),
    5_500,
  );
});
