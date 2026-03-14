import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { APP_REGION } from '../config/runtime';
import { requireAuth } from '../shared/errors';
import { logInfo } from '../shared/logger';

export const createInvite = onCall({ region: APP_REGION }, async (request) => {
  const auth = requireAuth(request);

  logInfo('createInvite requested', {
    uid: auth.uid,
    data: request.data,
  });

  throw new HttpsError(
    'unimplemented',
    'createInvite is scaffolded and awaits permission checks plus invite persistence logic.',
  );
});

export const claimMemberRecord = onCall({ region: APP_REGION }, async (request) => {
  const auth = requireAuth(request);

  logInfo('claimMemberRecord requested', {
    uid: auth.uid,
    data: request.data,
  });

  throw new HttpsError(
    'unimplemented',
    'claimMemberRecord is scaffolded and awaits invite validation plus member linking logic.',
  );
});

export const registerDeviceToken = onCall({ region: APP_REGION }, async (request) => {
  const auth = requireAuth(request);

  logInfo('registerDeviceToken requested', {
    uid: auth.uid,
    data: request.data,
  });

  throw new HttpsError(
    'unimplemented',
    'registerDeviceToken is scaffolded and awaits token upsert logic.',
  );
});
