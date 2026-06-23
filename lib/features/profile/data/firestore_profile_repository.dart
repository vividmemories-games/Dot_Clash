import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/env/app_env.dart';
import '../../../services/analytics/analytics_service.dart';
import '../../../services/backend/callable_backend.dart';
import '../../powerups/domain/power_up.dart';
import '../../powerups/domain/power_up_catalog.dart';
import 'profile_repository.dart';
import '../domain/lives_logic.dart';
import '../domain/progression.dart';
import '../domain/rank.dart';
import '../domain/user_profile.dart';

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({
    required this.uid,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;
  UserProfile? _latestProfile;
  final _controller = StreamController<UserProfile>.broadcast();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _remoteSub;
  bool _startedSync = false;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('profiles').doc(uid);

  CollectionReference<Map<String, dynamic>> get _matches =>
      _doc.collection('matches');

  @override
  Stream<UserProfile> watchProfile() async* {
    if (!_startedSync) {
      _startedSync = true;
      final initial = await _ensureExists();
      _emit(initial);
      _remoteSub = _doc.snapshots().listen(
        (snap) {
          // Skip locally-cached snapshots so a stale cache frame never
          // overwrites a server-fresh emit (e.g. after a callable write).
          if (snap.metadata.isFromCache) return;
          final data = snap.data();
          if (data == null) return;
          _emit(_fromMap(uid, data));
        },
        onError: (_) {
          // Keep the stream alive during transient Firestore outages.
        },
      );
    }

    if (_latestProfile != null) {
      yield _latestProfile!;
    }
    yield* _controller.stream;
  }

  @override
  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    await _update({
      'displayName': trimmed.isEmpty ? 'Player' : trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> equipTheme(String themeId) async {
    await _update({
      'themeId': themeId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> equipAvatar(String avatarId) async {
    await _update({
      'avatarId': avatarId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> equipInitialSkin(String skinId) async {
    await _update({
      'initialSkinId': skinId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> verifyRemoveAdsPurchase({
    required String platform,
    required String productId,
    String? packageName,
    String? purchaseToken,
    String? verificationData,
    String? localVerificationData,
  }) async {
    final profile = await _loadProfileBestEffort();
    if (profile.removeAds) return true;

    final result = await _tryCallableWithResult(
      'verifyRemoveAdsPurchase',
      {
        'platform': platform,
        'productId': productId,
        if (packageName != null) 'packageName': packageName,
        if (purchaseToken != null) 'purchaseToken': purchaseToken,
        if (verificationData != null) 'verificationData': verificationData,
        if (localVerificationData != null)
          'localVerificationData': localVerificationData,
      },
    );
    if (result != null && result['success'] == true) {
      await _refreshProfileFromServer();
      return true;
    }
    if (_allowEconomyLocalFallback) {
      return _grantRemoveAdsLocal();
    }
    return false;
  }

  @override
  Future<bool> grantRemoveAds() async {
    if (!AppEnv.isDev) {
      debugPrint(
        '[IAP] grantRemoveAds() is dev-only; purchases must use verifyRemoveAdsPurchase.',
      );
      return false;
    }
    return _grantRemoveAdsLocal();
  }

  Future<bool> _grantRemoveAdsLocal() async {
    await _ensureExists();
    final profile = await _loadProfileBestEffort();
    if (profile.removeAds) return true;
    await _update({
      'removeAds': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  @override
  Future<bool> purchaseTheme(String themeId, int priceCoins) async {
    return _economyBool(
      'purchaseCosmetic',
      {'itemId': themeId},
      optimistic: (p) => _predictCosmeticPurchase(
        p,
        itemId: themeId,
        priceCoins: priceCoins,
        owned: p.ownedThemeIds,
        equipOnly: () => p.copyWith(themeId: themeId),
        buyAndEquip: () => p.copyWith(
          coins: p.coins - priceCoins,
          ownedThemeIds: [...p.ownedThemeIds, themeId],
          themeId: themeId,
        ),
      ),
      devFallback: () => _purchase(
        ownedKey: 'ownedThemeIds',
        equipKey: 'themeId',
        itemId: themeId,
        priceCoins: priceCoins,
      ),
    );
  }

  @override
  Future<bool> purchaseAvatar(String avatarId, int priceCoins) async {
    return _economyBool(
      'purchaseCosmetic',
      {'itemId': avatarId},
      optimistic: (p) => _predictCosmeticPurchase(
        p,
        itemId: avatarId,
        priceCoins: priceCoins,
        owned: p.ownedAvatarIds,
        equipOnly: () => p.copyWith(avatarId: avatarId),
        buyAndEquip: () => p.copyWith(
          coins: p.coins - priceCoins,
          ownedAvatarIds: [...p.ownedAvatarIds, avatarId],
          avatarId: avatarId,
        ),
      ),
      devFallback: () => _purchase(
        ownedKey: 'ownedAvatarIds',
        equipKey: 'avatarId',
        itemId: avatarId,
        priceCoins: priceCoins,
      ),
    );
  }

  @override
  Future<bool> purchaseInitialSkin(String skinId, int priceCoins) async {
    return _economyBool(
      'purchaseCosmetic',
      {'itemId': skinId},
      optimistic: (p) => _predictCosmeticPurchase(
        p,
        itemId: skinId,
        priceCoins: priceCoins,
        owned: p.ownedInitialSkinIds,
        equipOnly: () => p.copyWith(initialSkinId: skinId),
        buyAndEquip: () => p.copyWith(
          coins: p.coins - priceCoins,
          ownedInitialSkinIds: [...p.ownedInitialSkinIds, skinId],
          initialSkinId: skinId,
        ),
      ),
      devFallback: () => _purchase(
        ownedKey: 'ownedInitialSkinIds',
        equipKey: 'initialSkinId',
        itemId: skinId,
        priceCoins: priceCoins,
      ),
    );
  }

  @override
  Future<bool> purchaseLife() async {
    return _economyBool(
      'purchaseLife',
      const {},
      devFallback: () => _guardBoolTransaction('purchaseLife', () async {
        await _ensureExists();
        return _firestore.runTransaction<bool>((txn) async {
          final snap = await txn.get(_doc);
          final profile = _fromMap(uid, snap.data() ?? _defaultProfileMap(uid));
          final now = DateTime.now();
          final resolved = LivesLogic.resolve(
            lives: profile.lives,
            nextLifeAt: profile.nextLifeAt,
            now: now,
          );
          if (resolved.effectiveLives >= Progression.maxLives) return false;
          if (profile.coins < Progression.lifeRefillPriceCoins) return false;

          final purchased = LivesLogic.onPurchase(
            lives: resolved.effectiveLives,
            nextLifeAt: resolved.nextLifeAt,
            now: now,
          );
          txn.update(_doc, {
            'coins': profile.coins - Progression.lifeRefillPriceCoins,
            'lives': purchased.lives,
            'nextLifeAt': purchased.nextLifeAt == null
                ? null
                : Timestamp.fromDate(purchased.nextLifeAt!),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        });
      }),
    );
  }

  @override
  Future<bool> claimDaily() async {
    return _economyBool(
      'claimDailyReward',
      const {},
      optimistic: _predictDailyClaim,
      devFallback: () => _guardBoolTransaction('claimDaily', () async {
        await _ensureExists();
        return _firestore.runTransaction<bool>((txn) async {
          final snap = await txn.get(_doc);
          final profile = _fromMap(uid, snap.data() ?? _defaultProfileMap(uid));
          final now = DateTime.now();
          final last = profile.lastDailyClaimAt;
          if (last != null &&
              now.difference(last) < const Duration(hours: 24)) {
            return false;
          }
          final boost = PowerUpCatalog.todayDailyBoost(now.toUtc());
          final inv = Map<String, int>.from(profile.powerUpInventory);
          inv[boost.id] =
              (inv[boost.id] ?? 0) + PowerUpCatalog.dailyBoostQuantity;
          final newXp = profile.xp + 40;
          txn.update(_doc, {
            'coins': profile.coins + 60,
            'xp': newXp,
            'level': Progression.levelForXp(newXp),
            'powerUpInventory': inv,
            'lastDailyClaimAt': Timestamp.fromDate(now),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        });
      }),
    );
  }

  @override
  Future<bool> devResetDailyClaim() async {
    if (!AppEnv.isDev) return false;
    final result = await _tryCallableWithResult('devResetDailyClaim', const {});
    if (result != null && result['success'] == true) {
      if (_latestProfile != null) {
        _emit(_latestProfile!.copyWith(clearLastDailyClaimAt: true));
      }
      unawaited(_refreshProfileFromServer());
      return true;
    }
    return false;
  }

  @override
  Future<bool> claimRewardedAd() async {
    return _economyBool(
      'claimRewardedAd',
      const {},
      devFallback: () => _guardBoolTransaction('claimRewardedAd', () async {
        await _ensureExists();
        return _firestore.runTransaction<bool>((txn) async {
          final snap = await txn.get(_doc);
          final profile = _fromMap(uid, snap.data() ?? _defaultProfileMap(uid));
          final now = DateTime.now();
          final last = profile.lastRewardedAdAt;
          if (last != null &&
              now.difference(last) < const Duration(minutes: 30)) {
            return false;
          }
          txn.update(_doc, {
            'coins': profile.coins + 35,
            'lastRewardedAdAt': Timestamp.fromDate(now),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        });
      }),
    );
  }

  @override
  Future<bool> grantLifeFromAd() async {
    return _economyBool(
      'grantLifeFromAd',
      const {},
      devFallback: _grantFreeLifeLocal,
    );
  }

  @override
  Future<bool> refundLastCampaignLife() async {
    return _economyBool(
      'grantLifeFromAd',
      const {},
      devFallback: _grantFreeLifeLocal,
    );
  }

  Future<bool> _grantFreeLifeLocal() async {
    return _guardBoolTransaction('grantFreeLife', () async {
      await _ensureExists();
      return _firestore.runTransaction<bool>((txn) async {
        final snap = await txn.get(_doc);
        final profile = _fromMap(uid, snap.data() ?? _defaultProfileMap(uid));
        final now = DateTime.now();
        final resolved = LivesLogic.resolve(
          lives: profile.lives,
          nextLifeAt: profile.nextLifeAt,
          now: now,
        );
        if (resolved.effectiveLives >= Progression.maxLives) return false;
        final updated = LivesLogic.onPurchase(
          lives: resolved.effectiveLives,
          nextLifeAt: resolved.nextLifeAt,
          now: now,
        );
        txn.update(_doc, {
          'lives': updated.lives,
          'nextLifeAt': updated.nextLifeAt == null
              ? null
              : Timestamp.fromDate(updated.nextLifeAt!),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    });
  }

  @override
  Future<bool> purchasePowerUp(
    String powerUpId,
    int priceCoins, {
    int quantity = 1,
  }) async {
    return _economyBool(
      'purchasePowerUp',
      {'powerUpId': powerUpId, 'quantity': quantity},
      optimistic: (p) =>
          _predictPowerUpPurchase(p, powerUpId, priceCoins, quantity),
      devFallback: () => _guardBoolTransaction('purchasePowerUp', () async {
        await _ensureExists();
        return _firestore.runTransaction<bool>((txn) async {
          final snap = await txn.get(_doc);
          final profile = _fromMap(uid, snap.data() ?? _defaultProfileMap(uid));
          if (profile.coins < priceCoins) return false;
          final inv = Map<String, int>.from(profile.powerUpInventory);
          inv[powerUpId] = (inv[powerUpId] ?? 0) + quantity;
          txn.update(_doc, {
            'coins': profile.coins - priceCoins,
            'powerUpInventory': inv,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        });
      }),
    );
  }

  @override
  Future<bool> consumePowerUp(String powerUpId, {int quantity = 1}) async {
    return _economyBool(
      'consumePowerUp',
      {'powerUpId': powerUpId, 'quantity': quantity},
      devFallback: () => _guardBoolTransaction('consumePowerUp', () async {
        await _ensureExists();
        return _firestore.runTransaction<bool>((txn) async {
          final snap = await txn.get(_doc);
          final profile = _fromMap(uid, snap.data() ?? _defaultProfileMap(uid));
          final current = profile.powerUpInventory[powerUpId] ?? 0;
          if (current < quantity) return false;
          final inv = Map<String, int>.from(profile.powerUpInventory);
          final left = current - quantity;
          if (left <= 0) {
            inv.remove(powerUpId);
          } else {
            inv[powerUpId] = left;
          }
          txn.update(_doc, {
            'powerUpInventory': inv,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        });
      }),
    );
  }

  @override
  Future<void> grantPowerUp(String powerUpId, int quantity) async {
    final result = await _tryCallableWithResult(
      'grantPowerUp',
      {'powerUpId': powerUpId, 'quantity': quantity},
    );
    if (result != null && result['success'] == true) {
      await _refreshProfileFromServer();
      return;
    }
    if (!_allowEconomyLocalFallback) return;

    await _ensureExists();
    await _firestore.runTransaction<void>((txn) async {
      final snap = await txn.get(_doc);
      final profile = _fromMap(uid, snap.data() ?? _defaultProfileMap(uid));
      final inv = Map<String, int>.from(profile.powerUpInventory);
      inv[powerUpId] = (inv[powerUpId] ?? 0) + quantity;
      txn.update(_doc, {
        'powerUpInventory': inv,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> syncLives() async {
    await _ensureExists();
    final profile = await _loadProfileBestEffort();
    final now = DateTime.now();
    final resolved = LivesLogic.resolve(
      lives: profile.lives,
      nextLifeAt: profile.nextLifeAt,
      now: now,
    );
    if (resolved.effectiveLives == profile.lives &&
        resolved.nextLifeAt == profile.nextLifeAt) {
      return;
    }

    final result = await _tryCallableWithResult('syncLives', const {});
    if (result != null && result['success'] == true) {
      await _refreshProfileFromServer();
      return;
    }

    // Local UI only — Firestore rules block client writes to lives.
    _emit(
      profile.copyWith(
        lives: resolved.effectiveLives,
        nextLifeAt: resolved.nextLifeAt,
      ),
    );
  }

  @override
  Future<void> settleMatch(
    MatchResult result, {
    bool consumeLife = false,
  }) async {
    final outcome = switch (result) {
      MatchResult.win => 'win',
      MatchResult.loss => 'loss',
      MatchResult.tie => 'tie',
    };
    final usedCallable = await _tryCallable(
      'settleQuickMatch',
      {'outcome': outcome, 'consumeLife': consumeLife},
    );
    if (usedCallable) {
      await _refreshProfileFromServer();
      return;
    }
    if (!_allowEconomyLocalFallback) return;

    await _ensureExists();
    final profile = await _loadProfileBestEffort();
    final now = DateTime.now();
    final resolvedLives = LivesLogic.resolve(
      lives: profile.lives,
      nextLifeAt: profile.nextLifeAt,
      now: now,
    );

    final win = result == MatchResult.win;
    final tie = result == MatchResult.tie;

    final deltaCoins = Progression.coinsForMatch(win: win, tie: tie);
    final deltaXp = Progression.xpForMatch(win: win, tie: tie);
    final newXp = profile.xp + deltaXp;

    final newWins = profile.wins + (win ? 1 : 0);
    final newLosses = profile.losses + (result == MatchResult.loss ? 1 : 0);
    final newTies = profile.ties + (tie ? 1 : 0);
    final newGames = profile.gamesPlayed + 1;

    final newStreak =
        win ? profile.winStreak + 1 : (tie ? profile.winStreak : 0);
    final bestStreak =
        newStreak > profile.bestWinStreak ? newStreak : profile.bestWinStreak;

    var newRating = profile.rating;
    if (win) newRating += 18;
    if (tie) newRating += 2;
    if (!win && !tie) newRating -= 18;
    if (newRating < 800) newRating = 800;
    final seasonBest = newRating > profile.seasonBestRating
        ? newRating
        : profile.seasonBestRating;

    var updatedLives = resolvedLives.effectiveLives;
    var updatedNextLifeAt = resolvedLives.nextLifeAt;
    if (consumeLife && result == MatchResult.loss) {
      final afterLoss = LivesLogic.onLoss(
        lives: updatedLives,
        nextLifeAt: updatedNextLifeAt,
        now: now,
      );
      updatedLives = afterLoss.lives;
      updatedNextLifeAt = afterLoss.nextLifeAt;
    }

    final missions = profile.dailyMissions.forToday().copyWithBump(
          win: win,
          gamePlayed: true,
          boxesCaptured: 0,
        );

    final updated = profile.copyWith(
      coins: profile.coins + deltaCoins,
      xp: newXp,
      wins: newWins,
      dailyMissions: missions,
      losses: newLosses,
      ties: newTies,
      gamesPlayed: newGames,
      winStreak: newStreak,
      bestWinStreak: bestStreak,
      rating: newRating,
      seasonBestRating: seasonBest,
      seasonWins: profile.seasonWins + (win ? 1 : 0),
      seasonLosses: profile.seasonLosses + (result == MatchResult.loss ? 1 : 0),
      seasonTies: profile.seasonTies + (tie ? 1 : 0),
      lives: updatedLives,
      nextLifeAt: updatedNextLifeAt,
    );
    _emit(updated);

    await _withRetry(() => _doc.set({
          ..._toMap(updated),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));
  }

  @override
  Future<void> settleCampaignLevel({
    required String levelId,
    required int starsEarned,
    required int coinReward,
    required int xpReward,
    bool consumeLife = true,
    bool win = true,
    int boxesCaptured = 0,
    Map<String, int> powerUpRewards = const {},
  }) async {
    final callableResult = await _tryCallableWithResult(
      'completeCampaignLevel',
      {
        'levelId': levelId,
        'starsEarned': starsEarned,
        'win': win,
        'boxesCaptured': boxesCaptured,
      },
    );
    if (callableResult != null) {
      final serverCoins =
          (callableResult['coinReward'] as num?)?.toInt() ?? coinReward;
      final serverXp =
          (callableResult['xpReward'] as num?)?.toInt() ?? xpReward;
      final current = await _loadProfileBestEffort();
      _emit(_profileAfterCampaignSettlement(
        current,
        levelId: levelId,
        starsEarned: starsEarned,
        coinReward: serverCoins,
        xpReward: serverXp,
        consumeLife: consumeLife,
        win: win,
        boxesCaptured: boxesCaptured,
        powerUpRewards: powerUpRewards,
      ));
      unawaited(_refreshProfileFromServer());
      return;
    }

    if (!_allowEconomyLocalFallback) {
      debugPrint(
        '[Campaign][settle] Callable failed — progress not saved (prod).',
      );
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[Campaign][settle] Callable unavailable — saving progress via Firestore (dev).',
      );
    }
    await _settleCampaignLevelLocal(
      levelId: levelId,
      starsEarned: starsEarned,
      coinReward: coinReward,
      xpReward: xpReward,
      consumeLife: consumeLife,
      win: win,
      boxesCaptured: boxesCaptured,
      powerUpRewards: powerUpRewards,
    );
  }

  @override
  Future<void> settleDailyPuzzle({
    required String levelId,
    required bool win,
    int boxesCaptured = 0,
  }) async {
    if (!win) return;

    final usedCallable = await _tryCallable(
      'completeDailyPuzzle',
      {
        'levelId': levelId,
        'win': win,
        'boxesCaptured': boxesCaptured,
      },
    );
    if (usedCallable) {
      await _refreshProfileFromServer();
      return;
    }

    await _settleDailyPuzzleLocal(
      levelId: levelId,
      boxesCaptured: boxesCaptured,
    );
  }

  @override
  Future<bool> claimDailyMission(String missionId) async {
    final result = await _tryCallableWithResult(
      'claimDailyMission',
      {'missionId': missionId},
    );
    if (result != null) {
      await _refreshProfileFromServer();
      return result['success'] == true;
    }
    return _claimDailyMissionLocal(missionId);
  }

  /// Returns true when the callable ran successfully.
  Future<bool> _tryCallable(String name, Map<String, dynamic> data) async {
    final result = await _tryCallableWithResult(name, data);
    return result != null;
  }

  Future<Map<String, dynamic>?> _tryCallableWithResult(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (!CallableBackend.instance.isAvailable) return null;
    try {
      return await CallableBackend.instance.call(name, data);
    } on FirebaseFunctionsException catch (e) {
      if (_callableAllowsLocalFallback(e)) {
        if (kDebugMode) {
          final authUid = FirebaseAuth.instance.currentUser?.uid;
          debugPrint(
            '[Callable] $name failed: code=${e.code} '
            'message=${e.message ?? '(none)'} '
            'details=${e.details} '
            'authUid=${authUid ?? 'null'}',
          );
          if (e.code == 'unauthenticated' && authUid != null) {
            debugPrint(
              '[Callable] Signed in locally but callable rejected the request. '
              'Check App Check debug token (SETUP.md §2f) and redeploy functions.',
            );
          }
        }
        return null;
      }
      rethrow;
    }
  }

  bool get _allowEconomyLocalFallback => AppEnv.isDev;

  bool _callableAllowsLocalFallback(FirebaseFunctionsException e) {
    if (!_allowEconomyLocalFallback) return false;
    if (e.code == 'not-found' ||
        e.code == 'unavailable' ||
        e.code == 'internal' ||
        e.code == 'failed-precondition' ||
        e.code == 'unauthenticated' ||
        e.code == 'permission-denied') {
      return true;
    }
    final msg = e.message ?? '';
    return msg.contains('permission to the requested URL');
  }

  /// Runs an economy callable with an optional [optimistic] local prediction.
  ///
  /// When [optimistic] is supplied and a profile is cached, the predicted
  /// profile is emitted immediately so the UI (coins, inventory, cosmetics)
  /// updates on the next frame instead of waiting for the network round-trip.
  /// The server write is reconciled in the background via [watchProfile]'s
  /// snapshot listener plus a non-blocking refresh. A local guard returning
  /// null (e.g. not enough coins) fails fast with no network call, and a
  /// server rejection rolls the optimistic emit back.
  Future<bool> _economyBool(
    String name,
    Map<String, dynamic> data, {
    required Future<bool> Function() devFallback,
    UserProfile? Function(UserProfile current)? optimistic,
  }) async {
    UserProfile? previous;
    if (optimistic != null && _latestProfile != null) {
      previous = _latestProfile;
      final predicted = optimistic(previous!);
      if (predicted == null) return false;
      _emit(predicted);
    }

    final result = await _tryCallableWithResult(name, data);
    if (result != null) {
      if (result['success'] == true) {
        if (previous != null) {
          // Optimistic emit already updated the UI — reconcile off the hot path.
          unawaited(_refreshProfileFromServer());
        } else {
          await _refreshProfileFromServer();
        }
        return true;
      }
      if (previous != null) _emit(previous);
      return false;
    }
    if (_allowEconomyLocalFallback) {
      final ok = await devFallback();
      if (!ok && previous != null) _emit(previous);
      return ok;
    }
    if (previous != null) _emit(previous);
    return false;
  }

  // ── Optimistic predictors ───────────────────────────────────────────────
  // Each mirrors the corresponding server (and dev-fallback) economy logic so
  // the brief optimistic state matches what streams back from Firestore.

  UserProfile? _predictCosmeticPurchase(
    UserProfile p, {
    required String itemId,
    required int priceCoins,
    required List<String> owned,
    required UserProfile Function() equipOnly,
    required UserProfile Function() buyAndEquip,
  }) {
    if (owned.contains(itemId)) return equipOnly();
    if (p.coins < priceCoins) return null;
    return buyAndEquip();
  }

  UserProfile? _predictPowerUpPurchase(
    UserProfile p,
    String powerUpId,
    int priceCoins,
    int quantity,
  ) {
    if (p.coins < priceCoins) return null;
    return p.copyWith(
      coins: p.coins - priceCoins,
      powerUpInventory: {
        ...p.powerUpInventory,
        powerUpId: (p.powerUpInventory[powerUpId] ?? 0) + quantity,
      },
    );
  }

  UserProfile? _predictDailyClaim(UserProfile p) {
    final now = DateTime.now();
    final last = p.lastDailyClaimAt;
    if (last != null && now.difference(last) < const Duration(hours: 24)) {
      return null;
    }
    final boost = PowerUpCatalog.todayDailyBoost(now.toUtc());
    final inv = Map<String, int>.from(p.powerUpInventory);
    inv[boost.id] = (inv[boost.id] ?? 0) + PowerUpCatalog.dailyBoostQuantity;
    final newXp = p.xp + 40;
    return p.copyWith(
      coins: p.coins + 60,
      xp: newXp,
      level: Progression.levelForXp(newXp),
      powerUpInventory: inv,
      lastDailyClaimAt: now,
    );
  }

  /// Force-reads the profile from Firestore server (bypasses offline cache) and
  /// emits if data is present. Keeps the last optimistic emit on failure.
  Future<void> _refreshProfileFromServer() async {
    try {
      final snap = await _withRetry(
        () => _doc.get(const GetOptions(source: Source.server)),
      );
      final data = snap.data();
      if (data != null) {
        final fresh = _fromMap(uid, data);
        if (kDebugMode) {
          debugPrint(
            '[Profile][refresh] server ok '
            'stars=${fresh.campaignStars.length} '
            'lastLevel=${fresh.lastCampaignLevelId}',
          );
        }
        _emit(fresh);
      }
    } catch (e) {
      debugPrint('[Profile][refresh] server read failed=$e');
      // Keep the last optimistic emit — do not revert.
    }
  }

  /// Returns the optimistic [UserProfile] after applying campaign settlement
  /// rules to [profile]. Mirrors the server-side `completeCampaignLevel` logic.
  UserProfile _profileAfterCampaignSettlement(
    UserProfile profile, {
    required String levelId,
    required int starsEarned,
    required int coinReward,
    required int xpReward,
    required bool consumeLife,
    required bool win,
    required int boxesCaptured,
    Map<String, int> powerUpRewards = const {},
  }) {
    final now = DateTime.now();
    final resolvedLives = LivesLogic.resolve(
      lives: profile.lives,
      nextLifeAt: profile.nextLifeAt,
      now: now,
    );

    final currentBest = profile.campaignStars[levelId] ?? 0;
    final newStars = starsEarned > currentBest
        ? (Map<String, int>.from(profile.campaignStars)
          ..[levelId] = starsEarned)
        : profile.campaignStars;

    final newXp = profile.xp + (win ? xpReward : xpReward ~/ 4);
    final newLevel = Progression.levelForStars(
      Progression.totalStarsFromMap(newStars),
    );

    var newRating = profile.rating;
    if (win) {
      newRating += 12;
    } else {
      newRating -= 8;
    }
    if (newRating < 800) newRating = 800;
    final seasonBest = newRating > profile.seasonBestRating
        ? newRating
        : profile.seasonBestRating;

    var updatedLives = resolvedLives.effectiveLives;
    var updatedNextLifeAt = resolvedLives.nextLifeAt;
    if (consumeLife && !win) {
      final afterLoss = LivesLogic.onLoss(
        lives: updatedLives,
        nextLifeAt: updatedNextLifeAt,
        now: now,
      );
      updatedLives = afterLoss.lives;
      updatedNextLifeAt = afterLoss.nextLifeAt;
    }

    final inv = Map<String, int>.from(profile.powerUpInventory);
    if (win) {
      for (final entry in powerUpRewards.entries) {
        inv[entry.key] = (inv[entry.key] ?? 0) + entry.value;
      }
    }

    return profile.copyWith(
      coins: profile.coins + (win ? coinReward : coinReward ~/ 4),
      xp: newXp,
      level: newLevel,
      gamesPlayed: profile.gamesPlayed + 1,
      wins: profile.wins + (win ? 1 : 0),
      losses: profile.losses + (win ? 0 : 1),
      rating: newRating,
      seasonBestRating: seasonBest,
      seasonWins: profile.seasonWins + (win ? 1 : 0),
      seasonLosses: profile.seasonLosses + (win ? 0 : 1),
      lives: updatedLives,
      nextLifeAt: updatedNextLifeAt,
      campaignStars: newStars,
      lastCampaignLevelId: levelId,
      dailyMissions: profile.dailyMissions.forToday().copyWithBump(
            win: win,
            gamePlayed: true,
            boxesCaptured: boxesCaptured,
          ),
      powerUpInventory: inv,
    );
  }

  Future<void> _settleCampaignLevelLocal({
    required String levelId,
    required int starsEarned,
    required int coinReward,
    required int xpReward,
    required bool consumeLife,
    required bool win,
    required int boxesCaptured,
    Map<String, int> powerUpRewards = const {},
  }) async {
    final profile = await _loadProfileBestEffort();
    final updated = _profileAfterCampaignSettlement(
      profile,
      levelId: levelId,
      starsEarned: starsEarned,
      coinReward: coinReward,
      xpReward: xpReward,
      consumeLife: consumeLife,
      win: win,
      boxesCaptured: boxesCaptured,
      powerUpRewards: powerUpRewards,
    );
    _emit(updated);

    await _withRetry(() => _doc.set({
          ..._toMap(updated),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));
  }

  Future<void> _settleDailyPuzzleLocal({
    required String levelId,
    required int boxesCaptured,
  }) async {
    final profile = await _loadProfileBestEffort();
    final today = DailyMissionProgress.todayUtc();
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final streak = profile.dailyPuzzleDate == yesterdayKey
        ? profile.dailyPuzzleStreak + 1
        : (profile.dailyPuzzleDate == today ? profile.dailyPuzzleStreak : 1);

    final updated = profile.copyWith(
      coins: profile.coins + 50,
      dailyPuzzleDate: today,
      dailyPuzzleLevelId: levelId,
      dailyPuzzleCompleted: true,
      dailyPuzzleStreak: streak,
      dailyMissions: profile.dailyMissions.forToday().copyWithBump(
            win: true,
            gamePlayed: true,
            boxesCaptured: boxesCaptured,
          ),
    );
    _emit(updated);
    await _withRetry(() => _doc.set({
          ..._toMap(updated),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));
  }

  Future<bool> _claimDailyMissionLocal(String missionId) async {
    const targets = <String, ({int target, int coins})>{
      'win_matches': (target: 3, coins: 45),
      'play_games': (target: 4, coins: 60),
      'capture_boxes': (target: 15, coins: 35),
    };
    final spec = targets[missionId];
    if (spec == null) return false;

    final profile = await _loadProfileBestEffort();
    final progress = profile.dailyMissions.forToday();
    if (progress.isClaimed(missionId)) return false;
    if (progress.progressFor(missionId) < spec.target) return false;

    final updated = profile.copyWith(
      coins: profile.coins + spec.coins,
      dailyMissions: progress.withClaimed(missionId),
    );
    _emit(updated);
    await _withRetry(() => _doc.set({
          ..._toMap(updated),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));
    return true;
  }

  @override
  Future<void> recordMatch({
    required MatchResult result,
    required String modeLabel,
    required String opponentLabel,
  }) async {
    final outcome = switch (result) {
      MatchResult.win => 'win',
      MatchResult.loss => 'loss',
      MatchResult.tie => 'tie',
    };
    await _withRetry(() => _matches.add({
          'outcome': outcome,
          'modeLabel': modeLabel,
          'opponentLabel': opponentLabel,
          'playedAt': FieldValue.serverTimestamp(),
        }));
  }

  @override
  Future<void> recordChallengeMatch({
    required String code,
    required MatchResult result,
    required String opponentLabel,
  }) async {
    final normalized = code.trim().toUpperCase();
    final callable = await _tryCallableWithResult(
      'recordChallengeMatch',
      {'code': normalized},
    );
    if (callable != null && callable['success'] == true) {
      await _refreshProfileFromServer();
      return;
    }
    if (!_allowEconomyLocalFallback) return;

    await settleMatch(result, consumeLife: false);
    final outcome = switch (result) {
      MatchResult.win => 'win',
      MatchResult.loss => 'loss',
      MatchResult.tie => 'tie',
    };
    await _withRetry(() => _matches.add({
          'outcome': outcome,
          'modeLabel': 'Challenge',
          'opponentLabel': opponentLabel,
          'challengeCode': normalized,
          'playedAt': FieldValue.serverTimestamp(),
        }));
  }

  @override
  Stream<List<RecentMatchRecord>> watchRecentMatches({int limit = 10}) {
    return _matches
        .orderBy('playedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final outcomeRaw = data['outcome'] as String? ?? 'loss';
              final outcome = switch (outcomeRaw) {
                'win' => MatchResult.win,
                'tie' => MatchResult.tie,
                _ => MatchResult.loss,
              };
              final playedAt = data['playedAt'];
              return RecentMatchRecord(
                id: doc.id,
                outcome: outcome,
                modeLabel: data['modeLabel'] as String? ?? 'Game',
                opponentLabel: data['opponentLabel'] as String? ?? 'Opponent',
                playedAt:
                    playedAt is Timestamp ? playedAt.toDate() : DateTime.now(),
                challengeCode: data['challengeCode'] as String?,
                opponentUid: data['opponentUid'] as String?,
              );
            }).toList());
  }

  Future<void> _update(Map<String, dynamic> data) async {
    try {
      await _ensureExists();
      await _withRetry(() => _doc.update(data));
    } on FirebaseException catch (e, st) {
      _logFirestoreFailure('update', e, st);
    }
  }

  Future<bool> _purchase({
    required String ownedKey,
    required String equipKey,
    required String itemId,
    required int priceCoins,
  }) async {
    return _guardBoolTransaction('purchase', () async {
      await _ensureExists();
      return _firestore.runTransaction<bool>((txn) async {
        final snap = await txn.get(_doc);
        final profile = _fromMap(uid, snap.data() ?? _defaultProfileMap(uid));
        final owned = switch (ownedKey) {
          'ownedThemeIds' => profile.ownedThemeIds,
          'ownedAvatarIds' => profile.ownedAvatarIds,
          _ => profile.ownedInitialSkinIds,
        };
        if (owned.contains(itemId)) {
          txn.update(_doc, {
            equipKey: itemId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        }
        if (profile.coins < priceCoins) return false;
        txn.update(_doc, {
          'coins': profile.coins - priceCoins,
          ownedKey: [...owned, itemId],
          equipKey: itemId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    });
  }

  Future<UserProfile> _ensureExists() async {
    final data = _defaultProfileMap(uid);
    try {
      final snap = await _withRetry(() => _doc.get());
      if (snap.exists && snap.data() != null) {
        // Never merge full defaults onto an existing profile — that resets
        // coins, campaign stars, displayName, etc. to stub values.
        final profile = _fromMap(uid, snap.data()!);
        _latestProfile = profile;
        return profile;
      }
      await _withRetry(() => _doc.set(data, SetOptions(merge: true)));
      final created = await _withRetry(() => _doc.get());
      final profile = _fromMap(uid, created.data() ?? data);
      _latestProfile = profile;
      return profile;
    } catch (_) {
      // Fall through to local fallback below for transient outages.
    }
    if (_latestProfile != null) return _latestProfile!;
    return _fromMap(uid, data);
  }

  Future<UserProfile> _loadProfileBestEffort() async {
    if (_latestProfile != null) return _latestProfile!;
    try {
      final snap = await _withRetry(() => _doc.get());
      if (snap.data() != null) {
        return _fromMap(uid, snap.data()!);
      }
    } catch (_) {}
    return _fromMap(uid, _defaultProfileMap(uid));
  }

  void _emit(UserProfile profile) {
    _latestProfile = profile;
    if (!_controller.isClosed) {
      _controller.add(profile);
    }
  }

  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 4,
  }) async {
    var attempt = 0;
    var delay = const Duration(milliseconds: 250);
    while (true) {
      attempt++;
      try {
        return await operation();
      } on FirebaseException catch (e) {
        final transient = e.code == 'unavailable' ||
            e.code == 'deadline-exceeded' ||
            e.code == 'aborted' ||
            e.code == 'resource-exhausted';
        if (!transient || attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
  }

  Future<bool> _guardBoolTransaction(
    String operation,
    Future<bool> Function() run,
  ) async {
    try {
      return await run();
    } on FirebaseException catch (e, st) {
      _logFirestoreFailure(operation, e, st);
      return false;
    }
  }

  void _logFirestoreFailure(
    String operation,
    FirebaseException e,
    StackTrace st,
  ) {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint(
      '[Profile][firestore][$operation] code=${e.code} '
      'message=${e.message ?? '(none)'} repoUid=$uid authUid=${authUid ?? 'null'}',
    );
    if (e.code == 'permission-denied') {
      if (authUid != uid) {
        debugPrint(
          '[Profile] permission-denied: repo uid does not match auth uid.',
        );
      }
      debugPrint(
        '[Profile] If App Check is enforced, verify Play/TestFlight signing '
        'cert SHA in Firebase console (SETUP.md).',
      );
    }
    unawaited(AnalyticsService.instance.recordError(e, st));
  }

  void dispose() {
    _remoteSub?.cancel();
    _controller.close();
  }

  static Map<String, dynamic> _toMap(UserProfile p) {
    return {
      'uid': p.uid,
      'displayName': p.displayName,
      'coins': p.coins,
      'xp': p.xp,
      'level': p.level,
      'wins': p.wins,
      'losses': p.losses,
      'ties': p.ties,
      'gamesPlayed': p.gamesPlayed,
      'winStreak': p.winStreak,
      'bestWinStreak': p.bestWinStreak,
      'seasonId': p.seasonId,
      'rating': p.rating,
      'seasonBestRating': p.seasonBestRating,
      'seasonWins': p.seasonWins,
      'seasonLosses': p.seasonLosses,
      'seasonTies': p.seasonTies,
      'themeId': p.themeId,
      'avatarId': p.avatarId,
      'initialSkinId': p.initialSkinId,
      'removeAds': p.removeAds,
      'ownedThemeIds': p.ownedThemeIds,
      'ownedAvatarIds': p.ownedAvatarIds,
      'ownedInitialSkinIds': p.ownedInitialSkinIds,
      'lives': p.lives,
      'nextLifeAt':
          p.nextLifeAt == null ? null : Timestamp.fromDate(p.nextLifeAt!),
      'lastDailyClaimAt': p.lastDailyClaimAt == null
          ? null
          : Timestamp.fromDate(p.lastDailyClaimAt!),
      'lastRewardedAdAt': p.lastRewardedAdAt == null
          ? null
          : Timestamp.fromDate(p.lastRewardedAdAt!),
      'campaignStars': p.campaignStars,
      'lastCampaignLevelId': p.lastCampaignLevelId,
      'dailyPuzzleDate': p.dailyPuzzleDate,
      'dailyPuzzleLevelId': p.dailyPuzzleLevelId,
      'dailyPuzzleCompleted': p.dailyPuzzleCompleted,
      'dailyPuzzleStreak': p.dailyPuzzleStreak,
      'dailyMissions': {
        'date': p.dailyMissions.date,
        'wins': p.dailyMissions.wins,
        'games': p.dailyMissions.games,
        'boxes': p.dailyMissions.boxes,
        'claimed': p.dailyMissions.claimedIds.fold<Map<String, bool>>(
          {},
          (map, id) => map..[id] = true,
        ),
      },
      'powerUpInventory': p.powerUpInventory,
    };
  }

  static UserProfile _fromMap(String uid, Map<String, dynamic> map) {
    DateTime? asDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    List<String> asStringList(dynamic value) =>
        value is List ? value.map((e) => e.toString()).toList() : const [];

    return UserProfile(
      uid: uid,
      displayName: (map['displayName'] as String?) ?? 'Player',
      coins: (map['coins'] as num?)?.toInt() ?? 200,
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      level: (map['level'] as num?)?.toInt() ?? 1,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      ties: (map['ties'] as num?)?.toInt() ?? 0,
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
      winStreak: (map['winStreak'] as num?)?.toInt() ?? 0,
      bestWinStreak: (map['bestWinStreak'] as num?)?.toInt() ?? 0,
      seasonId: (map['seasonId'] as String?) ??
          RankSystem.currentSeasonId(DateTime.now()),
      rating: (map['rating'] as num?)?.toInt() ?? 1000,
      seasonBestRating: (map['seasonBestRating'] as num?)?.toInt() ?? 1000,
      seasonWins: (map['seasonWins'] as num?)?.toInt() ?? 0,
      seasonLosses: (map['seasonLosses'] as num?)?.toInt() ?? 0,
      seasonTies: (map['seasonTies'] as num?)?.toInt() ?? 0,
      themeId: (map['themeId'] as String?) ?? 'theme_neon_default',
      avatarId: (map['avatarId'] as String?) ?? 'avatar_orb_cyan',
      initialSkinId:
          (map['initialSkinId'] as String?) ?? 'initial_skin_classic',
      removeAds: (map['removeAds'] as bool?) ?? false,
      ownedThemeIds: asStringList(map['ownedThemeIds']).isEmpty
          ? const ['theme_neon_default']
          : asStringList(map['ownedThemeIds']),
      ownedAvatarIds: asStringList(map['ownedAvatarIds']).isEmpty
          ? const ['avatar_orb_cyan']
          : asStringList(map['ownedAvatarIds']),
      ownedInitialSkinIds: asStringList(map['ownedInitialSkinIds']).isEmpty
          ? const ['initial_skin_classic']
          : asStringList(map['ownedInitialSkinIds']),
      lives: ((map['lives'] as num?)?.toInt() ?? Progression.maxLives)
          .clamp(0, Progression.maxLives)
          .toInt(),
      nextLifeAt: asDate(map['nextLifeAt']),
      lastDailyClaimAt: asDate(map['lastDailyClaimAt']),
      lastRewardedAdAt: asDate(map['lastRewardedAdAt']),
      campaignStars: () {
        final raw = map['campaignStars'];
        if (raw is Map) {
          return Map<String, int>.from(
            raw.map((k, v) => MapEntry(k as String, (v as num).toInt())),
          );
        }
        return const <String, int>{};
      }(),
      lastCampaignLevelId: map['lastCampaignLevelId'] as String?,
      dailyPuzzleDate: map['dailyPuzzleDate'] as String?,
      dailyPuzzleLevelId: map['dailyPuzzleLevelId'] as String?,
      dailyPuzzleCompleted: map['dailyPuzzleCompleted'] as bool? ?? false,
      dailyPuzzleStreak: (map['dailyPuzzleStreak'] as num?)?.toInt() ?? 0,
      dailyMissions: _parseDailyMissions(map['dailyMissions']),
      powerUpInventory: () {
        final raw = map['powerUpInventory'];
        if (raw is Map) {
          return Map<String, int>.from(
            raw.map((k, v) => MapEntry(k as String, (v as num).toInt())),
          );
        }
        return const <String, int>{};
      }(),
    );
  }

  static DailyMissionProgress _parseDailyMissions(dynamic raw) {
    if (raw is! Map) return const DailyMissionProgress.empty().forToday();
    final claimedRaw = raw['claimed'];
    final claimed = <String>{};
    if (claimedRaw is Map) {
      for (final entry in claimedRaw.entries) {
        if (entry.value == true) claimed.add(entry.key as String);
      }
    }
    return DailyMissionProgress(
      date: (raw['date'] as String?) ?? DailyMissionProgress.todayUtc(),
      wins: (raw['wins'] as num?)?.toInt() ?? 0,
      games: (raw['games'] as num?)?.toInt() ?? 0,
      boxes: (raw['boxes'] as num?)?.toInt() ?? 0,
      claimedIds: claimed,
    ).forToday();
  }

  static Map<String, dynamic> _defaultProfileMap(String uid) {
    final now = DateTime.now();
    return {
      'uid': uid,
      'displayName': 'Player',
      'coins': 200,
      'xp': 0,
      'level': 1,
      'wins': 0,
      'losses': 0,
      'ties': 0,
      'gamesPlayed': 0,
      'winStreak': 0,
      'bestWinStreak': 0,
      'seasonId': RankSystem.currentSeasonId(now),
      'rating': 1000,
      'seasonBestRating': 1000,
      'seasonWins': 0,
      'seasonLosses': 0,
      'seasonTies': 0,
      'themeId': 'theme_neon_default',
      'avatarId': 'avatar_orb_cyan',
      'initialSkinId': 'initial_skin_classic',
      'removeAds': false,
      'ownedThemeIds': const ['theme_neon_default'],
      'ownedAvatarIds': const ['avatar_orb_cyan'],
      'ownedInitialSkinIds': const ['initial_skin_classic'],
      'lives': Progression.maxLives,
      'nextLifeAt': null,
      'lastDailyClaimAt': null,
      'lastRewardedAdAt': null,
      'campaignStars': <String, int>{},
      'lastCampaignLevelId': null,
      'dailyPuzzleDate': null,
      'dailyPuzzleLevelId': null,
      'dailyPuzzleCompleted': false,
      'dailyPuzzleStreak': 0,
      'dailyMissions': {
        'date': DailyMissionProgress.todayUtc(),
        'wins': 0,
        'games': 0,
        'boxes': 0,
        'claimed': <String, bool>{},
      },
      'powerUpInventory': <String, int>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
