import { FieldValue, Timestamp, type DocumentData } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

import {
  MISSION_TARGETS,
  missionProgressForId,
  readDailyMissionProgress,
  todayUtc,
  yesterdayUtc,
} from './daily';
import { onLoss, resolveLives } from './lives';
import { levelForStars, totalStarsFromMap } from './progression';
import { deleteUserData } from './compliance';
import { assertAuth, callableOptions, db } from './shared';

export { deleteUserData };

interface CampaignSettleRequest {
  levelId: string;
  starsEarned: number;
  coinReward: number;
  xpReward: number;
  win: boolean;
  boxesCaptured?: number;
}

function bumpDailyMissions(
  profile: DocumentData,
  opts: { win: boolean; boxesCaptured: number },
): Record<string, unknown> {
  const progress = readDailyMissionProgress(profile);
  return {
    date: progress.date,
    wins: progress.wins + (opts.win ? 1 : 0),
    games: progress.games + 1,
    boxes: progress.boxes + Math.max(0, opts.boxesCaptured),
    claimed: progress.claimed,
  };
}

// ── Campaign level settlement ─────────────────────────────────────────────────

export const completeCampaignLevel = onCall(
  callableOptions,
  async (request) => {
    const uid = assertAuth(request);

    const data = request.data as CampaignSettleRequest;
    const { levelId, starsEarned, coinReward, xpReward, win } = data;
    const boxesCaptured = Number(data.boxesCaptured ?? 0);

    if (!levelId || typeof starsEarned !== 'number') {
      throw new HttpsError('invalid-argument', 'Missing fields.');
    }

    const clampedStars = Math.min(3, Math.max(0, starsEarned));
    const effectiveCoins = win ? coinReward : Math.floor(coinReward / 4);
    const effectiveXp = win ? xpReward : Math.floor(xpReward / 4);
    const nowMs = Date.now();

    const profileRef = db.collection('profiles').doc(uid);

    await db.runTransaction(async (txn) => {
      const snap = await txn.get(profileRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Profile not found.');
      }
      const profile = snap.data()!;

      const currentStars = (profile.campaignStars ?? {})[levelId] ?? 0;
      const updatedStars = { ...(profile.campaignStars ?? {}) } as Record<string, number>;
      if (clampedStars > currentStars) {
        updatedStars[levelId] = clampedStars;
      }

      const totalStars = totalStarsFromMap(updatedStars);
      const playerLevel = levelForStars(totalStars);

      const resolved = resolveLives(
        Number(profile.lives ?? 5),
        profile.nextLifeAt as Timestamp | null | undefined,
        nowMs,
      );
      let lives = resolved.lives;
      let nextLifeAt = resolved.nextLifeAt;
      if (!win) {
        const afterLoss = onLoss(lives, nextLifeAt, nowMs);
        lives = afterLoss.lives;
        nextLifeAt = afterLoss.nextLifeAt;
      }

      txn.update(profileRef, {
        campaignStars: updatedStars,
        lastCampaignLevelId: levelId,
        level: playerLevel,
        xp: (profile.xp ?? 0) + effectiveXp,
        coins: (profile.coins ?? 0) + effectiveCoins,
        gamesPlayed: (profile.gamesPlayed ?? 0) + 1,
        wins: (profile.wins ?? 0) + (win ? 1 : 0),
        losses: (profile.losses ?? 0) + (win ? 0 : 1),
        lives,
        nextLifeAt,
        dailyMissions: bumpDailyMissions(profile, { win, boxesCaptured }),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return { success: true };
  },
);

// ── Daily puzzle completion ───────────────────────────────────────────────────

export const completeDailyPuzzle = onCall(
  callableOptions,
  async (request) => {
    const uid = assertAuth(request);
    const data = request.data as {
      levelId: string;
      win: boolean;
      boxesCaptured?: number;
    };
    const { levelId, win } = data;
    if (!levelId) {
      throw new HttpsError('invalid-argument', 'Missing levelId.');
    }
    if (!win) {
      return { success: false, reason: 'loss' };
    }

    const today = todayUtc();
    const yesterday = yesterdayUtc();
    const coinReward = 50;
    const boxesCaptured = Number(data.boxesCaptured ?? 0);
    const profileRef = db.collection('profiles').doc(uid);

    await db.runTransaction(async (txn) => {
      const snap = await txn.get(profileRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Profile not found.');
      }
      const profile = snap.data()!;

      if (profile.dailyPuzzleDate === today && profile.dailyPuzzleCompleted === true) {
        return;
      }

      const lastDate = profile.dailyPuzzleDate as string | undefined;
      const prevStreak = Number(profile.dailyPuzzleStreak ?? 0);
      const newStreak =
        lastDate === yesterday ? prevStreak + 1 : lastDate === today ? prevStreak : 1;

      txn.update(profileRef, {
        dailyPuzzleDate: today,
        dailyPuzzleLevelId: levelId,
        dailyPuzzleCompleted: true,
        dailyPuzzleStreak: newStreak,
        coins: (profile.coins ?? 0) + coinReward,
        dailyMissions: bumpDailyMissions(profile, { win: true, boxesCaptured }),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return { success: true, coinReward };
  },
);

// ── Daily mission claim ─────────────────────────────────────────────────────────

export const claimDailyMission = onCall(
  callableOptions,
  async (request) => {
    const uid = assertAuth(request);
    const { missionId } = request.data as { missionId: string };
    const spec = MISSION_TARGETS[missionId];
    if (!spec) {
      throw new HttpsError('invalid-argument', 'Unknown mission.');
    }

    const profileRef = db.collection('profiles').doc(uid);

    return db.runTransaction(async (txn) => {
      const snap = await txn.get(profileRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Profile not found.');
      }
      const profile = snap.data()!;
      const progress = readDailyMissionProgress(profile);

      if (progress.claimed[missionId]) {
        return { success: false, reason: 'already_claimed' };
      }

      const current = missionProgressForId(missionId, progress);
      if (current < spec.target) {
        return { success: false, reason: 'not_complete' };
      }

      const claimed = { ...progress.claimed, [missionId]: true };
      txn.update(profileRef, {
        coins: (profile.coins ?? 0) + spec.coins,
        dailyMissions: { ...progress, claimed },
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { success: true, coinsGranted: spec.coins };
    });
  },
);
