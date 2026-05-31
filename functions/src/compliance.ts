import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

import { callableOptions, db } from './shared';

async function deleteCollectionInBatches(
  collectionRef: FirebaseFirestore.CollectionReference,
  batchSize = 400,
): Promise<number> {
  let deleted = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snap = await collectionRef.limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.size;
  }
  return deleted;
}

export const deleteUserData = onCall(callableOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in first.');
  }

  const profileRef = db.collection('profiles').doc(uid);
  const matchesRef = profileRef.collection('matches');

  const matchesDeleted = await deleteCollectionInBatches(matchesRef);
  await profileRef.delete().catch(() => undefined);

  // Legacy collection if present.
  await db.collection('users').doc(uid).delete().catch(() => undefined);

  await db.collection('accountDeletions').doc(uid).set({
    deletedAt: FieldValue.serverTimestamp(),
    matchesDeleted,
  });

  try {
    await admin.auth().deleteUser(uid);
  } catch (err: unknown) {
    const code = (err as { code?: string }).code;
    if (code === 'auth/requires-recent-login') {
      throw new HttpsError(
        'failed-precondition',
        'Recent sign-in required. Sign in again, then retry.',
      );
    }
    throw new HttpsError('internal', 'Could not delete account.');
  }

  return { success: true };
});
