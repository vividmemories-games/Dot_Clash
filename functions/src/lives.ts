import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { assertAuth, callableOptions, db } from './shared';
import { LIFE_REGEN_MS, MAX_LIVES } from './progression';

export interface LivesState {
  lives: number;
  nextLifeAt: Timestamp | null;
}

function toMillis(ts: Timestamp | null | undefined): number | null {
  return ts ? ts.toMillis() : null;
}

export function resolveLives(
  lives: number,
  nextLifeAt: Timestamp | null | undefined,
  nowMs: number,
): LivesState {
  let resolvedLives = Math.min(MAX_LIVES, Math.max(0, lives));
  let nextMs = toMillis(nextLifeAt);

  if (resolvedLives >= MAX_LIVES) {
    return { lives: MAX_LIVES, nextLifeAt: null };
  }

  if (nextMs == null) {
    nextMs = nowMs + LIFE_REGEN_MS;
  }

  while (resolvedLives < MAX_LIVES && nextMs != null && nextMs <= nowMs) {
    resolvedLives++;
    if (resolvedLives < MAX_LIVES) {
      nextMs += LIFE_REGEN_MS;
    } else {
      nextMs = null;
    }
  }

  return {
    lives: resolvedLives,
    nextLifeAt: nextMs == null ? null : Timestamp.fromMillis(nextMs),
  };
}

export function onLoss(
  lives: number,
  nextLifeAt: Timestamp | null | undefined,
  nowMs: number,
): LivesState {
  const synced = resolveLives(lives, nextLifeAt, nowMs);
  let updatedLives = synced.lives;
  let updatedNext = synced.nextLifeAt;

  if (updatedLives > 0) {
    updatedLives -= 1;
    if (updatedLives < MAX_LIVES && updatedNext == null) {
      updatedNext = Timestamp.fromMillis(nowMs + LIFE_REGEN_MS);
    }
  }

  return { lives: updatedLives, nextLifeAt: updatedNext };
}

/** Coin purchase or rewarded ad — grant one life up to max. */
export function onGrantLife(
  lives: number,
  nextLifeAt: Timestamp | null | undefined,
  nowMs: number,
): LivesState {
  const synced = resolveLives(lives, nextLifeAt, nowMs);
  if (synced.lives >= MAX_LIVES) {
    return { lives: MAX_LIVES, nextLifeAt: null };
  }

  const updatedLives = synced.lives + 1;
  let updatedNext = synced.nextLifeAt;
  if (updatedLives >= MAX_LIVES) {
    updatedNext = null;
  } else if (updatedNext == null) {
    updatedNext = Timestamp.fromMillis(nowMs + LIFE_REGEN_MS);
  }

  return { lives: updatedLives, nextLifeAt: updatedNext };
}

function profileRef(uid: string) {
  return db.collection('profiles').doc(uid);
}

/** Passive life regen — clients cannot write lives/nextLifeAt directly. */
export const syncLives = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const nowMs = Date.now();

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef(uid));
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;
    const rawLives = Number(profile.lives ?? 5);
    const rawNext = profile.nextLifeAt as Timestamp | null | undefined;
    const resolved = resolveLives(rawLives, rawNext, nowMs);

    const resolvedNextMs = resolved.nextLifeAt?.toMillis() ?? null;
    const rawNextMs = rawNext?.toMillis() ?? null;
    if (resolved.lives === rawLives && resolvedNextMs === rawNextMs) {
      return { success: true, changed: false };
    }

    txn.update(profileRef(uid), {
      lives: resolved.lives,
      nextLifeAt: resolved.nextLifeAt,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: true, changed: true };
  });
});
