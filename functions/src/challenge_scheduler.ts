import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import {
  commitChallengeMoveInTransaction,
  TURN_TIMEOUT_SECONDS,
} from './challenge';
import { db } from './shared';

const TURN_TIMEOUT_MS = TURN_TIMEOUT_SECONDS * 1000;

/**
 * Every minute: apply server turn timeouts and expire unjoined waiting rooms.
 */
export const processChallengeTimeouts = onSchedule(
  {
    schedule: 'every 1 minutes',
    region: 'us-central1',
  },
  async () => {
    const now = Timestamp.now();
    const turnCutoff = Timestamp.fromMillis(now.toMillis() - TURN_TIMEOUT_MS);

    const [activeSnap, waitingSnap] = await Promise.all([
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

    for (const doc of activeSnap.docs) {
      try {
        await db.runTransaction((txn) =>
          commitChallengeMoveInTransaction(txn, doc.ref, { isTimeout: true }),
        );
      } catch (err) {
        console.warn('Challenge timeout move failed', { code: doc.id, err });
      }
    }
  },
);
