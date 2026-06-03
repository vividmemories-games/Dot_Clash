import { HttpsError } from 'firebase-functions/v2/https';

import { db } from './shared';

const CAMPAIGN_ID = 'dot_clash';

export interface LevelRewards {
  coinReward: number;
  xpReward: number;
  powerUpRewards: Record<string, number>;
}

export async function loadLevelRewards(levelId: string): Promise<LevelRewards> {
  const snap = await db
    .collection('campaigns')
    .doc(CAMPAIGN_ID)
    .collection('levels')
    .doc(levelId)
    .get();

  if (!snap.exists) {
    throw new HttpsError('not-found', `Unknown campaign level: ${levelId}`);
  }

  const data = snap.data()!;
  const rewards = data.rewards as { coins?: number; xp?: number } | undefined;
  const rawPowerUps = data.powerUpRewards as Record<string, number> | undefined;

  return {
    coinReward: Math.max(0, Number(rewards?.coins ?? 15)),
    xpReward: Math.max(0, Number(rewards?.xp ?? 20)),
    powerUpRewards: rawPowerUps ?? {},
  };
}
