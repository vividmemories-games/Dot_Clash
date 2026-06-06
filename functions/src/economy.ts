import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from 'firebase-functions/v2/https';

import {
  catalogEntry,
  DAILY_BOOST_QUANTITY,
  DAILY_REWARD_COINS,
  DAILY_REWARD_XP,
  equipKeyForKind,
  LIFE_REFILL_PRICE_COINS,
  ownedKeyForKind,
  POWER_UP_PRICES,
  REWARDED_AD_COINS,
  todayDailyBoostId,
} from './catalog';
import { assertAuth, callableOptions, db } from './shared';
import { onGrantLife, onLoss, resolveLives } from './lives';
import {
  coinsForMatch,
  levelForXp,
  xpForMatch,
} from './progression';

function profileRef(uid: string) {
  return db.collection('profiles').doc(uid);
}

function asStringList(value: unknown, fallback: string[]): string[] {
  if (!Array.isArray(value)) return [...fallback];
  return value.map(String);
}

function mergePowerUp(
  inv: Record<string, number>,
  powerUpId: string,
  quantity: number,
): Record<string, number> {
  const next = { ...inv };
  next[powerUpId] = (next[powerUpId] ?? 0) + quantity;
  return next;
}

export const purchaseCosmetic = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const { itemId, equip = true } = request.data as {
    itemId: string;
    equip?: boolean;
  };

  const entry = catalogEntry(itemId);
  if (!entry) {
    throw new HttpsError('invalid-argument', 'Unknown item.');
  }

  const ownedKey = ownedKeyForKind(entry.kind);
  const equipKey = equipKeyForKind(entry.kind);

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef(uid));
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;
    const owned = asStringList(profile[ownedKey], []);
    if (owned.includes(itemId)) {
      if (equip) {
        txn.update(profileRef(uid), {
          [equipKey]: itemId,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return { success: true, alreadyOwned: true };
    }
    const coins = Number(profile.coins ?? 0);
    if (coins < entry.priceCoins) {
      return { success: false, reason: 'insufficient_coins' };
    }

    const update: Record<string, unknown> = {
      coins: coins - entry.priceCoins,
      [ownedKey]: [...owned, itemId],
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (equip) update[equipKey] = itemId;

    txn.update(profileRef(uid), update);
    return { success: true };
  });
});

