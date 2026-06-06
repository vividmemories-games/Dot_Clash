/**
 * Clears profiles/{uid}.lastDailyClaimAt so daily can be claimed again.
 *
 * Usage (from repo root):
 *   node functions/scripts/reset_daily_claim.cjs [uid] [projectId]
 */
const admin = require('firebase-admin');

const uid = process.argv[2] ?? 'ssIUn3mwHJTgBctiQJBX2mzDg5a2';
const projectId = process.argv[3] ?? 'dot-clash-dev';

admin.initializeApp({ projectId });

admin
  .firestore()
  .doc(`profiles/${uid}`)
  .update({
    lastDailyClaimAt: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  })
  .then(() => {
    console.log(`Cleared lastDailyClaimAt for profiles/${uid} on ${projectId}`);
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
