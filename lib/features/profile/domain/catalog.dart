enum CatalogItemType { theme, avatar, initialSkin, bundle }

/// Future IAP / coin bundles grouping cosmetics (not sold in v6.0 shop UI yet).
class CatalogBundle {
  const CatalogBundle({
    required this.id,
    required this.name,
    required this.description,
    required this.itemIds,
    required this.priceCoins,
    this.iapProductId,
    this.enabled = false,
  });

  final String id;
  final String name;
  final String description;

  /// Theme, avatar, and/or initial skin ids included in the bundle.
  final List<String> itemIds;
  final int priceCoins;
  final String? iapProductId;

  /// When false, hidden from shop until bundle checkout is implemented.
  final bool enabled;
}

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
    this.bundles = const [],
  });

  final List<CatalogItem> themes;
  final List<CatalogItem> avatars;
  final List<CatalogItem> initialSkins;
  final List<CatalogBundle> bundles;
}

