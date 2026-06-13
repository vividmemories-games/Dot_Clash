import { FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from 'firebase-functions/v2/https';

import { assertAuth, callableOptions, db } from './shared';

const ANDROID_CHALLENGE_CHANNEL_ID = 'dot_clash_challenges';

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
  if (!snap.exists) {
    console.info('FCM challenge invite skipped', {
      targetUid,
      code,
      reason: 'profile_missing',
    });
    return;
  }

  const token = snap.data()?.fcmToken as string | undefined;
  if (!token) {
    console.info('FCM challenge invite skipped', {
      targetUid,
      code,
      reason: 'no_token',
    });
    return;
  }

  const title = 'Dot Clash challenge';
  const body = `${hostDisplayName} challenged you! Code: ${code}`;
  const sentAt = new Date().toISOString();

  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: {
        type: 'challenge_invite',
        code,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: ANDROID_CHALLENGE_CHANNEL_ID,
          priority: 'high',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
      },
    });
    console.info('FCM challenge invite sent', {
      targetUid,
      code,
      sentAt,
      tokenPrefix: token.slice(0, 8),
    });
  } catch (err) {
    console.warn('FCM challenge invite failed', {
      targetUid,
      code,
      sentAt,
      err,
    });
  }
}
