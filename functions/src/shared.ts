import * as admin from 'firebase-admin';
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';

admin.initializeApp();

export const db = admin.firestore();

const projectId = process.env.GCLOUD_PROJECT ?? '';

/**
 * Gen-2 callables need `invoker: 'public'` so mobile clients can reach Cloud Run;
 * auth is enforced via Firebase ID tokens in `request.auth` (and App Check when enabled).
 */
export const callableOptions = {
  region: 'us-central1' as const,
  invoker: 'public' as const,
  /** Dev: off while simulators use debug tokens; prod: on. */
  enforceAppCheck: projectId === 'dot-clash-72cc6',
};

export function assertAuth(request: CallableRequest): string {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in first.');
  }
  return request.auth.uid;
}
