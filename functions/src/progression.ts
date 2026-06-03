/** Mirrors lib/features/profile/domain/progression.dart (campaign stars → player level). */

export const MAX_LIVES = 5;
export const LIFE_REGEN_MS = 20 * 60 * 1000;

export function starsToAdvanceFromPlayerLevel(level: number): number {
  return 12 + (level - 1) * 3;
}

export function starsForPlayerLevel(level: number): number {
  if (level <= 1) return 0;
  let total = 0;
  for (let l = 1; l < level; l++) {
    total += starsToAdvanceFromPlayerLevel(l);
  }
  return total;
}

export function levelForStars(totalStars: number): number {
  if (totalStars <= 0) return 1;
  let level = 1;
  while (level < 50 && totalStars >= starsForPlayerLevel(level + 1)) {
    level++;
  }
  return level;
}

export function totalStarsFromMap(stars: Record<string, number>): number {
  return Object.values(stars).reduce((sum, s) => sum + Math.min(3, Math.max(0, s)), 0);
}

export const BASE_XP = 100;
export const STEP_XP = 25;

export function xpForLevel(level: number): number {
  return BASE_XP + (level - 1) * STEP_XP;
}

export function levelForXp(xp: number): number {
  let level = 1;
  let remaining = xp;
  while (remaining >= xpForLevel(level)) {
    remaining -= xpForLevel(level);
    level++;
    if (level > 200) break;
  }
  return level;
}

export function coinsForMatch(win: boolean, tie: boolean): number {
  if (tie) return 8;
  return win ? 15 : 6;
}

export function xpForMatch(win: boolean, tie: boolean): number {
  if (tie) return 14;
  return win ? 22 : 10;
}
