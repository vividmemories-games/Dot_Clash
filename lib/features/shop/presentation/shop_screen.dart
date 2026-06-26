import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env/app_env.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dot_clash_visuals.dart';
import '../../../features/home/presentation/widgets/lives_refill_sheet.dart';
import '../../../features/home/presentation/widgets/resource_pill.dart';
import '../../../features/powerups/domain/power_up.dart';
import '../../../features/powerups/domain/power_up_catalog.dart';
import '../../../features/profile/domain/catalog.dart';
import '../../../features/profile/domain/lives_logic.dart';
import '../../../features/profile/domain/progression.dart';
import '../../../features/profile/providers/lives_provider.dart';
import '../../../features/profile/providers/profile_providers.dart';
import '../../../shared/feedback/app_haptics.dart';
import '../../../shared/layout/app_spacing.dart';
import '../../../shared/navigation/main_shell_swipe.dart';
import '../../../shared/widgets/equipped_avatar.dart';
import '../../../shared/widgets/initial_skin_style.dart';
import '../../../shared/widgets/neon_card.dart';
import '../../../features/profile/domain/rewarded_ad_rules.dart';
import '../../../services/ads/ad_reward_router.dart';
import '../../../services/ads/rewarded_ad_messages.dart';
import '../../../services/analytics/analytics_service.dart';
import '../../../services/iap/iap_service.dart';

/// True while any shop coin purchase / daily claim is awaiting the server.
final shopPurchaseInFlightProvider = StateProvider<bool>((ref) => false);

