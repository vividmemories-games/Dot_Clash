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
    ];

    return CatalogSnapshot(themes: themes, avatars: avatars, initialSkins: initialSkins);
  }
}

