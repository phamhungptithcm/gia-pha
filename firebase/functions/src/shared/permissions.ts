import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';

export const GOVERNANCE_ROLES = {
  superAdmin: 'SUPER_ADMIN',
  clanAdmin: 'CLAN_ADMIN',
  branchAdmin: 'BRANCH_ADMIN',
  treasurer: 'TREASURER',
  scholarshipCouncilHead: 'SCHOLARSHIP_COUNCIL_HEAD',
  adminSupport: 'ADMIN_SUPPORT',
  member: 'MEMBER',
} as const;

export type GovernanceRole = (typeof GOVERNANCE_ROLES)[keyof typeof GOVERNANCE_ROLES];
export type AuthToken = NonNullable<CallableRequest<unknown>['auth']>['token'];

export function stringOrNull(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function normalizeRole(value: unknown): string {
  return stringOrNull(value)?.toUpperCase() ?? '';
}

export function tokenMemberId(token: AuthToken): string | null {
  return stringOrNull(token.memberId);
}

export function tokenClanIds(token: AuthToken): Array<string> {
  const raw = Array.isArray(token.clanIds) ? token.clanIds : [];
  return raw
    .filter((entry): entry is string => typeof entry === 'string')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

export function tokenPrimaryRole(token: AuthToken): string {
  return normalizeRole(token.primaryRole);
}

export function tokenMemberAccessMode(token: AuthToken): string {
  return stringOrNull(token.memberAccessMode)?.toLowerCase() ?? 'unlinked';
}

export function hasRole(token: AuthToken, roles: Array<string>): boolean {
  const role = tokenPrimaryRole(token);
  return roles.includes(role);
}

export function ensureClaimedSession(token: AuthToken): void {
  if (tokenMemberAccessMode(token) !== 'claimed') {
    throw new HttpsError(
      'permission-denied',
      'This session must be linked and claimed before performing this action.',
    );
  }
}

export function ensureClanAccess(token: AuthToken, clanId: string): void {
  if (!tokenClanIds(token).includes(clanId)) {
    throw new HttpsError(
      'permission-denied',
      'This session does not have access to the requested clan.',
    );
  }
}

export function ensureAnyRole(token: AuthToken, roles: Array<string>, message: string): void {
  if (!hasRole(token, roles)) {
    throw new HttpsError('permission-denied', message);
  }
}
