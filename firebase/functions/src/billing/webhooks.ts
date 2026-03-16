import { createHash, createHmac } from 'node:crypto';

import { onRequest } from 'firebase-functions/v2/https';

import {
  APP_REGION,
  getBillingWebhookSecret,
  getCardWebhookSecret,
  getVnpayHashSecret,
  getVnpayTmnCode,
} from '../config/runtime';
import {
  applyPaymentResult,
  recordPaymentWebhookEvent,
  resolveBillingAudienceMemberIds,
} from './store';
import { notifyMembers } from '../notifications/push-delivery';
import { logError, logInfo, logWarn } from '../shared/logger';

export const vnpayPaymentCallback = onRequest(
  { region: APP_REGION },
  async (request, response) => {
    if (request.method !== 'GET') {
      response.status(405).json({ ok: false, message: 'Method not allowed' });
      return;
    }

    const params = normalizeQueryParams(request.query);
    const transactionId = params.vnp_TxnRef ?? '';
    if (transactionId.length === 0) {
      response.status(400).json({ ok: false, message: 'vnp_TxnRef is required' });
      return;
    }

    const payloadHash = sha256(JSON.stringify(params));
    const signatureValid = isValidVnpaySignature(params);
    const externalEventId =
      params.vnp_TransactionNo ?? params.vnp_TxnRef ?? `${Date.now()}`;

    if (!signatureValid) {
      logWarn('vnpay callback rejected due to invalid signature', {
        transactionId,
        externalEventId,
      });
      response.status(401).json({
        ok: false,
        message: 'Invalid VNPay signature',
      });
      return;
    }

    const webhookEvent = await recordPaymentWebhookEvent({
      provider: 'vnpay',
      externalEventId,
      transactionId,
      payloadHash,
      validSignature: true,
      rawPayload: params,
    });
    if (webhookEvent.alreadyProcessed) {
      response.status(200).json({
        ok: true,
        idempotent: true,
        transactionId,
      });
      return;
    }

    const responseCode = params.vnp_ResponseCode ?? '';
    const paymentStatus =
      responseCode === '00' ? 'succeeded' : responseCode === '24' ? 'canceled' : 'failed';

    try {
      const result = await applyPaymentResult({
        transactionId,
        provider: 'vnpay',
        gatewayReference: params.vnp_TransactionNo ?? transactionId,
        paymentStatus,
        payloadHash,
        actorUid: 'system:vnpay_webhook',
      });
      await notifyBillingWebhookResult({
        clanId: result.clanId,
        transactionId,
        amountVnd: Number(result.transaction.amountVnd),
        provider: 'vnpay',
        approved: paymentStatus === 'succeeded',
      });

      logInfo('vnpay callback processed', {
        transactionId,
        paymentStatus,
        responseCode,
      });
      response.status(200).json({
        ok: true,
        transactionId,
        paymentStatus,
      });
    } catch (error) {
      logError('vnpay callback processing failed', {
        transactionId,
        error: `${error}`,
      });
      response.status(500).json({
        ok: false,
        message: 'Could not process VNPay callback',
      });
    }
  },
);

export const cardPaymentCallback = onRequest(
  { region: APP_REGION },
  async (request, response) => {
    if (!['GET', 'POST'].includes(request.method)) {
      response.status(405).json({ ok: false, message: 'Method not allowed' });
      return;
    }

    const payload = mergeCardPayload(request.query, request.body);
    const transactionId = payload.transactionId;
    if (transactionId.length === 0) {
      response.status(400).json({ ok: false, message: 'transactionId is required' });
      return;
    }
    const externalEventId = payload.gatewayReference.length > 0
      ? payload.gatewayReference
      : `card-${transactionId}-${Date.now()}`;
    const payloadHash = sha256(JSON.stringify(payload));
    const signatureValid = isValidCardSignature(payload);

    if (!signatureValid) {
      response.status(401).json({ ok: false, message: 'Invalid card callback signature' });
      return;
    }

    const webhookEvent = await recordPaymentWebhookEvent({
      provider: 'card',
      externalEventId,
      transactionId,
      payloadHash,
      validSignature: true,
      rawPayload: payload,
    });
    if (webhookEvent.alreadyProcessed) {
      response.status(200).json({
        ok: true,
        idempotent: true,
        transactionId,
      });
      return;
    }

    const paymentStatus = normalizeCardStatus(payload.status);

    try {
      const result = await applyPaymentResult({
        transactionId,
        provider: 'card',
        gatewayReference: payload.gatewayReference,
        paymentStatus,
        payloadHash,
        actorUid: 'system:card_webhook',
      });
      await notifyBillingWebhookResult({
        clanId: result.clanId,
        transactionId,
        amountVnd: Number(result.transaction.amountVnd),
        provider: 'card',
        approved: paymentStatus === 'succeeded',
      });
      response.status(200).json({
        ok: true,
        transactionId,
        paymentStatus,
      });
    } catch (error) {
      response.status(500).json({
        ok: false,
        message: 'Could not process card callback',
        error: `${error}`,
      });
    }
  },
);

