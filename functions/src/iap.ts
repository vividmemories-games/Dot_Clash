import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import * as crypto from 'node:crypto';
import * as jwt from 'jsonwebtoken';

import { assertAuth, callableOptions, db } from './shared';
import { onCall } from 'firebase-functions/v2/https';

export const REMOVE_ADS_PRODUCT_ID = 'dot_clash_remove_ads';

const ALLOWED_PACKAGES = new Set([
  'com.vividmemories.dotclash',
  'com.vividmemories.dotclash.dev',
]);

const projectId = process.env.GCLOUD_PROJECT ?? '';
const isProd = projectId === 'dot-clash-72cc6';

interface VerifyRemoveAdsRequest {
  platform: 'ios' | 'android';
  productId: string;
  packageName?: string;
  purchaseToken?: string;
  verificationData?: string;
  localVerificationData?: string;
  source?: string;
}

function assertRemoveAdsProduct(productId: string): void {
  if (productId !== REMOVE_ADS_PRODUCT_ID) {
    throw new HttpsError('invalid-argument', 'Invalid product.');
  }
}

async function verifyAndroidPurchase(
  packageName: string,
  productId: string,
  token: string,
): Promise<void> {
  if (!ALLOWED_PACKAGES.has(packageName)) {
    throw new HttpsError('invalid-argument', 'Invalid package.');
  }
  if (!token || token.length < 10) {
    throw new HttpsError('invalid-argument', 'Missing purchase token.');
  }

  try {
    const { google } = await import('googleapis');
    const auth = await google.auth.getClient({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const androidpublisher = google.androidpublisher({ version: 'v3', auth });
    const res = await androidpublisher.purchases.products.get({
      packageName,
      productId,
      token,
    });
    const state = res.data.purchaseState;
    if (state !== 0) {
      throw new HttpsError('failed-precondition', 'Purchase not completed.');
    }
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    const message = err instanceof Error ? err.message : String(err);
    if (!isProd) {
      console.warn('[IAP] Android verify skipped (dev):', message);
      return;
    }
    throw new HttpsError('internal', `Play verification failed: ${message}`);
  }
}

function applePrivateKey(): string | null {
  const inline = process.env.APPLE_IAP_PRIVATE_KEY?.replace(/\\n/g, '\n');
  if (inline) return inline;
  return null;
}

function createAppleJwt(): string | null {
  const keyId = process.env.APPLE_IAP_KEY_ID;
  const issuerId = process.env.APPLE_IAP_ISSUER_ID;
  const key = applePrivateKey();
  if (!keyId || !issuerId || !key) return null;

  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: issuerId,
      iat: now,
      exp: now + 1200,
      aud: 'appstoreconnect-v1',
      bid: process.env.APPLE_IAP_BUNDLE_ID ?? 'com.vividmemories.dotclash',
    },
    key,
    { algorithm: 'ES256', keyid: keyId },
  );
}

function decodeJwsPayload(jws: string): Record<string, unknown> | null {
  const parts = jws.split('.');
  if (parts.length < 2) return null;
  try {
    const payload = parts[1];
    const padded = payload + '='.repeat((4 - (payload.length % 4)) % 4);
    const json = Buffer.from(padded.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString(
      'utf8',
    );
    return JSON.parse(json) as Record<string, unknown>;
  } catch {
    return null;
  }
}

async function verifyIosPurchase(
  verificationData: string,
  localVerificationData: string,
): Promise<void> {
  const jws = verificationData?.trim() || localVerificationData?.trim();
  if (!jws) {
    throw new HttpsError('invalid-argument', 'Missing iOS verification data.');
  }

  const appleJwt = createAppleJwt();
  if (!appleJwt) {
    if (!isProd) {
      console.warn('[IAP] iOS verify skipped (dev): APPLE_IAP_* secrets not set');
      return;
    }
    throw new HttpsError(
      'failed-precondition',
      'iOS IAP verification not configured (set APPLE_IAP_KEY_ID, APPLE_IAP_ISSUER_ID, APPLE_IAP_PRIVATE_KEY).',
    );
  }

  const payload = decodeJwsPayload(jws);
  const transactionId =
    (payload?.transactionId as string | undefined) ??
    (payload?.originalTransactionId as string | undefined);

  if (!transactionId) {
    throw new HttpsError('invalid-argument', 'Could not read transaction id from receipt.');
  }

  const host = isProd
    ? 'https://api.storekit.itunes.apple.com'
    : 'https://api.storekit-sandbox.itunes.apple.com';

  const url = `${host}/inApps/v1/transactions/${transactionId}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${appleJwt}` },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new HttpsError(
      'failed-precondition',
      `App Store verification failed (${res.status}): ${body.slice(0, 200)}`,
    );
  }

  const data = (await res.json()) as { signedTransactionInfo?: string };
  const txPayload = data.signedTransactionInfo
    ? decodeJwsPayload(data.signedTransactionInfo)
    : null;
  const productId = txPayload?.productId as string | undefined;
  if (productId && productId !== REMOVE_ADS_PRODUCT_ID) {
    throw new HttpsError('failed-precondition', 'Product mismatch.');
  }
}

async function verifyWithStore(data: VerifyRemoveAdsRequest): Promise<void> {
  if (data.platform === 'android') {
    const packageName = data.packageName?.trim();
    if (!packageName) {
      throw new HttpsError('invalid-argument', 'Missing packageName.');
    }
    const token = data.purchaseToken?.trim() || data.verificationData?.trim();
    if (!token) {
      throw new HttpsError('invalid-argument', 'Missing purchase token.');
    }
    await verifyAndroidPurchase(packageName, data.productId, token);
    return;
  }

  if (data.platform === 'ios') {
    await verifyIosPurchase(
      data.verificationData ?? '',
      data.localVerificationData ?? '',
    );
    return;
  }

  throw new HttpsError('invalid-argument', 'Invalid platform.');
}

function transactionDedupeKey(data: VerifyRemoveAdsRequest): string {
  const raw =
    data.purchaseToken ??
    data.verificationData ??
    data.localVerificationData ??
    '';
  return crypto.createHash('sha256').update(`${data.platform}:${raw}`).digest('hex');
}

export const verifyRemoveAdsPurchase = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const data = request.data as VerifyRemoveAdsRequest;

  assertRemoveAdsProduct(data.productId ?? '');
  await verifyWithStore(data);

  const dedupeKey = transactionDedupeKey(data);
  const profileRef = db.collection('profiles').doc(uid);

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef);
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;
    const processed = (profile.iapProcessedKeys as string[] | undefined) ?? [];
    if (processed.includes(dedupeKey)) {
      return;
    }

    txn.update(profileRef, {
      removeAds: true,
      iapProcessedKeys: [...processed.slice(-50), dedupeKey],
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});
