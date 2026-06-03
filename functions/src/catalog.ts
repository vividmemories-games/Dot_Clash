/** Shop prices — keep in sync with lib/features/profile/data/mock_catalog_repository.dart */

export type CosmeticKind = 'theme' | 'avatar' | 'initialSkin';

export interface CatalogEntry {
  id: string;
  kind: CosmeticKind;
  priceCoins: number;
}

const ENTRIES: CatalogEntry[] = [
  { id: 'theme_neon_default', kind: 'theme', priceCoins: 0 },
  { id: 'theme_neon_ember', kind: 'theme', priceCoins: 250 },
  { id: 'theme_neon_mint', kind: 'theme', priceCoins: 250 },
  { id: 'theme_neon_aurora', kind: 'theme', priceCoins: 350 },
  { id: 'theme_neon_royal', kind: 'theme', priceCoins: 350 },
  { id: 'theme_neon_sunset', kind: 'theme', priceCoins: 400 },
  { id: 'theme_neon_frost', kind: 'theme', priceCoins: 400 },
  { id: 'theme_neon_void', kind: 'theme', priceCoins: 500 },
  { id: 'avatar_orb_cyan', kind: 'avatar', priceCoins: 0 },
  { id: 'avatar_orb_magenta', kind: 'avatar', priceCoins: 120 },
  { id: 'avatar_orb_gold', kind: 'avatar', priceCoins: 240 },
  { id: 'avatar_orb_lime', kind: 'avatar', priceCoins: 180 },
  { id: 'avatar_orb_coral', kind: 'avatar', priceCoins: 200 },
  { id: 'avatar_orb_violet', kind: 'avatar', priceCoins: 280 },
  { id: 'avatar_orb_ice', kind: 'avatar', priceCoins: 320 },
  { id: 'avatar_orb_rose', kind: 'avatar', priceCoins: 400 },
  { id: 'initial_skin_classic', kind: 'initialSkin', priceCoins: 0 },
  { id: 'initial_skin_glow', kind: 'initialSkin', priceCoins: 150 },
  { id: 'initial_skin_ultra', kind: 'initialSkin', priceCoins: 300 },
  { id: 'initial_skin_neon', kind: 'initialSkin', priceCoins: 180 },
  { id: 'initial_skin_outline', kind: 'initialSkin', priceCoins: 220 },
  { id: 'initial_skin_shadow', kind: 'initialSkin', priceCoins: 260 },
  { id: 'initial_skin_chrome', kind: 'initialSkin', priceCoins: 340 },
  { id: 'initial_skin_arcade', kind: 'initialSkin', priceCoins: 400 },
];

const BY_ID = new Map(ENTRIES.map((e) => [e.id, e]));

export function catalogEntry(id: string): CatalogEntry | undefined {
  return BY_ID.get(id);
}

export const POWER_UP_PRICES: Record<string, number> = {
  hold: 50,
  riposte: 80,
  extraTurns: 60,
  domino: 120,
  flow: 100,
};

export const LIFE_REFILL_PRICE_COINS = 100;
export const DAILY_REWARD_COINS = 60;
export const DAILY_REWARD_XP = 40;
export const REWARDED_AD_COINS = 35;
export const DAILY_BOOST_QUANTITY = 2;

export const DAILY_BOOST_SCHEDULE = ['hold', 'riposte', 'extraTurns'] as const;

export function todayDailyBoostId(utcNow = new Date()): string {
  const days = Math.floor(
    Date.UTC(utcNow.getUTCFullYear(), utcNow.getUTCMonth(), utcNow.getUTCDate()) /
      86_400_000,
  );
  return DAILY_BOOST_SCHEDULE[days % DAILY_BOOST_SCHEDULE.length];
}

export function ownedKeyForKind(kind: CosmeticKind): string {
  switch (kind) {
    case 'theme':
      return 'ownedThemeIds';
    case 'avatar':
      return 'ownedAvatarIds';
    case 'initialSkin':
      return 'ownedInitialSkinIds';
  }
}

export function equipKeyForKind(kind: CosmeticKind): string {
  switch (kind) {
    case 'theme':
      return 'themeId';
    case 'avatar':
      return 'avatarId';
    case 'initialSkin':
      return 'initialSkinId';
  }
}