String _formatLifeTimer(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatDailyCooldown(Duration duration) {
  if (duration <= Duration.zero) return 'now';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

bool _isDailyClaimAvailable(DateTime? lastDailyClaimAt) {
  if (lastDailyClaimAt == null) return true;
  return DateTime.now().difference(lastDailyClaimAt) >=
      const Duration(hours: 24);
}

Duration _dailyClaimCooldownRemaining(DateTime? lastDailyClaimAt) {
  if (lastDailyClaimAt == null) return Duration.zero;
  const window = Duration(hours: 24);
  final elapsed = DateTime.now().difference(lastDailyClaimAt);
  if (elapsed >= window) return Duration.zero;
  return window - elapsed;
}

Future<void> _showShopBoolResult(
  WidgetRef ref,
  BuildContext context, {
  required Future<bool> Function() purchase,
  required String successMessage,
  String failureMessage = 'Not enough coins.',
  String errorMessage = 'Couldn\'t connect. Try again.',
}) async {
  if (ref.read(shopPurchaseInFlightProvider)) return;
  ref.read(shopPurchaseInFlightProvider.notifier).state = true;
  AppHaptics.lightImpact();
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(successMessage),
      duration: const Duration(seconds: 2),
    ),
  );
  try {
    final ok = await purchase();
    if (!context.mounted) return;
    if (!ok) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  } catch (e, st) {
    unawaited(AnalyticsService.instance.recordError(e, st));
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
  } finally {
    ref.read(shopPurchaseInFlightProvider.notifier).state = false;
  }
}

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  static const _tabLabels = ['THEMES', 'AVATARS', 'INITIALS', 'BOOSTS'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = context.dc;
    final t = context.txt;
    final profileAsync = ref.watch(profileProvider);
    final livesSnapshot = ref.watch(livesSnapshotProvider);
    final catalog = ref.watch(catalogProvider);
    final repo = ref.watch(profileRepositoryProvider);
    final livesController = ref.watch(livesControllerProvider);
    final removeAdsProductAsync = ref.watch(removeAdsProductProvider);
    final iap = ref.read(iapServiceProvider);
    final purchaseInFlight = ref.watch(shopPurchaseInFlightProvider);

    void openLivesSheet() {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: v.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: v.cardBorder),
        ),
        builder: (_) => LivesRefillSheet(
          onBuyLife: livesController.purchaseLife,
          onWatchAd: () =>
              ref.read(adRewardRouterProvider).showRewardedLifeAd(),
        ),
      );
    }

    return profileAsync.when(
      loading: () => Scaffold(
        backgroundColor: v.scaffold,
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: v.scaffold,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('SHOP'),
        ),
        body: SafeArea(
          child: Padding(
            padding: AppSpacing.pagePadding,
            child: Text('$e', style: t.bodySmall),
          ),
        ),
      ),
      data: (profile) => DefaultTabController(
        length: _tabLabels.length,
        child: Builder(
          builder: (tabContext) {
            void goToBoostsTab() {
              DefaultTabController.of(tabContext).animateTo(3);
            }

            return Scaffold(
              backgroundColor: v.scaffold,
              body: SafeArea(
                child: Column(
                  children: [
                    _ShopHeader(
                      coins: profile.coins,
                      livesSnapshot: livesSnapshot,
                      onCoinsTap: goToBoostsTab,
                      onLivesTap: openLivesSheet,
                    ),
                    const _ShopTabBar(labels: _tabLabels),
                    Expanded(
                      child: ShopOuterSwipeBridge(
                        child: TabBarView(
                          children: [
                            _CosmeticCatalogTab(
                              ref: ref,
                              purchaseInFlight: purchaseInFlight,
                              title: 'CHOOSE YOUR THEME',
                              subtitle:
                                  'Personalize your matches. Only you can see your theme.',
                              coins: profile.coins,
                              items: catalog.themes,
                              ownedIds: profile.ownedThemeIds,
                              equippedId: profile.themeId,
                              onBuy: (item) =>
                                  repo.purchaseTheme(item.id, item.priceCoins),
                              onEquip: (item) => repo.equipTheme(item.id),
                            ),
                            _CosmeticCatalogTab(
                              ref: ref,
                              purchaseInFlight: purchaseInFlight,
                              title: 'CHOOSE YOUR AVATAR',
                              subtitle:
                                  'Show off on the home screen and in matches.',
                              coins: profile.coins,
                              items: catalog.avatars,
                              ownedIds: profile.ownedAvatarIds,
                              equippedId: profile.avatarId,
                              onBuy: (item) =>
                                  repo.purchaseAvatar(item.id, item.priceCoins),
                              onEquip: (item) => repo.equipAvatar(item.id),
                            ),
                            _CosmeticCatalogTab(
                              ref: ref,
                              purchaseInFlight: purchaseInFlight,
                              title: 'CHOOSE YOUR INITIAL',
                              subtitle:
                                  'Your letter on the scoreboard during play.',
                              coins: profile.coins,
                              items: catalog.initialSkins,
                              ownedIds: profile.ownedInitialSkinIds,
                              equippedId: profile.initialSkinId,
                              onBuy: (item) => repo.purchaseInitialSkin(
                                item.id,
                                item.priceCoins,
                              ),
                              onEquip: (item) => repo.equipInitialSkin(item.id),
                            ),
                            _BoostsAndStoreTab(
                              ref: ref,
                              purchaseInFlight: purchaseInFlight,
                              inventory: profile.powerUpInventory,
                              coins: profile.coins,
                              lastDailyClaimAt: profile.lastDailyClaimAt,
                              lastRewardedAdAt: profile.lastRewardedAdAt,
                              snapshot: livesSnapshot,
                              removeAds: profile.removeAds,
                              removeAdsPrice:
                                  removeAdsProductAsync.valueOrNull?.price,
                              onBuyBoost: (type) => repo.purchasePowerUp(
                                type.id,
                                PowerUpCatalog.priceFor(type),
                              ),
                              onBuyLife: livesController.purchaseLife,
                              onOpenLivesSheet: openLivesSheet,
                              onWatchAdForLife: () => ref
                                  .read(adRewardRouterProvider)
                                  .showRewardedLifeAd(),
                              onClaimDaily: repo.claimDaily,
                              onDevResetDaily:
                                  AppEnv.isDev ? repo.devResetDailyClaim : null,
                              onWatchAdForCoins: () => ref
                                  .read(adRewardRouterProvider)
                                  .showRewardedShopCoins(),
                              onPurchaseRemoveAds: () async {
                                final ok = await iap.purchaseRemoveAds();
                                return (
                                  ok,
                                  ok ? null : iap.lastPurchaseError,
                                );
                              },
                              onRestorePurchases: iap.restorePurchases,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShopHeader extends StatefulWidget {
  const _ShopHeader({
    required this.coins,
    required this.livesSnapshot,
    required this.onCoinsTap,
    required this.onLivesTap,
  });

  final int coins;
  final LivesSnapshot livesSnapshot;
  final VoidCallback onCoinsTap;
  final VoidCallback onLivesTap;

  @override
  State<_ShopHeader> createState() => _ShopHeaderState();
}

class _ShopHeaderState extends State<_ShopHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _coinPulse;
  late final Animation<double> _coinScale;

  @override
  void initState() {
    super.initState();
    _coinPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _coinScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.13),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.13, end: 1),
        weight: 65,
      ),
    ]).animate(CurvedAnimation(parent: _coinPulse, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_ShopHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coins != oldWidget.coins) {
      _coinPulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _coinPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final livesColor = widget.livesSnapshot.isFull ? v.green : v.red;
    final timer = widget.livesSnapshot.timeUntilNextLife ?? Duration.zero;
    final timerLabel = _formatLifeTimer(timer);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ScaleTransition(
                scale: _coinScale,
                child: ResourcePill(
                  icon: Icons.monetization_on_rounded,
                  label: '${widget.coins}',
                  iconColor: v.gold,
                  trailing: Icon(
                    Icons.add_circle_rounded,
                    size: 14,
                    color: v.gold,
                  ),
                  onTap: widget.onCoinsTap,
                ),
              ),
            ),
          ),
          Text(
            'SHOP',
            style: t.scoreLabel.copyWith(
              color: v.gold,
              letterSpacing: 2.5,
              shadows: v.useGlow
                  ? [
                      Shadow(
                        color: v.gold.withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ResourcePill(
                    icon: Icons.favorite_rounded,
                    label:
                        '${widget.livesSnapshot.effectiveLives}/${Progression.maxLives}',
                    iconColor: livesColor,
                    trailing: Icon(
                      Icons.add_circle_rounded,
                      size: 14,
                      color: livesColor,
                    ),
                    onTap: widget.onLivesTap,
                  ),
                  if (!widget.livesSnapshot.isFull) ...[
                    AppSpacing.vGapXS,
                    Text(
                      'Next life in $timerLabel',
                      style: t.bodySmall.copyWith(
                        fontSize: 10,
                        color: v.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopTabBar extends StatefulWidget {
  const _ShopTabBar({required this.labels});

  final List<String> labels;

  @override
  State<_ShopTabBar> createState() => _ShopTabBarState();
}

class _ShopTabBarState extends State<_ShopTabBar> {
  TabController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DefaultTabController.of(context);
    if (_controller != next) {
      _controller?.removeListener(_onTabChanged);
      _controller = next;
      _controller?.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final controller = _controller!;
    final selected = controller.index;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: List.generate(widget.labels.length, (i) {
          final isSelected = selected == i;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 4,
                right: i == widget.labels.length - 1 ? 0 : 4,
              ),
              child: _ShopTabPill(
                label: widget.labels[i],
                isSelected: isSelected,
                onTap: () => controller.animateTo(i),
                visuals: v,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ShopTabPill extends StatelessWidget {
  const _ShopTabPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.visuals,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final DotClashVisuals visuals;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final v = visuals;
    final activeGradient = LinearGradient(
      colors: [v.gold, const Color(0xFFFF8C42)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppSpacing.roundedFull,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? activeGradient : null,
            color: isSelected ? null : v.surface.withValues(alpha: 0.6),
            borderRadius: AppSpacing.roundedFull,
            border: Border.all(
              color: isSelected
                  ? v.gold.withValues(alpha: 0.9)
                  : v.gold.withValues(alpha: 0.35),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected && v.useGlow
                ? [
                    BoxShadow(
                      color: v.gold.withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.scoreLabel.copyWith(
                  fontSize: 9,
                  letterSpacing: 0.6,
                  color: isSelected ? const Color(0xFF1A0F00) : v.gold,
                ),
              ),
              if (isSelected)
                const Positioned(
                  top: -6,
                  right: -2,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 10,
                    color: Color(0xFFFFF8E7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopPillButton extends StatelessWidget {
  const _ShopPillButton({
    required this.label,
    required this.color,
    this.icon,
    this.onPressed,
    this.enabled = true,
    this.expanded = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final isEnabled = enabled && onPressed != null;
    final effectiveColor = isEnabled ? color : v.textDisabled;
    final borderRadius =
        expanded ? AppSpacing.roundedMD : AppSpacing.roundedFull;
    final verticalPad = expanded ? 14.0 : 10.0;
    final horizontalPad = expanded ? 16.0 : 14.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: isEnabled ? onPressed : null,
        child: Container(
          width: expanded ? double.infinity : null,
          constraints: expanded ? null : const BoxConstraints(minWidth: 76),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPad,
            vertical: verticalPad,
          ),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.12),
            borderRadius: borderRadius,
            border: Border.all(color: effectiveColor, width: 1.5),
            boxShadow: isEnabled && v.useGlow
                ? [
                    BoxShadow(
                      color: effectiveColor.withValues(alpha: 0.28),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: effectiveColor),
                SizedBox(width: expanded ? 8 : 6),
              ],
              if (expanded)
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      height: 1.2,
                      color: effectiveColor,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    height: 1.2,
                    color: effectiveColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CosmeticCatalogTab extends StatelessWidget {
  const _CosmeticCatalogTab({
    required this.ref,
    required this.purchaseInFlight,
    required this.title,
    required this.subtitle,
    required this.coins,
    required this.items,
    required this.ownedIds,
    required this.equippedId,
    required this.onBuy,
    required this.onEquip,
  });

  final WidgetRef ref;
  final bool purchaseInFlight;

  final String title;
  final String subtitle;
  final int coins;
  final List<CatalogItem> items;
  final List<String> ownedIds;
  final String equippedId;
  final Future<bool> Function(CatalogItem item) onBuy;
  final Future<void> Function(CatalogItem item) onEquip;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = _cosmeticCatalogGridAspectRatio(
          context,
          gridWidth: constraints.maxWidth,
          items: items,
        );

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 16, color: v.gold),
                        AppSpacing.hGapXS,
                        Expanded(
                          child: Text(
                            title,
                            style: t.scoreLabel.copyWith(
                              fontSize: 13,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vGapXS,
                    Text(
                      subtitle,
                      style: t.bodySmall.copyWith(color: v.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _cosmeticCatalogCrossAxisCount,
                  childAspectRatio: aspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = items[i];
                    final owned =
                        ownedIds.contains(item.id) || item.priceCoins == 0;
                    final equipped = equippedId == item.id;
                    final canAfford = coins >= item.priceCoins;
                    return _CatalogCard(
                      item: item,
                      owned: owned,
                      equipped: equipped,
                      canAfford: canAfford && !purchaseInFlight,
                      onBuy: () async {
                        await _showShopBoolResult(
                          ref,
                          context,
                          purchase: () => onBuy(item),
                          successMessage: 'Purchased!',
                        );
                      },
                      onEquip: () async => onEquip(item),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Grid layout for cosmetic shop tabs (themes / avatars / initials).
const int _cosmeticCatalogCrossAxisCount = 2;
const double _cosmeticCatalogGridHorizontalInset = 32; // 16 + 16 sliver padding
const double _cosmeticCatalogGridCrossSpacing = 12;

/// Estimates minimum catalog card height and returns width/height for [SliverGrid].
double _cosmeticCatalogGridAspectRatio(
  BuildContext context, {
  required double gridWidth,
  required List<CatalogItem> items,
}) {
  final width = gridWidth.isFinite && gridWidth > 0
      ? gridWidth
      : MediaQuery.sizeOf(context).width;
  final cellWidth = (width -
          _cosmeticCatalogGridHorizontalInset -
          _cosmeticCatalogGridCrossSpacing) /
      _cosmeticCatalogCrossAxisCount;

  final textScale = MediaQuery.textScalerOf(context).scale(1);
  final hasOrbPreview = items.any(
    (i) =>
        i.type == CatalogItemType.avatar ||
        i.type == CatalogItemType.initialSkin,
  );
  final hasThemeSwatches = items.any((i) => i.type == CatalogItemType.theme);

  // Mirrors [_CatalogCard] fixed vertical stack + [NeonCard] padding.
  var minHeight = AppSpacing.md * 2; // NeonCard padding
  minHeight += 13 * 1.2 * textScale; // title
  minHeight += AppSpacing.xs;
  minHeight += 12 * 1.4 * textScale; // rarity
  if (hasThemeSwatches) {
    minHeight += AppSpacing.xs + 12; // swatch row
  }
  if (hasOrbPreview) {
    minHeight += AppSpacing.sm + 42; // orb / initial preview
  }
  minHeight += 6 + 20 * textScale; // price row
  minHeight += 34; // action button
  minHeight += 6; // safety buffer (avoids 11px overflow on narrow phones)

  final aspect = cellWidth / minHeight;
  return aspect.clamp(0.72, 1.12);
}

class _BoostsAndStoreTab extends StatelessWidget {
  const _BoostsAndStoreTab({
    required this.ref,
    required this.purchaseInFlight,
    required this.inventory,
    required this.coins,
    required this.lastDailyClaimAt,
    required this.lastRewardedAdAt,
    required this.snapshot,
    required this.removeAds,
    required this.removeAdsPrice,
    required this.onBuyBoost,
    required this.onBuyLife,
    required this.onOpenLivesSheet,
    required this.onWatchAdForLife,
    required this.onClaimDaily,
    this.onDevResetDaily,
    required this.onWatchAdForCoins,
    required this.onPurchaseRemoveAds,
    required this.onRestorePurchases,
  });

  final WidgetRef ref;
  final bool purchaseInFlight;

  final Map<String, int> inventory;
  final int coins;
  final DateTime? lastDailyClaimAt;
  final DateTime? lastRewardedAdAt;
  final LivesSnapshot snapshot;
  final bool removeAds;
  final String? removeAdsPrice;
  final Future<bool> Function(PowerUpType type) onBuyBoost;
  final Future<bool> Function() onBuyLife;
  final VoidCallback onOpenLivesSheet;
  final Future<bool> Function() onWatchAdForLife;
  final Future<bool> Function() onClaimDaily;
  final Future<bool> Function()? onDevResetDaily;
  final Future<bool> Function() onWatchAdForCoins;
  final Future<(bool ok, String? error)> Function() onPurchaseRemoveAds;
  final Future<bool> Function() onRestorePurchases;

  static const _boostTypes = [
    PowerUpType.hold,
    PowerUpType.riposte,
    PowerUpType.extraTurns,
  ];

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final router = ref.read(adRewardRouterProvider);
    final coinCooldown =
        RewardedAdRules.coinCooldownRemaining(lastRewardedAdAt);
    final canWatchCoinAd = router.canShowRewardedShopCoins(lastRewardedAdAt);
    final canWatchLifeAd = router.canShowRewardedLifeAd(snapshot);
    final canBuyLife = !snapshot.isFull &&
        coins >= Progression.lifeRefillPriceCoins &&
        !purchaseInFlight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SectionLabel(title: 'BOOSTS', icon: Icons.bolt_rounded, color: v.gold),
        AppSpacing.vGapSM,
        ..._boostTypes.map((type) {
          final price = PowerUpCatalog.priceFor(type);
          final owned = inventory[type.id] ?? 0;
          final canBuy = coins >= price && !purchaseInFlight;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NeonCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PowerUpCatalog.labels[type] ?? type.id,
                          style: t.playerName.copyWith(
                            color: PowerUpCatalog.accentFor(type, v),
                          ),
                        ),
                        AppSpacing.vGapXS,
                        Text(
                          PowerUpCatalog.descriptions[type] ?? '',
                          style: t.bodySmall,
                        ),
                        AppSpacing.vGapXS,
                        Text(
                          'Owned: $owned',
                          style: t.bodySmall.copyWith(color: v.gold),
                        ),
                      ],
                    ),
                  ),
                  _ShopPillButton(
                    label: '$price',
                    icon: Icons.monetization_on_rounded,
                    color: v.gold,
                    enabled: canBuy,
                    onPressed: canBuy
                        ? () => _showShopBoolResult(
                              ref,
                              context,
                              purchase: () => onBuyBoost(type),
                              successMessage: 'Boost purchased!',
                            )
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
        AppSpacing.vGapLG,
        _SectionLabel(
          title: 'RESOURCES',
          icon: Icons.favorite_rounded,
          color: v.red,
        ),
        AppSpacing.vGapSM,
        NeonCard(
          glowColor: v.red.withValues(alpha: 0.12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    snapshot.isFull
                        ? 'Lives full'
                        : 'Lives ${snapshot.effectiveLives}/${Progression.maxLives}',
                    style: t.playerName.copyWith(color: v.red),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.info_outline_rounded,
                        color: v.textSecondary),
                    onPressed: onOpenLivesSheet,
                  ),
                ],
              ),
              if (!snapshot.isFull)
                Text(
                  'Next life in ${_formatLifeTimer(snapshot.timeUntilNextLife ?? Duration.zero)}',
                  style: t.bodySmall,
                ),
              AppSpacing.vGapSM,
              _ShopPillButton(
                label:
                    'Refill 1 life · ${Progression.lifeRefillPriceCoins} coins',
                icon: Icons.favorite_rounded,
                color: v.red,
                expanded: true,
                enabled: canBuyLife,
                onPressed: canBuyLife
                    ? () => _showShopBoolResult(
                          ref,
                          context,
                          purchase: onBuyLife,
                          successMessage: 'Life purchased!',
                        )
                    : null,
              ),
              AppSpacing.vGapSM,
              _ShopPillButton(
                label: router.isLifeAdDailyCapReached
                    ? 'Daily life ads used (3/3)'
                    : 'Watch ad for 1 life',
                icon: Icons.play_circle_outline_rounded,
                color: v.green,
                expanded: true,
                enabled: canWatchLifeAd,
                onPressed: canWatchLifeAd
                    ? () async {
                        final ok = await onWatchAdForLife();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Life granted!'
                                  : RewardedAdMessages.shopLifeFailure(
                                      livesFull: snapshot.isFull,
                                      dailyCapReached:
                                          router.isLifeAdDailyCapReached,
                                    ),
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
        AppSpacing.vGapLG,
        _SectionLabel(
          title: 'EARN COINS',
          icon: Icons.monetization_on_rounded,
          color: v.gold,
        ),
        AppSpacing.vGapSM,
        _DailyClaimCard(
          ref: ref,
          purchaseInFlight: purchaseInFlight,
          lastDailyClaimAt: lastDailyClaimAt,
          onClaim: onClaimDaily,
          onDevReset: onDevResetDaily,
        ),
        AppSpacing.vGapSM,
        _PerkCard(
          title: 'Watch ad for coins',
          description: coinCooldown != null
              ? 'Available in ${RewardedAdRules.formatCooldown(coinCooldown)}.'
              : 'Watch a short ad and earn +${RewardedAdRules.rewardedCoinGrant} coins.',
          icon: Icons.play_circle_outline_rounded,
          color: v.playerB,
          actionLabel: '+COINS',
          enabled: canWatchCoinAd,
          onAction: canWatchCoinAd
              ? () async {
                  final ok = await onWatchAdForCoins();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Reward granted (+${RewardedAdRules.rewardedCoinGrant} coins)!'
                            : RewardedAdMessages.shopCoinsFailure(
                                lastRewardedAdAt: lastRewardedAdAt,
                              ),
                      ),
                    ),
                  );
                }
              : null,
        ),
        AppSpacing.vGapLG,
        _SectionLabel(
          title: 'PREMIUM',
          icon: Icons.block_rounded,
          color: v.playerA,
        ),
        AppSpacing.vGapSM,
        _RemoveAdsSection(
          removeAds: removeAds,
          priceLabel: removeAdsPrice,
          onPurchase: onPurchaseRemoveAds,
          onRestore: onRestorePurchases,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        AppSpacing.hGapXS,
        Text(
          title,
          style: t.scoreLabel.copyWith(
            fontSize: 12,
            letterSpacing: 1.6,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DailyClaimCard extends StatefulWidget {
  const _DailyClaimCard({
    required this.ref,
    required this.purchaseInFlight,
    required this.lastDailyClaimAt,
    required this.onClaim,
    this.onDevReset,
  });

  final WidgetRef ref;
  final bool purchaseInFlight;
  final DateTime? lastDailyClaimAt;
  final Future<bool> Function() onClaim;
  final Future<bool> Function()? onDevReset;

  @override
  State<_DailyClaimCard> createState() => _DailyClaimCardState();
}

class _DailyClaimCardState extends State<_DailyClaimCard> {
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  bool get _canClaim => _isDailyClaimAvailable(widget.lastDailyClaimAt);

  Duration get _cooldown =>
      _dailyClaimCooldownRemaining(widget.lastDailyClaimAt);

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final canClaim = _canClaim && !widget.purchaseInFlight;
    final description = canClaim
        ? 'Free coins and XP once per day.'
        : 'Next claim in ${_formatDailyCooldown(_cooldown)}.';

    return GestureDetector(
      onLongPress: widget.onDevReset == null
          ? null
          : () async {
              final ok = await widget.onDevReset!();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Daily reset (dev) — you can claim again.'
                        : 'Dev reset failed. Deploy devResetDailyClaim function.',
                  ),
                ),
              );
            },
      child: _PerkCard(
        title: 'Claim Daily',
        description: description,
        icon: Icons.calendar_month_rounded,
        color: v.green,
        actionLabel: canClaim ? 'CLAIM' : 'CLAIMED',
        enabled: canClaim,
        onAction: canClaim
            ? () => _showShopBoolResult(
                  widget.ref,
                  context,
                  purchase: widget.onClaim,
                  successMessage: 'Daily claimed! (+60 coins · +40 XP)',
                  failureMessage: 'Daily already claimed.',
                )
            : null,
      ),
    );
  }
}

class _PerkCard extends StatelessWidget {
  const _PerkCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.onAction,
    this.enabled = true,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return NeonCard(
      glowColor: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          AppSpacing.hGapMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: t.playerName.copyWith(color: color, fontSize: 13),
                ),
                AppSpacing.vGapXS,
                Text(description, style: t.bodySmall),
              ],
            ),
          ),
          _ShopPillButton(
            label: actionLabel,
            color: color,
            enabled: enabled,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.canAfford,
    required this.onBuy,
    required this.onEquip,
  });

  final CatalogItem item;
  final bool owned;
  final bool equipped;
  final bool canAfford;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final accent = _catalogAccent(item, v);
    final showBuy = !owned && !equipped;
    final buyEnabled = showBuy && canAfford;
    final buttonColor = buyEnabled ? accent : v.textDisabled;

    return NeonCard(
      glowColor: accent.withValues(alpha: 0.10),
      borderColor: equipped ? accent : v.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name.toUpperCase(),
            style: t.playerName.copyWith(
              color: accent,
              fontSize: 13,
              letterSpacing: 1.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.vGapXS,
          Text(
            item.rarity.toUpperCase(),
            style: t.bodySmall,
          ),
          if (item.type == CatalogItemType.theme) ...[
            AppSpacing.vGapXS,
            _ThemeSwatches(item: item),
          ],
          if (item.type == CatalogItemType.avatar ||
              item.type == CatalogItemType.initialSkin) ...[
            AppSpacing.vGapSM,
            _CosmeticPreview(item: item),
          ],
          const Spacer(),
          if (!owned)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.monetization_on_rounded,
                    color: canAfford ? v.gold : v.red,
                    size: 16,
                  ),
                  AppSpacing.hGapXS,
                  Text(
                    '${item.priceCoins}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: canAfford ? v.textPrimary : v.red,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: equipped || owned ? accent : buttonColor,
                foregroundColor: v.onAccent,
                disabledBackgroundColor: v.textDisabled.withValues(alpha: 0.35),
                disabledForegroundColor: v.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
              onPressed: equipped
                  ? null
                  : (owned ? onEquip : (buyEnabled ? onBuy : null)),
              child: Text(
                equipped ? 'EQUIPPED' : (owned ? 'USE' : 'BUY'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _catalogAccent(CatalogItem item, DotClashVisuals v) {
  switch (item.type) {
    case CatalogItemType.theme:
      return item.previewPrimary != null ? Color(item.previewPrimary!) : v.gold;
    case CatalogItemType.avatar:
      return EquippedAvatar.accentForAvatarId(item.id, v);
    case CatalogItemType.initialSkin:
      return v.playerA;
    case CatalogItemType.bundle:
      return v.gold;
  }
}

class _CosmeticPreview extends StatelessWidget {
  const _CosmeticPreview({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    if (item.type == CatalogItemType.avatar) {
      return EquippedAvatar(
        avatarId: item.id,
        fallbackInitial: 'A',
        size: 42,
        showInitial: false,
      );
    }

    final accent =
        EquippedAvatar.accentForAvatarId('avatar_orb_cyan', context.dc);
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const EquippedAvatar(
            avatarId: 'avatar_orb_cyan',
            fallbackInitial: 'A',
            size: 42,
            showInitial: false,
          ),
          Text(
            'A',
            style: InitialSkinStyles.letterStyle(
              skinId: item.id,
              fontSize: 16,
              accent: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSwatches extends StatelessWidget {
  const _ThemeSwatches({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final primary =
        item.previewPrimary == null ? v.playerA : Color(item.previewPrimary!);
    final secondary = item.previewSecondary == null
        ? v.playerB
        : Color(item.previewSecondary!);
    return Row(
      children: [
        _SwatchDot(color: primary),
        AppSpacing.hGapXS,
        _SwatchDot(color: secondary),
      ],
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
    );
  }
}

class _RemoveAdsSection extends StatelessWidget {
  const _RemoveAdsSection({
    required this.removeAds,
    required this.priceLabel,
    required this.onPurchase,
    required this.onRestore,
  });

  final bool removeAds;
  final String? priceLabel;
  final Future<(bool ok, String? error)> Function() onPurchase;
  final Future<bool> Function() onRestore;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final accent = v.gold;
    final price = priceLabel ?? '…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeonCard(
          glowColor: accent.withValues(alpha: 0.18),
          borderColor: removeAds ? v.green : accent.withValues(alpha: 0.55),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RemoveAdsBadge(accent: accent, purchased: removeAds),
              AppSpacing.hGapMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REMOVE ADS',
                      style: t.playerName.copyWith(
                        color: accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    AppSpacing.vGapXS,
                    Text(
                      removeAds
                          ? 'Interstitials removed. Thank you for supporting '
                              'Dot Clash!'
                          : 'Enjoy an ad-free experience and support Dot Clash!',
                      style: t.bodySmall.copyWith(
                        color: v.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.hGapSM,
              if (removeAds)
                Icon(Icons.check_circle_rounded, color: v.green, size: 28)
              else
                _RemoveAdsPriceButton(
                  price: price,
                  onPressed: () async {
                    final result = await onPurchase();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.$1
                              ? 'Remove Ads unlocked!'
                              : (result.$2?.trim().isNotEmpty == true
                                  ? result.$2!.trim()
                                  : 'Purchase was not completed.'),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        if (!removeAds) ...[
          AppSpacing.vGapSM,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final ok = await onRestore();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Purchases restored.'
                          : 'No Remove Ads purchase found.',
                    ),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Restore Purchases',
                    style: t.bodySmall.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: accent),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RemoveAdsBadge extends StatelessWidget {
  const _RemoveAdsBadge({
    required this.accent,
    required this.purchased,
  });

  final Color accent;
  final bool purchased;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (v.useGlow && !purchased) ...[
            Positioned(
              top: -2,
              right: -2,
              child: Icon(
                Icons.auto_awesome,
                size: 12,
                color: accent.withValues(alpha: 0.9),
              ),
            ),
            Positioned(
              bottom: 0,
              left: -4,
              child: Icon(
                Icons.auto_awesome,
                size: 9,
                color: accent.withValues(alpha: 0.65),
              ),
            ),
          ],
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppSpacing.roundedMD,
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              boxShadow: v.useGlow
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block_rounded,
                  color: accent,
                  size: 22,
                ),
                Text(
                  'ADS',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoveAdsPriceButton extends StatelessWidget {
  const _RemoveAdsPriceButton({
    required this.price,
    required this.onPressed,
  });

  final String price;
  final VoidCallback onPressed;

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE082), Color(0xFFC8922A)],
  );

  @override
  Widget build(BuildContext context) {
    final v = context.dc;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppSpacing.roundedMD,
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: _gradient,
            borderRadius: AppSpacing.roundedMD,
            boxShadow: v.useGlow
                ? [
                    BoxShadow(
                      color: v.gold.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            price,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2A1800),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
