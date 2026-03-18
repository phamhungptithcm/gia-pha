import * as logger from 'firebase-functions/logger';

export function logInfo(message: string, context: Record<string, unknown> = {}) {
  logger.info(message, sanitizeContext(context));
}

export function logWarn(message: string, context: Record<string, unknown> = {}) {
  logger.warn(message, sanitizeContext(context));
}

export function logError(message: string, context: Record<string, unknown> = {}) {
  logger.error(message, sanitizeContext(context));
}

function sanitizeContext(context: Record<string, unknown>): Record<string, unknown> {
  const sanitized = sanitizeValue(context, '');
  if (sanitized != null && typeof sanitized === 'object' && !Array.isArray(sanitized)) {
    return sanitized as Record<string, unknown>;
  }
  return {};
}

function sanitizeValue(value: unknown, key: string): unknown {
  if (isSensitiveKey(key)) {
    return redactSensitiveValue(value, key);
  }

  if (Array.isArray(value)) {
    return value.map((entry) => sanitizeValue(entry, key));
  }

  if (value != null && typeof value === 'object') {
    const input = value as Record<string, unknown>;
    const output: Record<string, unknown> = {};
    for (const [entryKey, entryValue] of Object.entries(input)) {
      output[entryKey] = sanitizeValue(entryValue, entryKey);
    }
    return output;
  }

  return value;
}

function isSensitiveKey(key: string): boolean {
  const normalized = key.trim().toLowerCase();
  if (normalized.length === 0) {
    return false;
  }

  if (normalized.includes('phone')) {
    return true;
  }

  const tokenLike = normalized === 'token' ||
    normalized.endsWith('_token') ||
    (normalized.endsWith('token') && !normalized.endsWith('token_count') && !normalized.endsWith('token_length'));
  if (tokenLike) {
    return true;
  }

  return normalized.includes('password') ||
    normalized.includes('secret') ||
    normalized.includes('authorization') ||
    normalized.includes('cookie') ||
    normalized.includes('otp');
}

function redactSensitiveValue(value: unknown, key: string): unknown {
  if (value == null) {
    return null;
  }
  if (typeof value !== 'string') {
    return '[REDACTED]';
  }

  const normalizedKey = key.trim().toLowerCase();
  if (normalizedKey.includes('phone')) {
    return maskPhone(value);
  }
  if (normalizedKey.includes('token') || normalizedKey.includes('secret')) {
    return maskToken(value);
  }
  return '[REDACTED]';
}

function maskPhone(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.length === 0) {
    return '';
  }
  if (trimmed.length <= 4) {
    return '****';
  }
  return `${trimmed.slice(0, 3)}****${trimmed.slice(-2)}`;
}

function maskToken(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.length === 0) {
    return '';
  }
  if (trimmed.length <= 8) {
    return '********';
  }
  return `${trimmed.slice(0, 4)}...${trimmed.slice(-4)}`;
}
