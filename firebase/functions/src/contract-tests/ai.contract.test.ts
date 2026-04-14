import assert from "node:assert/strict";
import test from "node:test";

import {
  readAppAssistantInput,
  readEventDraftInput,
  readProfileDraftInput,
  runAiTaskWithFallback,
} from "../ai/callables";
import {
  computeAiFeatureThrottleRemainingMs,
  computeAiQuotaRemainingCredits,
  computeAiUsageWindowKey,
  resolveAiFeatureUsageCost,
  resolveAiMonthlyUsageLimit,
} from "../ai/usage";

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

test("ai contract: monthly quota scales from free to pro", () => {
  assert.equal(resolveAiMonthlyUsageLimit("FREE"), 30);
  assert.equal(resolveAiMonthlyUsageLimit("BASE"), 120);
  assert.equal(resolveAiMonthlyUsageLimit("PLUS"), 360);
  assert.equal(resolveAiMonthlyUsageLimit("PRO"), 1200);
  assert.equal(resolveAiMonthlyUsageLimit("FREE") < resolveAiMonthlyUsageLimit("BASE"), true);
  assert.equal(resolveAiMonthlyUsageLimit("BASE") < resolveAiMonthlyUsageLimit("PLUS"), true);
  assert.equal(resolveAiMonthlyUsageLimit("PLUS") < resolveAiMonthlyUsageLimit("PRO"), true);
  assert.equal(resolveAiFeatureUsageCost("app_assistant_chat") > resolveAiFeatureUsageCost("profile_review"), true);
});

test("ai contract: monthly quota remaining credits never goes negative", () => {
  assert.equal(
    computeAiQuotaRemainingCredits({
      usedCredits: 4,
      quotaCredits: 20,
    }),
    16,
  );
  assert.equal(
    computeAiQuotaRemainingCredits({
      usedCredits: 28,
      quotaCredits: 20,
    }),
    0,
  );
});

test("ai contract: usage window is grouped by UTC month", () => {
  assert.equal(
    computeAiUsageWindowKey(new Date("2026-04-13T23:10:00.000Z")),
    "2026-04",
  );
  assert.equal(
    computeAiUsageWindowKey(new Date("2026-05-01T00:00:00.000Z")),
    "2026-05",
  );
});

test("ai contract: assistant input keeps only bounded grounded search context", () => {
  const input = readAppAssistantInput({
    clanId: "clan_demo_001",
    currentScreenId: "tree",
    currentScreenTitle: "Family tree",
    activeClanName: "Gia phả họ Nguyễn",
    question: "Nguyễn Minh ở chi nào?",
    history: [
      { role: "user", text: "Tìm Nguyễn Minh" },
      { role: "assistant", text: "Đang kiểm tra..." },
    ],
    searchContext: {
      searchQueryHint: "Nguyễn Minh",
      activeClanName: "Gia phả họ Nguyễn",
      activeClanMemberCount: 182,
      activeClanBranchCount: 6,
      availableClanCount: 3,
      availableClanNames: ["Gia phả họ Nguyễn", "Clan B", "", 123],
      memberMatches: [
        {
          memberId: "member_demo_parent_001",
          displayName: "Nguyễn Minh",
          fullName: "Nguyễn Minh",
          relationshipCode: "cousin",
          nickName: "Minh",
          branchName: "Chi Trưởng",
          generation: 8,
          birthDate: "1978-04-15",
          deathDate: "",
          jobTitle: "Clan admin",
          hasPhone: true,
          hasAddress: false,
          parentCount: 2,
          childCount: 3,
          spouseCount: 1,
          phoneE164: "+8490",
        },
      ],
    },
  });

  assert.equal(input.searchContext.searchQueryHint, "Nguyễn Minh");
  assert.equal(input.searchContext.availableClanCount, 3);
  assert.deepEqual(input.searchContext.availableClanNames, [
    "Gia phả họ Nguyễn",
    "Clan B",
  ]);
  assert.deepEqual(input.searchContext.memberMatches[0], {
    memberId: "member_demo_parent_001",
    displayName: "Nguyễn Minh",
    fullName: "Nguyễn Minh",
    relationshipCode: "cousin",
    nickName: "Minh",
    branchName: "Chi Trưởng",
    generation: 8,
    birthDate: "1978-04-15",
    deathDate: "",
    jobTitle: "Clan admin",
    hasPhone: true,
    hasAddress: false,
    parentCount: 2,
    childCount: 3,
    spouseCount: 1,
  });
  assert.equal("phoneE164" in input.searchContext.memberMatches[0], false);
});
