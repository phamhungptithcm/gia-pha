import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';

import {
  canAccessPremiumFeatures,
  resolveEffectivePlanCode,
  resolvePlanByMemberCount,
  shouldShowAds,
} from '../billing/pricing';
import { normalizeSubscriptionStatus } from '../billing/subscription-lifecycle';

const CONTRACT_IAP_PRODUCT_IDS_BASE = 'base_yearly,base_annual';
const CONTRACT_IAP_PRODUCT_IDS_PLUS = 'plus_yearly,plus_annual';
const CONTRACT_IAP_PRODUCT_IDS_PRO = 'pro_yearly,pro_annual';
const CONTRACT_IAP_IOS_BASE = 'ios_base_yearly,ios_base_annual';
const CONTRACT_IAP_IOS_PLUS = 'ios_plus_yearly,ios_plus_annual';
const CONTRACT_IAP_IOS_PRO = 'ios_pro_yearly,ios_pro_annual';
const CONTRACT_IAP_ANDROID_BASE = 'android_base_yearly,android_base_annual';
const CONTRACT_IAP_ANDROID_PLUS = 'android_plus_yearly,android_plus_annual';
const CONTRACT_IAP_ANDROID_PRO = 'android_pro_yearly,android_pro_annual';

process.env.BILLING_IAP_PRODUCT_IDS_BASE = CONTRACT_IAP_PRODUCT_IDS_BASE;
process.env.BILLING_IAP_PRODUCT_IDS_PLUS = CONTRACT_IAP_PRODUCT_IDS_PLUS;
process.env.BILLING_IAP_PRODUCT_IDS_PRO = CONTRACT_IAP_PRODUCT_IDS_PRO;
process.env.BILLING_IAP_IOS_PRODUCT_IDS_BASE = CONTRACT_IAP_IOS_BASE;
process.env.BILLING_IAP_IOS_PRODUCT_IDS_PLUS = CONTRACT_IAP_IOS_PLUS;
process.env.BILLING_IAP_IOS_PRODUCT_IDS_PRO = CONTRACT_IAP_IOS_PRO;
process.env.BILLING_IAP_ANDROID_PRODUCT_IDS_BASE = CONTRACT_IAP_ANDROID_BASE;
process.env.BILLING_IAP_ANDROID_PRODUCT_IDS_PLUS = CONTRACT_IAP_ANDROID_PLUS;
process.env.BILLING_IAP_ANDROID_PRODUCT_IDS_PRO = CONTRACT_IAP_ANDROID_PRO;

test('billing contract: member-count pricing tiers are non-overlapping (+1 boundaries)', () => {
  assert.equal(resolvePlanByMemberCount(10).planCode, 'FREE');
  assert.equal(resolvePlanByMemberCount(11).planCode, 'BASE');
  assert.equal(resolvePlanByMemberCount(200).planCode, 'BASE');
  assert.equal(resolvePlanByMemberCount(201).planCode, 'PLUS');
  assert.equal(resolvePlanByMemberCount(700).planCode, 'PLUS');
  assert.equal(resolvePlanByMemberCount(701).planCode, 'PRO');
});

test('billing contract: auto + upgrade keeps higher plan and blocks lower-than-min requests', () => {
  assert.equal(
    resolveEffectivePlanCode({
      memberCount: 60,
      currentPlanCode: 'PRO',
    }),
    'PRO',
  );

  assert.equal(
    resolveEffectivePlanCode({
      memberCount: 60,
      currentPlanCode: 'BASE',
      requestedPlanCode: 'PLUS',
    }),
    'PLUS',
  );

  assert.equal(
    resolveEffectivePlanCode({
      memberCount: 120,
      currentPlanCode: 'PRO',
      requestedPlanCode: 'BASE',
    }),
    'BASE',
  );

  assert.throws(() =>
    resolveEffectivePlanCode({
      memberCount: 60,
      currentPlanCode: 'BASE',
      requestedPlanCode: 'FREE',
    }),
  );
});

test('billing contract: ad entitlement and premium access follow plan + status', () => {
  assert.equal(shouldShowAds('FREE', 'active'), true);
  assert.equal(shouldShowAds('BASE', 'active'), true);
  assert.equal(shouldShowAds('PLUS', 'active'), false);
  assert.equal(shouldShowAds('PRO', 'active'), false);

  assert.equal(canAccessPremiumFeatures('PLUS', 'active'), true);
  assert.equal(canAccessPremiumFeatures('PRO', 'grace_period'), true);
  assert.equal(canAccessPremiumFeatures('PRO', 'expired'), false);
  assert.equal(canAccessPremiumFeatures('BASE', 'active'), true);
});

test('billing contract: lifecycle status normalizes by expiry and grace period', () => {
  const now = new Date(Date.UTC(2026, 2, 15, 10, 0, 0));
  assert.equal(
    normalizeSubscriptionStatus({
      status: 'active',
      expiresAt: new Date(Date.UTC(2026, 2, 20, 0, 0, 0)),
      graceEndsAt: null,
      now,
    }),
    'active',
  );

  assert.equal(
    normalizeSubscriptionStatus({
      status: 'active',
      expiresAt: new Date(Date.UTC(2026, 2, 14, 0, 0, 0)),
      graceEndsAt: new Date(Date.UTC(2026, 2, 16, 0, 0, 0)),
      now,
    }),
    'grace_period',
  );

  assert.equal(
    normalizeSubscriptionStatus({
      status: 'active',
      expiresAt: new Date(Date.UTC(2026, 2, 10, 0, 0, 0)),
      graceEndsAt: new Date(Date.UTC(2026, 2, 12, 0, 0, 0)),
      now,
    }),
    'expired',
  );
});

