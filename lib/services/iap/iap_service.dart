import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/env/app_env.dart';
import '../../features/profile/providers/profile_providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final iapServiceProvider = Provider<IapService>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  final svc = IapService(verifyRemoveAds: repo.verifyRemoveAdsPurchase);
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

typedef VerifyRemoveAds = Future<bool> Function({
  required String platform,
  required String productId,
  String? packageName,
  String? purchaseToken,
  String? verificationData,
  String? localVerificationData,
});

class IapService {
  IapService({required VerifyRemoveAds verifyRemoveAds})
      : _verifyRemoveAds = verifyRemoveAds {
    _init();
  }

  final VerifyRemoveAds _verifyRemoveAds;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = [];
  Completer<bool>? _pendingPurchase;
  Completer<bool>? _pendingRestore;
  String? _lastPurchaseError;

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
    for (final p in _products) {
      debugPrint(
        '[IAP] ${p.id} price=${p.price} raw=${p.rawPrice} currency=${p.currencyCode}',
      );
    }
  }

  String? get lastPurchaseError => _lastPurchaseError;

  /// Starts Remove Ads purchase. Completes when the store confirms or fails.
  Future<bool> purchaseRemoveAds() async {
    _lastPurchaseError = null;
    await ensureProductsLoaded();
    final product = removeAdsProduct;
    if (product == null) {
      _lastPurchaseError = 'Store product not available.';
      debugPrint('[IAP] removeAds product not loaded');
      return false;
    }

    if (_pendingPurchase != null) {
      if (!_pendingPurchase!.isCompleted) {
        return _pendingPurchase!.future;
      }
      _pendingPurchase = null;
    }
    _pendingPurchase = Completer<bool>();

    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _lastPurchaseError = 'Could not open the store purchase sheet.';
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
            final ok = await _verifyPurchaseWithBackend(purchase);
            _finishPendingPurchase(ok);
            _finishPendingRestore(ok);
          }
          break;
        case PurchaseStatus.error:
          debugPrint('[IAP] purchase error: ${purchase.error}');
          if (isRemoveAds) {
            _lastPurchaseError ??=
                purchase.error?.message ?? 'Store purchase failed.';
            _finishPendingPurchase(false);
            _finishPendingRestore(false);
          }
          break;
        case PurchaseStatus.canceled:
          if (isRemoveAds) {
            _lastPurchaseError ??= 'Purchase canceled.';
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

  Future<bool> _verifyPurchaseWithBackend(PurchaseDetails purchase) async {
    if (kIsWeb) return false;

    final platform = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
            ? 'android'
            : null;
    if (platform == null) return false;

    try {
      return await _verifyRemoveAds(
        platform: platform,
        productId: purchase.productID,
        packageName: Platform.isAndroid ? AppEnv.androidPackageName : null,
        purchaseToken: Platform.isAndroid
            ? purchase.verificationData.serverVerificationData
            : null,
        verificationData: purchase.verificationData.serverVerificationData,
        localVerificationData: purchase.verificationData.localVerificationData,
      );
    } on FirebaseFunctionsException catch (e) {
      _lastPurchaseError = e.message ?? e.code;
      debugPrint('[IAP] verifyRemoveAdsPurchase: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      _lastPurchaseError = 'Could not verify purchase with the server.';
      debugPrint('[IAP] verifyRemoveAdsPurchase error: $e');
      return false;
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
