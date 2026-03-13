import * as logger from 'firebase-functions/logger';

export function logInfo(message: string, context: Record<string, unknown> = {}) {
  logger.info(message, context);
}

export function logWarn(message: string, context: Record<string, unknown> = {}) {
  logger.warn(message, context);
}

export function logError(message: string, context: Record<string, unknown> = {}) {
  logger.error(message, context);
}