test('billing contract: VNPay callback signature is validated', async () => {
  process.env.VNPAY_HASH_SECRET = 'contract-test-secret';
  process.env.VNPAY_TMNCODE = 'DEMO1234';
  const { isValidVnpaySignature } = await import('../billing/webhooks');

  const params: Record<string, string> = {
    vnp_Amount: '4900000',
    vnp_Command: 'pay',
    vnp_CreateDate: '20260315120000',
    vnp_CurrCode: 'VND',
    vnp_Locale: 'vn',
    vnp_OrderInfo: 'BeFam BASE annual subscription',
    vnp_OrderType: 'billpayment',
    vnp_ResponseCode: '00',
    vnp_TmnCode: 'DEMO1234',
    vnp_TransactionNo: '15190022',
    vnp_TxnRef: 'txn_contract_001',
    vnp_Version: '2.1.0',
  };

  const canonical = Object.entries(params)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
    .join('&');

  params.vnp_SecureHash = createHmac('sha512', process.env.VNPAY_HASH_SECRET)
    .update(canonical)
    .digest('hex');

  assert.equal(isValidVnpaySignature(params), true);

  params.vnp_TmnCode = 'WRONG_TMNCODE';
  assert.equal(isValidVnpaySignature(params), false);

  params.vnp_TmnCode = 'DEMO1234';
  params.vnp_SecureHash = `${params.vnp_SecureHash.substring(0, 30)}broken`;
  assert.equal(isValidVnpaySignature(params), false);
});

test(
  'billing contract: IAP product mapping remains stable for store verification',
  async () => {
    process.env.BILLING_IAP_PRODUCT_IDS_BASE = CONTRACT_IAP_PRODUCT_IDS_BASE;
    process.env.BILLING_IAP_PRODUCT_IDS_PLUS = CONTRACT_IAP_PRODUCT_IDS_PLUS;
    process.env.BILLING_IAP_PRODUCT_IDS_PRO = CONTRACT_IAP_PRODUCT_IDS_PRO;
    process.env.BILLING_IAP_IOS_PRODUCT_IDS_BASE = CONTRACT_IAP_IOS_BASE;
    process.env.BILLING_IAP_IOS_PRODUCT_IDS_PLUS = CONTRACT_IAP_IOS_PLUS;
    process.env.BILLING_IAP_IOS_PRODUCT_IDS_PRO = CONTRACT_IAP_IOS_PRO;
    process.env.BILLING_IAP_ANDROID_PRODUCT_IDS_BASE = CONTRACT_IAP_ANDROID_BASE;
    process.env.BILLING_IAP_ANDROID_PRODUCT_IDS_PLUS = CONTRACT_IAP_ANDROID_PLUS;
    process.env.BILLING_IAP_ANDROID_PRODUCT_IDS_PRO = CONTRACT_IAP_ANDROID_PRO;
    const {
      normalizeIapPlatform,
      resolvePlanCodeForIapProductId,
      resolveStoreProductIdForPlanCode,
    } = await import('../billing/iap-verification');

    assert.equal(resolvePlanCodeForIapProductId('ios_base_yearly', 'ios'), 'BASE');
    assert.equal(resolvePlanCodeForIapProductId('ios_plus_yearly', 'ios'), 'PLUS');
    assert.equal(resolvePlanCodeForIapProductId('ios_pro_yearly', 'ios'), 'PRO');
    assert.equal(
      resolvePlanCodeForIapProductId('android_base_yearly', 'android'),
      'BASE',
    );
    assert.equal(
      resolvePlanCodeForIapProductId('android_plus_yearly', 'android'),
      'PLUS',
    );
    assert.equal(
      resolvePlanCodeForIapProductId('android_pro_yearly', 'android'),
      'PRO',
    );
    assert.equal(resolvePlanCodeForIapProductId('unknown_plan'), null);

    assert.equal(resolveStoreProductIdForPlanCode('BASE', 'ios'), 'ios_base_yearly');
    assert.equal(resolveStoreProductIdForPlanCode('PLUS', 'ios'), 'ios_plus_yearly');
    assert.equal(resolveStoreProductIdForPlanCode('PRO', 'ios'), 'ios_pro_yearly');
    assert.equal(
      resolveStoreProductIdForPlanCode('BASE', 'android'),
      'android_base_yearly',
    );
    assert.equal(
      resolveStoreProductIdForPlanCode('PLUS', 'android'),
      'android_plus_yearly',
    );
    assert.equal(
      resolveStoreProductIdForPlanCode('PRO', 'android'),
      'android_pro_yearly',
    );
    assert.equal(resolveStoreProductIdForPlanCode('FREE'), null);

    assert.equal(normalizeIapPlatform('ios'), 'ios');
    assert.equal(normalizeIapPlatform('apple'), 'ios');
    assert.equal(normalizeIapPlatform('android'), 'android');
    assert.equal(normalizeIapPlatform('google_play'), 'android');
    assert.throws(() => normalizeIapPlatform('web'));
  },
);