type CardPayload = {
  transactionId: string;
  status: string;
  gatewayReference: string;
  signature: string;
};

function mergeCardPayload(query: unknown, body: unknown): CardPayload {
  const merged = {
    ...(query != null && typeof query === 'object'
      ? (query as Record<string, unknown>)
      : {}),
    ...(body != null && typeof body === 'object'
      ? (body as Record<string, unknown>)
      : {}),
  };

  return {
    transactionId: normalizeString(merged.transactionId ?? merged.tx),
    status: normalizeString(merged.status),
    gatewayReference: normalizeString(merged.gatewayReference ?? merged.gatewayRef),
    signature: normalizeString(merged.signature),
  };
}

function normalizeCardStatus(status: string): 'succeeded' | 'failed' | 'canceled' {
  const normalized = status.trim().toLowerCase();
  if (normalized === 'success' || normalized === 'succeeded' || normalized === 'paid') {
    return 'succeeded';
  }
  if (normalized === 'canceled' || normalized === 'cancelled') {
    return 'canceled';
  }
  return 'failed';
}

function isValidCardSignature(payload: CardPayload): boolean {
  const secret = getCardWebhookSecret() || getBillingWebhookSecret();
  if (secret == null || secret.trim().length === 0) {
    return false;
  }
  const canonical = `${payload.transactionId}|${payload.status}|${payload.gatewayReference}`;
  const expected = createHmac('sha256', secret).update(canonical).digest('hex');
  return safeEqual(expected, payload.signature);
}

function normalizeQueryParams(query: unknown): Record<string, string> {
  if (query == null || typeof query !== 'object') {
    return {};
  }
  const output: Record<string, string> = {};
  for (const [key, value] of Object.entries(query as Record<string, unknown>)) {
    if (typeof value === 'string') {
      output[key] = value.trim();
      continue;
    }
    if (Array.isArray(value) && value.length > 0 && typeof value[0] === 'string') {
      output[key] = value[0].trim();
    }
  }
  return output;
}

export function isValidVnpaySignature(params: Record<string, string>): boolean {
  const secureHash = params.vnp_SecureHash;
  const hashSecret = getVnpayHashSecret();
  const expectedTmnCode = normalizeString(getVnpayTmnCode());
  const callbackTmnCode = normalizeString(params.vnp_TmnCode);
  if (secureHash == null || secureHash.length === 0 || hashSecret.length === 0) {
    return false;
  }
  if (expectedTmnCode.length > 0 && callbackTmnCode !== expectedTmnCode) {
    return false;
  }

  const canonical = Object.entries(params)
    .filter(([key]) => key !== 'vnp_SecureHash' && key !== 'vnp_SecureHashType')
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
    .join('&');
  const expected = createHmac('sha512', hashSecret).update(canonical).digest('hex');
  return safeEqual(expected, secureHash);
}

async function notifyBillingWebhookResult({
  clanId,
  approved,
  amountVnd,
  transactionId,
  provider,
}: {
  clanId: string;
  approved: boolean;
  amountVnd: number;
  transactionId: string;
  provider: string;
}): Promise<void> {
  const memberIds = await resolveBillingAudienceMemberIds(clanId);
  if (memberIds.length === 0) {
    return;
  }

  await notifyMembers({
    clanId,
    memberIds,
    type: approved ? 'billing_payment_succeeded' : 'billing_payment_failed',
    title: approved ? 'Subscription payment confirmed' : 'Subscription payment failed',
    body: approved
      ? `${formatVnd(amountVnd)} via ${provider.toUpperCase()} has been confirmed.`
      : `${formatVnd(amountVnd)} via ${provider.toUpperCase()} did not complete.`,
    target: 'generic',
    targetId: transactionId,
    extraData: {
      transactionId,
      billing: 'true',
      result: approved ? 'success' : 'failed',
      provider,
    },
  });
}

function safeEqual(left: string, right: string): boolean {
  const a = left.trim().toLowerCase();
  const b = right.trim().toLowerCase();
  if (a.length === 0 || b.length === 0 || a.length !== b.length) {
    return false;
  }

  let mismatch = 0;
  for (let index = 0; index < a.length; index += 1) {
    mismatch |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return mismatch === 0;
}

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function formatVnd(amount: number): string {
  return `${Math.max(0, Math.trunc(amount)).toLocaleString('vi-VN')} VND`;
}
