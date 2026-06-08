import { FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from 'firebase-functions/v2/https';

import { assertAuth, callableOptions, db } from './shared';

function profileRef(uid: string) {
  return db.collection('profiles').doc(uid);
}

export const registerFcmToken = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const { token } = request.data as { token?: string };
  if (!token || typeof token !== 'string' || token.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Missing token.');
  }

  await profileRef(uid).update({
    fcmToken: token.trim(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { success: true };
});

/**
 * Best-effort push when host challenges a recent rival.
 * Skips silently when the target has no registered token.
 */
export async function sendChallengeInvitePush(
  targetUid: string,
  hostDisplayName: string,
  code: string,
): Promise<void> {
  const snap = await profileRef(targetUid).get();
  if (!snap.exists) return;

  const token = snap.data()?.fcmToken as string | undefined;
  if (!token) return;

  try {
    await getMessaging().send({
      token,
      notification: {
        title: 'Dot Clash challenge',
        body: `${hostDisplayName} challenged you! Code: ${code}`,
      },
      data: {
        type: 'challenge_invite',
        code,
      },
    });
  } catch (err) {
    console.warn('FCM challenge invite failed', { targetUid, code, err });
  }
}