export const purchasePowerUp = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const { powerUpId, quantity = 1 } = request.data as {
    powerUpId: string;
    quantity?: number;
  };
  const qty = Math.max(1, Math.min(99, Number(quantity)));
  const price = POWER_UP_PRICES[powerUpId];
  if (price == null) {
    throw new HttpsError('invalid-argument', 'Unknown power-up.');
  }
  const totalPrice = price * qty;

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef(uid));
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;
    const coins = Number(profile.coins ?? 0);
    if (coins < totalPrice) {
      return { success: false, reason: 'insufficient_coins' };
    }
    const inv = (profile.powerUpInventory as Record<string, number>) ?? {};
    txn.update(profileRef(uid), {
      coins: coins - totalPrice,
      powerUpInventory: mergePowerUp(inv, powerUpId, qty),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

export const purchaseLife = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const nowMs = Date.now();

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef(uid));
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;
    const coins = Number(profile.coins ?? 0);
    if (coins < LIFE_REFILL_PRICE_COINS) {
      return { success: false, reason: 'insufficient_coins' };
    }

    const resolved = resolveLives(
      Number(profile.lives ?? 5),
      profile.nextLifeAt as Timestamp | null | undefined,
      nowMs,
    );
    if (resolved.lives >= 5) {
      return { success: false, reason: 'lives_full' };
    }

    const granted = onGrantLife(
      resolved.lives,
      resolved.nextLifeAt,
      nowMs,
    );

    txn.update(profileRef(uid), {
      coins: coins - LIFE_REFILL_PRICE_COINS,
      lives: granted.lives,
      nextLifeAt: granted.nextLifeAt,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

export const claimDailyReward = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const nowMs = Date.now();

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef(uid));
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;
    const last = profile.lastDailyClaimAt as Timestamp | undefined;
    if (last && nowMs - last.toMillis() < 24 * 60 * 60 * 1000) {
      return { success: false, reason: 'cooldown' };
    }

    const coins = Number(profile.coins ?? 0);
    const xp = Number(profile.xp ?? 0) + DAILY_REWARD_XP;
    const boostId = todayDailyBoostId();
    const inv = (profile.powerUpInventory as Record<string, number>) ?? {};

    txn.update(profileRef(uid), {
      coins: coins + DAILY_REWARD_COINS,
      xp,
      level: levelForXp(xp),
      powerUpInventory: mergePowerUp(inv, boostId, DAILY_BOOST_QUANTITY),
      lastDailyClaimAt: Timestamp.fromMillis(nowMs),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

export const claimRewardedAd = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const nowMs = Date.now();

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef(uid));
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;
    const last = profile.lastRewardedAdAt as Timestamp | undefined;
    if (last && nowMs - last.toMillis() < 30 * 60 * 1000) {
      return { success: false, reason: 'cooldown' };
    }

    txn.update(profileRef(uid), {
      coins: Number(profile.coins ?? 0) + REWARDED_AD_COINS,
      lastRewardedAdAt: Timestamp.fromMillis(nowMs),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

export const grantLifeFromAd = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const nowMs = Date.now();

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef(uid));
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;
    const resolved = resolveLives(
      Number(profile.lives ?? 5),
      profile.nextLifeAt as Timestamp | null | undefined,
      nowMs,
    );
    if (resolved.lives >= 5) {
      return { success: false, reason: 'lives_full' };
    }

    const granted = onGrantLife(
      resolved.lives,
      resolved.nextLifeAt,
      nowMs,
    );

    txn.update(profileRef(uid), {
      lives: granted.lives,
      nextLifeAt: granted.nextLifeAt,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

export const consumePowerUp = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const { powerUpId, quantity = 1 } = request.data as {
    powerUpId: string;
    quantity?: number;
  };
  const qty = Math.max(1, Number(quantity));

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef(uid));
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;
    const inv = { ...((profile.powerUpInventory as Record<string, number>) ?? {}) };
    const current = inv[powerUpId] ?? 0;
    if (current < qty) {
      return { success: false, reason: 'insufficient' };
    }
    const left = current - qty;
    if (left <= 0) delete inv[powerUpId];
    else inv[powerUpId] = left;

    txn.update(profileRef(uid), {
      powerUpInventory: inv,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

export const grantPowerUp = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const { powerUpId, quantity = 1 } = request.data as {
    powerUpId: string;
    quantity?: number;
  };
  const qty = Math.max(1, Math.min(99, Number(quantity)));

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef(uid));
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;
    const inv = (profile.powerUpInventory as Record<string, number>) ?? {};

    txn.update(profileRef(uid), {
      powerUpInventory: mergePowerUp(inv, powerUpId, qty),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: true };
  });
});

export const settleQuickMatch = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const data = request.data as {
    outcome: 'win' | 'loss' | 'tie';
    consumeLife?: boolean;
  };
  const outcome = data.outcome;
  if (!['win', 'loss', 'tie'].includes(outcome)) {
    throw new HttpsError('invalid-argument', 'Invalid outcome.');
  }
  const win = outcome === 'win';
  const tie = outcome === 'tie';
  const consumeLife = data.consumeLife === true;
  const nowMs = Date.now();

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(profileRef(uid));
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = snap.data()!;

    const deltaCoins = coinsForMatch(win, tie);
    const deltaXp = xpForMatch(win, tie);
    const newXp = Number(profile.xp ?? 0) + deltaXp;

    let rating = Number(profile.rating ?? 1000);
    if (win) rating += 18;
    else if (tie) rating += 2;
    else rating -= 18;
    if (rating < 800) rating = 800;

    const seasonBest = Math.max(Number(profile.seasonBestRating ?? 1000), rating);

    const resolved = resolveLives(
      Number(profile.lives ?? 5),
      profile.nextLifeAt as Timestamp | null | undefined,
      nowMs,
    );
    let lives = resolved.lives;
    let nextLifeAt = resolved.nextLifeAt;

    if (consumeLife && outcome === 'loss') {
      const lost = onLoss(lives, nextLifeAt, nowMs);
      lives = lost.lives;
      nextLifeAt = lost.nextLifeAt;
    }

    const newStreak = win
      ? Number(profile.winStreak ?? 0) + 1
      : tie
        ? Number(profile.winStreak ?? 0)
        : 0;
    const bestStreak = Math.max(Number(profile.bestWinStreak ?? 0), newStreak);

    txn.update(profileRef(uid), {
      coins: Number(profile.coins ?? 0) + deltaCoins,
      xp: newXp,
      level: levelForXp(newXp),
      wins: Number(profile.wins ?? 0) + (win ? 1 : 0),
      losses: Number(profile.losses ?? 0) + (outcome === 'loss' ? 1 : 0),
      ties: Number(profile.ties ?? 0) + (tie ? 1 : 0),
      gamesPlayed: Number(profile.gamesPlayed ?? 0) + 1,
      winStreak: newStreak,
      bestWinStreak: bestStreak,
      rating,
      seasonBestRating: seasonBest,
      seasonWins: Number(profile.seasonWins ?? 0) + (win ? 1 : 0),
      seasonLosses: Number(profile.seasonLosses ?? 0) + (outcome === 'loss' ? 1 : 0),
      seasonTies: Number(profile.seasonTies ?? 0) + (tie ? 1 : 0),
      lives,
      nextLifeAt,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { success: true };
  });
});

const projectId = process.env.GCLOUD_PROJECT ?? '';

/** Dev-only: clears daily claim cooldown for QA on simulators. */
export const devResetDailyClaim = onCall(callableOptions, async (request) => {
  if (projectId !== 'dot-clash-dev') {
    throw new HttpsError('permission-denied', 'Dev project only.');
  }
  const uid = assertAuth(request);
  await profileRef(uid).update({
    lastDailyClaimAt: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { success: true };
});
