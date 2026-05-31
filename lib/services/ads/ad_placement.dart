/// Identifies where a rewarded or interstitial ad was shown.
enum AdPlacement {
  lifeRefill,
  lossRetry,
  shopCoins,
  doubleWin,
  extraTurns,
  extraTurnsLow,
  riposteRescue,
  practicePack,
  interstitial,
}

extension AdPlacementX on AdPlacement {
  String get analyticsName => name;
}
