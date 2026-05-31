import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/env/app_env.dart';
import '../../features/profile/providers/profile_providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final iapServiceProvider = Provider<IapService>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  final svc = IapService(grantRemoveAds: repo.grantRemoveAds);
  ref.onDispose(svc.dispose);
  return svc;
});

/// Store listing for Remove Ads (price label from Play / App Store).
final removeAdsProductProvider = FutureProvider<ProductDetails?>((ref) async {
  final svc = ref.watch(iapServiceProvider);
  await svc.ensureProductsLoaded();
  return svc.removeAdsProduct;
});

// ── IapService ─────────────────────────────────────────────────────────────────

typedef GrantRemoveAds = Future<bool> Function();

class IapService {
  IapService({required GrantRemoveAds grantRemoveAds})
      : _grantRemoveAds = grantRemoveAds {
    _init();
  }

  final GrantRemoveAds _grantRemoveAds;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = [];
  Completer<bool>? _pendingPurchase;
  Completer<bool>? _pendingRestore;

  List<ProductDetails> get products => List.unmodifiable(_products);

  ProductDetails? get removeAdsProduct =>
      _products.where((p) => p.id == AppEnv.iapRemoveAds).firstOrNull;

  Future<void> ensureProductsLoaded() async {
    if (_products.isNotEmpty) return;
    final available = await _iap.isAvailable();
    if (!available) return;
    await _loadProducts();
  }

  Future<void> _init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[IAP] Store not available');
      return;
    }

    _sub = _iap.purchaseStream.listen(
      _handlePurchases,
      onError: (e) => debugPrint('[IAP] Stream error: $e'),
    );

    await _loadProducts();
    await _iap.restorePurchases();
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(
      {AppEnv.iapRemoveAds, AppEnv.iapCosmeticPack},
    );

    if (response.error != null) {
      debugPrint('[IAP] Product load error: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[IAP] Products not found: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
  }

  /// Starts Remove Ads purchase. Completes when the store confirms or fails.
  Future<bool> purchaseRemoveAds() async {
    await ensureProductsLoaded();
    final product = removeAdsProduct;
    if (product == null) {
      debugPrint('[IAP] removeAds product not loaded');
      return false;
    }

    if (_pendingPurchase != null) {
      return _pendingPurchase!.future;
    }
    _pendingPurchase = Completer<bool>();

    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _finishPendingPurchase(false);
        return false;
      }
      return await _pendingPurchase!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _finishPendingPurchase(false);
          return false;
        },
      );
    } catch (e) {
      debugPrint('[IAP] purchaseRemoveAds error: $e');
      _finishPendingPurchase(false);
      return false;
    }
  }

  /// Restores prior non-consumable purchases and syncs Firestore [removeAds].
  Future<bool> restorePurchases() async {
    final available = await _iap.isAvailable();
    if (!available) return false;

    if (_pendingRestore != null) {
      return _pendingRestore!.future;
    }
    _pendingRestore = Completer<bool>();

    try {
      await _iap.restorePurchases();
      return await _pendingRestore!.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          _finishPendingRestore(false);
          return false;
        },
      );
    } catch (e) {
      debugPrint('[IAP] restorePurchases error: $e');
      _finishPendingRestore(false);
      return false;
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final isRemoveAds = purchase.productID == AppEnv.iapRemoveAds;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (isRemoveAds) {
            final ok = await _grantRemoveAds();
            _finishPendingPurchase(ok);
            _finishPendingRestore(ok);
          }
          break;
        case PurchaseStatus.error:
          debugPrint('[IAP] purchase error: ${purchase.error}');
          if (isRemoveAds) {
            _finishPendingPurchase(false);
            _finishPendingRestore(false);
          }
          break;
        case PurchaseStatus.canceled:
          if (isRemoveAds) {
            _finishPendingPurchase(false);
            _finishPendingRestore(false);
          }
          break;
        case PurchaseStatus.pending:
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void _finishPendingPurchase(bool value) {
    if (_pendingPurchase != null && !_pendingPurchase!.isCompleted) {
      _pendingPurchase!.complete(value);
    }
    _pendingPurchase = null;
  }

  void _finishPendingRestore(bool value) {
    if (_pendingRestore != null && !_pendingRestore!.isCompleted) {
      _pendingRestore!.complete(value);
    }
    _pendingRestore = null;
  }

  void dispose() {
    _sub?.cancel();
    _finishPendingPurchase(false);
    _finishPendingRestore(false);
  }
}
