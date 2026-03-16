import { createHmac } from 'node:crypto';

type VnpayHashMode = 'encoded' | 'raw';

const HASH_EXCLUDED_KEYS = new Set(['vnp_securehash', 'vnp_securehashtype']);
const GMT_PLUS_7_OFFSET_MILLIS = 7 * 60 * 60 * 1000;

export function buildVnpayQueryString(params: Record<string, string>): string {
  return buildVnpayHashData(params, { mode: 'encoded' });
}

export function buildVnpayHashData(
  params: Record<string, string>,
  options?: {
    mode?: VnpayHashMode;
  },
): string {
  const mode = options?.mode ?? 'encoded';
  return canonicalEntries(params)
    .map(([key, value]) => {
      if (mode === 'raw') {
        return `${key}=${value}`;
      }
      return `${encodeVnpayComponent(key)}=${encodeVnpayComponent(value)}`;
    })
    .join('&');
}

export function createVnpaySignature(
  params: Record<string, string>,
  hashSecret: string,
  mode: VnpayHashMode = 'encoded',
): string {
  const hashData = buildVnpayHashData(params, { mode });
  return createHmac('sha512', hashSecret).update(hashData).digest('hex');
}

export function validateVnpaySignature(
  params: Record<string, string>,
  hashSecret: string,
): boolean {
  const secureHash = normalizeHash(params.vnp_SecureHash);
  if (secureHash.length === 0 || hashSecret.trim().length === 0) {
    return false;
  }

  const encodedExpected = normalizeHash(createVnpaySignature(params, hashSecret, 'encoded'));
  if (safeEqual(encodedExpected, secureHash)) {
    return true;
  }

  // Keep backward compatibility with older integrations that hash raw values.
  const rawExpected = normalizeHash(createVnpaySignature(params, hashSecret, 'raw'));
  return safeEqual(rawExpected, secureHash);
}

export function formatVnpayTimestampGmt7(value: Date): string {
  const shifted = new Date(value.getTime() + GMT_PLUS_7_OFFSET_MILLIS);
  const year = shifted.getUTCFullYear();
  const month = `${shifted.getUTCMonth() + 1}`.padStart(2, '0');
  const day = `${shifted.getUTCDate()}`.padStart(2, '0');
  const hour = `${shifted.getUTCHours()}`.padStart(2, '0');
  const minute = `${shifted.getUTCMinutes()}`.padStart(2, '0');
  const second = `${shifted.getUTCSeconds()}`.padStart(2, '0');
  return `${year}${month}${day}${hour}${minute}${second}`;
}

export function normalizeVnpayLocale(rawValue: string | null | undefined): 'vn' | 'en' {
  return rawValue?.trim().toLowerCase() === 'en' ? 'en' : 'vn';
}

export function normalizeVnpayOrderInfo(rawValue: string): string {
  const normalized = rawValue
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^A-Za-z0-9 .,:_/-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (normalized.length === 0) {
    return 'BeFam subscription payment';
  }
  return normalized.slice(0, 255);
}

export function normalizeVnpayIpAddress(rawValue: string | null | undefined): string {
  let value = (rawValue ?? '').trim();
  if (value.length === 0) {
    return '127.0.0.1';
  }

  if (value.includes(',')) {
    value = value.split(',')[0]?.trim() ?? '';
  }
  if (value.startsWith('::ffff:')) {
    value = value.slice(7);
  }
  if (value === '::1') {
    return '127.0.0.1';
  }

  const ipv4WithPortMatch = value.match(/^(\d{1,3}(?:\.\d{1,3}){3}):\d{1,5}$/);
  if (ipv4WithPortMatch != null) {
    value = ipv4WithPortMatch[1];
  }

  if (value.length === 0) {
    return '127.0.0.1';
  }
  return value;
}

function canonicalEntries(params: Record<string, string>): Array<[string, string]> {
  return Object.entries(params)
    .filter(([key]) => !HASH_EXCLUDED_KEYS.has(key.trim().toLowerCase()))
    .map(([key, value]) => [key.trim(), value.trim()] as [string, string])
    .filter(([key]) => key.length > 0)
    .sort(([left], [right]) => left.localeCompare(right));
}

function encodeVnpayComponent(value: string): string {
  return encodeURIComponent(value).replace(/%20/g, '+');
}

function normalizeHash(value: string | null | undefined): string {
  return (value ?? '').trim().toLowerCase();
}

function safeEqual(left: string, right: string): boolean {
  if (left.length === 0 || right.length === 0 || left.length !== right.length) {
    return false;
  }

  let mismatch = 0;
  for (let index = 0; index < left.length; index += 1) {
    mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return mismatch === 0;
}
