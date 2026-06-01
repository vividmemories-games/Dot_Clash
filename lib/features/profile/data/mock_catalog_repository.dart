import '../domain/catalog.dart';

class MockCatalogRepository {
  const MockCatalogRepository();

  CatalogSnapshot getCatalog() {
    final themes = <CatalogItem>[
      const CatalogItem(
        id: 'theme_neon_default',
        type: CatalogItemType.theme,
        name: 'Neon Default',
        priceCoins: 0,
        rarity: 'starter',
        previewPrimary: 0xFF00D4FF,
        previewSecondary: 0xFFFF2EFF,
      ),
      const CatalogItem(
        id: 'theme_neon_ember',
        type: CatalogItemType.theme,
        name: 'Neon Ember',
        priceCoins: 250,
        rarity: 'rare',
        previewPrimary: 0xFFFFB830,
        previewSecondary: 0xFFFF4C4C,
      ),
      const CatalogItem(
        id: 'theme_neon_mint',
        type: CatalogItemType.theme,
        name: 'Neon Mint',
        priceCoins: 250,
        rarity: 'rare',
        previewPrimary: 0xFF00E676,
        previewSecondary: 0xFF00D4FF,
      ),
      const CatalogItem(
        id: 'theme_neon_aurora',
        type: CatalogItemType.theme,
        name: 'Neon Aurora',
        priceCoins: 350,
        rarity: 'epic',
        previewPrimary: 0xFFB8FF30,
        previewSecondary: 0xFF9D4DFF,
      ),
      const CatalogItem(
        id: 'theme_neon_royal',
        type: CatalogItemType.theme,
        name: 'Neon Royal',
        priceCoins: 350,
        rarity: 'epic',
        previewPrimary: 0xFF4DDCFF,
        previewSecondary: 0xFF6D5BFF,
      ),
      const CatalogItem(
        id: 'theme_neon_sunset',
        type: CatalogItemType.theme,
        name: 'Neon Sunset',
        priceCoins: 400,
        rarity: 'epic',
        previewPrimary: 0xFFFF7A45,
        previewSecondary: 0xFFFF3D8A,
      ),
      const CatalogItem(
        id: 'theme_neon_frost',
        type: CatalogItemType.theme,
        name: 'Neon Frost',
        priceCoins: 400,
        rarity: 'epic',
        previewPrimary: 0xFFB8F0FF,
        previewSecondary: 0xFF4D9FFF,
      ),
      const CatalogItem(
        id: 'theme_neon_void',
        type: CatalogItemType.theme,
        name: 'Neon Void',
        priceCoins: 500,
        rarity: 'legendary',
        previewPrimary: 0xFFE040FF,
        previewSecondary: 0xFF7C4DFF,
      ),
    ];

    final avatars = <CatalogItem>[
      const CatalogItem(
        id: 'avatar_orb_cyan',
        type: CatalogItemType.avatar,
        name: 'Cyan Orb',
        priceCoins: 0,
        rarity: 'starter',
      ),
      const CatalogItem(
        id: 'avatar_orb_magenta',
        type: CatalogItemType.avatar,
        name: 'Magenta Orb',
        priceCoins: 120,
        rarity: 'common',
      ),
      const CatalogItem(
        id: 'avatar_orb_gold',
        type: CatalogItemType.avatar,
        name: 'Gold Orb',
        priceCoins: 240,
        rarity: 'rare',
      ),
      const CatalogItem(
        id: 'avatar_orb_lime',
        type: CatalogItemType.avatar,
        name: 'Lime Orb',
        priceCoins: 180,
        rarity: 'common',
      ),
      const CatalogItem(
        id: 'avatar_orb_coral',
        type: CatalogItemType.avatar,
        name: 'Coral Orb',
        priceCoins: 200,
        rarity: 'common',
      ),
      const CatalogItem(
        id: 'avatar_orb_violet',
        type: CatalogItemType.avatar,
        name: 'Violet Orb',
        priceCoins: 280,
        rarity: 'rare',
      ),
      const CatalogItem(
        id: 'avatar_orb_ice',
        type: CatalogItemType.avatar,
        name: 'Ice Orb',
        priceCoins: 320,
        rarity: 'rare',
      ),
      const CatalogItem(
        id: 'avatar_orb_rose',
        type: CatalogItemType.avatar,
        name: 'Rose Orb',
        priceCoins: 400,
        rarity: 'epic',
      ),
    ];

    final initialSkins = <CatalogItem>[
      const CatalogItem(
        id: 'initial_skin_classic',
        type: CatalogItemType.initialSkin,
        name: 'Classic',
        priceCoins: 0,
        rarity: 'starter',
      ),
      const CatalogItem(
        id: 'initial_skin_glow',
        type: CatalogItemType.initialSkin,
        name: 'Glow',
        priceCoins: 150,
        rarity: 'common',
      ),
      const CatalogItem(
        id: 'initial_skin_ultra',
        type: CatalogItemType.initialSkin,
        name: 'Ultra',
        priceCoins: 300,
        rarity: 'epic',
      ),
      const CatalogItem(
        id: 'initial_skin_neon',
        type: CatalogItemType.initialSkin,
        name: 'Neon',
        priceCoins: 180,
        rarity: 'common',
      ),
      const CatalogItem(
        id: 'initial_skin_outline',
        type: CatalogItemType.initialSkin,
        name: 'Outline',
        priceCoins: 220,
        rarity: 'common',
      ),
      const CatalogItem(
        id: 'initial_skin_shadow',
        type: CatalogItemType.initialSkin,
        name: 'Shadow',
        priceCoins: 260,
        rarity: 'rare',
      ),
      const CatalogItem(
        id: 'initial_skin_chrome',
        type: CatalogItemType.initialSkin,
        name: 'Chrome',
        priceCoins: 340,
        rarity: 'rare',
      ),
      const CatalogItem(
        id: 'initial_skin_arcade',
        type: CatalogItemType.initialSkin,
        name: 'Arcade',
        priceCoins: 400,
        rarity: 'epic',
      ),
    ];

    const bundles = <CatalogBundle>[
      CatalogBundle(
        id: 'bundle_starter_rival',
        name: 'Rival Pack',
        description: 'Sunset theme + Rose orb + Neon initial (planned IAP).',
        itemIds: [
          'theme_neon_sunset',
          'avatar_orb_rose',
          'initial_skin_neon',
        ],
        priceCoins: 850,
        enabled: false,
      ),
      CatalogBundle(
        id: 'bundle_ice_queen',
        name: 'Ice Queen Pack',
        description: 'Frost theme + Ice orb + Chrome initial (planned IAP).',
        itemIds: [
          'theme_neon_frost',
          'avatar_orb_ice',
          'initial_skin_chrome',
        ],
        priceCoins: 950,
        enabled: false,
      ),
      CatalogBundle(
        id: 'bundle_void_master',
        name: 'Void Master Pack',
        description: 'Void theme + Violet orb + Arcade initial (planned IAP).',
        itemIds: [
          'theme_neon_void',
          'avatar_orb_violet',
          'initial_skin_arcade',
        ],
        priceCoins: 1100,
        enabled: false,
      ),
    ];

    return CatalogSnapshot(
      themes: themes,
      avatars: avatars,
      initialSkins: initialSkins,
      bundles: bundles,
    );
  }
}
