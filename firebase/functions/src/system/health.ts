import { onRequest } from 'firebase-functions/v2/https';

import { APP_REGION } from '../config/runtime';

const BOOT_TIME_ISO = new Date().toISOString();

export const appHealthCheck = onRequest(
  { region: APP_REGION },
  async (request, response) => {
    if (!['GET', 'HEAD'].includes(request.method)) {
      response.status(405).json({ ok: false, message: 'Method not allowed' });
      return;
    }

    response.status(200).json({
      ok: true,
      service: 'befam-functions',
      region: APP_REGION,
      bootTimeIso: BOOT_TIME_ISO,
      timestampIso: new Date().toISOString(),
    });
  },
);
