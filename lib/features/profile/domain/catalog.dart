enum CatalogItemType { theme, avatar, initialSkin }

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.type,
    required this.name,
    required this.priceCoins,
    this.iapProductId,
    this.enabled = true,
    this.rarity = 'common',
    this.previewAsset,
    this.previewPrimary,
    this.previewSecondary,
  });

  final String id;
  final CatalogItemType type;
  final String name;
  final int priceCoins;
  final String? iapProductId;
  final bool enabled;
  final String rarity;

  /// Optional asset path for preview thumbnails (not required for v1).
  final String? previewAsset;

  /// Optional colors for theme previews (ARGB ints).
  final int? previewPrimary;
  final int? previewSecondary;
}

class CatalogSnapshot {
  const CatalogSnapshot({
    required this.themes,
    required this.avatars,
    required this.initialSkins,
  });

  final List<CatalogItem> themes;
  final List<CatalogItem> avatars;
  final List<CatalogItem> initialSkins;
}

