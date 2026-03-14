import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';

export function requireAuth(request: CallableRequest<unknown>) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  return request.auth;
}
