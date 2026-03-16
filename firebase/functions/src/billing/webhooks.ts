import { createHash, createHmac } from 'node:crypto';

import type { Response } from 'express';
import { onRequest } from 'firebase-functions/v2/https';

import { APP_REGION } from '../config/runtime';
import {
  applyPaymentResult,
  recordPaymentWebhookEvent,
  resolveBillingAudienceMemberIds,
} from './store';
import { notifyMembers } from '../notifications/push-delivery';
import { db } from '../shared/firestore';
import { logError, logInfo, logWarn } from '../shared/logger';
import { validateVnpaySignature } from './vnpay';

const transactionsCollection = db.collection('paymentTransactions');

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
      respondVnpay(response, {
        rspCode: '01',
        message: 'Order not found',
      });
      return;
    }

    const payloadHash = sha256(JSON.stringify(params));
    const signatureValid = isValidVnpaySignature(params);
    const externalEventId =
      params.vnp_TransactionNo ?? params.vnp_TxnRef ?? `${Date.now()}`;

    const webhookEvent = await recordPaymentWebhookEvent({
      provider: 'vnpay',
      externalEventId,
      transactionId,
      payloadHash,
      validSignature: signatureValid,
      rawPayload: sanitizeVnpayPayload(params),
    });
    if (webhookEvent.alreadyProcessed) {
      respondVnpay(response, {
        rspCode: '02',
        message: 'Order already confirmed',
        idempotent: true,
        transactionId,
      });
      return;
    }

    if (!signatureValid) {
      logWarn('vnpay callback rejected due to invalid signature', {
        transactionId,
        externalEventId,
      });
      respondVnpay(response, {
        rspCode: '97',
        message: 'Invalid Checksum',
      });
      return;
    }

    const transactionSnapshot = await transactionsCollection.doc(transactionId).get();
    if (!transactionSnapshot.exists) {
      respondVnpay(response, {
        rspCode: '01',
        message: 'Order not found',
      });
      return;
    }
    const transactionData = transactionSnapshot.data() ?? {};
    const currentPaymentStatus = normalizeString(transactionData.paymentStatus);
    if (currentPaymentStatus === 'succeeded') {
      respondVnpay(response, {
        rspCode: '02',
        message: 'Order already confirmed',
      });
      return;
    }

    const callbackAmount = parseInteger(params.vnp_Amount);
    const expectedAmount = Math.max(0, Math.trunc(readNumber(transactionData.amountVnd) * 100));
    if (callbackAmount == null || expectedAmount !== callbackAmount) {
      logWarn('vnpay callback amount mismatch', {
        transactionId,
        callbackAmount,
        expectedAmount,
      });
      respondVnpay(response, {
        rspCode: '04',
        message: 'Invalid amount',
      });
      return;
    }

    const responseCode = params.vnp_ResponseCode ?? '';
    const transactionStatus = params.vnp_TransactionStatus ?? '';
    const paymentStatus = normalizeVnpayPaymentStatus({
      responseCode,
      transactionStatus,
    });

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
        transactionStatus,
      });
      respondVnpay(response, {
        rspCode: '00',
        message: 'Confirm Success',
        transactionId,
        paymentStatus,
      });
    } catch (error) {
      logError('vnpay callback processing failed', {
        transactionId,
        error: `${error}`,
      });
      respondVnpay(response, {
        rspCode: '99',
        message: 'Unknown error',
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

    const webhookEvent = await recordPaymentWebhookEvent({
      provider: 'card',
      externalEventId,
      transactionId,
      payloadHash,
      validSignature: signatureValid,
      rawPayload: sanitizeCardPayload(payload),
    });
    if (webhookEvent.alreadyProcessed) {
      response.status(200).json({
        ok: true,
        idempotent: true,
        transactionId,
      });
      return;
    }

    if (!signatureValid) {
      response.status(401).json({ ok: false, message: 'Invalid card callback signature' });
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

function sanitizeVnpayPayload(params: Record<string, string>): Record<string, unknown> {
  const keepKeys = [
    'vnp_TmnCode',
    'vnp_TxnRef',
    'vnp_TransactionNo',
    'vnp_Amount',
    'vnp_BankCode',
    'vnp_BankTranNo',
    'vnp_CardType',
    'vnp_PayDate',
    'vnp_ResponseCode',
    'vnp_TransactionStatus',
    'vnp_TransactionType',
    'vnp_PayType',
  ];
  const output: Record<string, unknown> = {};
  for (const key of keepKeys) {
    const value = params[key];
    if (value != null && value.trim().length > 0) {
      output[key] = value.trim();
    }
  }
  return output;
}

function sanitizeCardPayload(payload: CardPayload): Record<string, unknown> {
  return {
    transactionId: payload.transactionId,
    status: payload.status,
    gatewayReference: payload.gatewayReference,
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
  const secret = process.env.CARD_WEBHOOK_SECRET ?? process.env.BILLING_WEBHOOK_SECRET;
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
  const hashSecret = process.env.VNPAY_HASH_SECRET?.trim() ?? '';
  if (hashSecret.length === 0) {
    return false;
  }
  return validateVnpaySignature(params, hashSecret);
}

function normalizeVnpayPaymentStatus({
  responseCode,
  transactionStatus,
}: {
  responseCode: string;
  transactionStatus: string;
}): 'succeeded' | 'failed' | 'canceled' {
  if (responseCode === '00' && (transactionStatus.length === 0 || transactionStatus === '00')) {
    return 'succeeded';
  }
  if (responseCode === '24') {
    return 'canceled';
  }
  return 'failed';
}

function respondVnpay(
  response: Response,
  payload: {
    rspCode: string;
    message: string;
    httpStatus?: number;
    [key: string]: unknown;
  },
): void {
  const { rspCode, message, httpStatus = 200, ...extra } = payload;
  response.status(httpStatus).json({
    RspCode: rspCode,
    Message: message,
    ...extra,
  });
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

function parseInteger(value: string | undefined): number | null {
  const parsed = Number.parseInt(value ?? '', 10);
  if (!Number.isFinite(parsed)) {
    return null;
  }
  return parsed;
}

function readNumber(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return 0;
}

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function formatVnd(amount: number): string {
  return `${Math.max(0, Math.trunc(amount)).toLocaleString('vi-VN')} VND`;
}
