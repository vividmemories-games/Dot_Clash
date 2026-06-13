import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import {
  ACTIVE_STALE_HOURS,
  commitChallengeMoveInTransaction,
  TURN_TIMEOUT_SECONDS,
} from './challenge';
import { db } from './shared';

const TURN_TIMEOUT_MS = TURN_TIMEOUT_SECONDS * 1000;
const ACTIVE_STALE_MS = ACTIVE_STALE_HOURS * 60 * 60 * 1000;

/**
 * Every minute: apply server turn timeouts, expire unjoined waiting rooms,
 * and auto-abandon stale active matches (24h inactivity).
 */
export const processChallengeTimeouts = onSchedule(
  {
    schedule: 'every 1 minutes',
    region: 'us-central1',
  },
  async () => {
    try {
      const now = Timestamp.now();
      const turnCutoff = Timestamp.fromMillis(now.toMillis() - TURN_TIMEOUT_MS);
      const staleCutoff = Timestamp.fromMillis(now.toMillis() - ACTIVE_STALE_MS);

      const [activeSnap, waitingSnap, staleSnap] = await Promise.all([
        db
          .collection('challenges')
          .where('status', '==', 'active')
          .where('turnStartedAt', '<=', turnCutoff)
          .limit(50)
          .get(),
        db
          .collection('challenges')
          .where('status', '==', 'waiting')
          .where('expiresAt', '<=', now)
          .limit(50)
          .get(),
        db
          .collection('challenges')
          .where('status', '==', 'active')
          .where('lastActivityAt', '<=', staleCutoff)
          .limit(50)
          .get(),
      ]);

      for (const doc of waitingSnap.docs) {
        try {
          await db.runTransaction(async (txn) => {
            const snap = await txn.get(doc.ref);
            if (!snap.exists) return;
            const data = snap.data()!;
            if (data.status !== 'waiting') return;
            const expiresAt = data.expiresAt as Timestamp;
            if (expiresAt.toMillis() > Date.now()) return;
            txn.update(doc.ref, {
              status: 'expired',
              lastActivityAt: FieldValue.serverTimestamp(),
            });
          });
        } catch (err) {
          console.warn('Expire waiting challenge failed', { code: doc.id, err });
        }
      }

      for (const doc of staleSnap.docs) {
        try {
          await db.runTransaction(async (txn) => {
            const snap = await txn.get(doc.ref);
            if (!snap.exists) return;
            const data = snap.data()!;
            if (data.status !== 'active') return;
            const lastActivityAt = data.lastActivityAt as Timestamp | undefined;
            if (!lastActivityAt) return;
            if (lastActivityAt.toMillis() > Date.now() - ACTIVE_STALE_MS) {
              return;
            }
            txn.update(doc.ref, {
              status: 'abandoned',
              winnerUid: null,
              lastActivityAt: FieldValue.serverTimestamp(),
            });
          });
        } catch (err) {
          console.warn('Stale challenge abandon failed', { code: doc.id, err });
        }
      }

      for (const doc of activeSnap.docs) {
        try {
          await db.runTransaction((txn) =>
            commitChallengeMoveInTransaction(txn, doc.ref, { isTimeout: true }),
          );
        } catch (err) {
          console.warn('Challenge timeout move failed', { code: doc.id, err });
        }
      }
    } catch (err) {
      console.error('processChallengeTimeouts failed', err);
    }
  },
);
