import { Timestamp } from 'firebase-admin/firestore';

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
