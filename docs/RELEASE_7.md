# Release 7 — Security + beta hotfixes

## Done before Release 7

- Firestore rules whitelist deployed (dev + prod)
- Apple `.p8` removed from git; local key for Sign in with Apple only
- Shop avatar grid overflow fix (small iPhones)

## Beta reports (Norway)

### Remove Ads not working

**Cause:** Tight Firestore rules block client `removeAds` writes. IAP still calls `grantRemoveAds()` → permission denied after a successful store purchase.

**Fix:** `verifyRemoveAdsPurchase` Cloud Function + client calls it instead of direct Firestore.

### Price shows $1.99 not 29 NOK

**App code:** Uses `ProductDetails.price` from the store (not hardcoded).

**Check:**

1. App Store Connect → `dot_clash_remove_ads` → Pricing → Norway tier
2. Tester uses a **Norwegian Apple ID** (US accounts see USD in TestFlight)
3. Logs: `[IAP] loaded dot_clash_remove_ads price=… currency=…`

## Release 7 scope

See plan: [`.cursor/plans/release_7_security_133b2307.plan.md`](../.cursor/plans/release_7_security_133b2307.plan.md)

### Shipped (backend + client in repo)

- **Functions deployed** to `dot-clash-72cc6` (prod) and `dot-clash-dev`: `verifyRemoveAdsPurchase`, economy callables, hardened `completeCampaignLevel` (rewards from Firestore campaign docs, not client).
- **Flutter:** IAP → `verifyRemoveAdsPurchase`; shop/daily/ads/lives/match → callables; prod no longer falls back to direct Firestore economy writes.
- **Requires a new store build** for beta testers — installed builds still call old client code until updated.

### Prod IAP secrets (required for real receipt checks)

Step-by-step clicks: **`SETUP.md` §4b — Server-side IAP verification**.

Set on prod deploy (`functions/.env.dot-clash-72cc6`) or Cloud Run env vars:

| Secret | Purpose |
|--------|---------|
| `APPLE_IAP_KEY_ID` | App Store Connect API key (In-App Purchase) |
| `APPLE_IAP_ISSUER_ID` | Issuer ID |
| `APPLE_IAP_PRIVATE_KEY` | `.p8` contents (use `\n` for newlines) |
| `APPLE_IAP_BUNDLE_ID` | Optional; defaults to `com.vividmemories.dotclash` |

Android: grant the default Functions service account **View financial data** in Play Console (or use a dedicated service account with Android Publisher API).

Dev project skips store verification when secrets/API are missing.

### Still to do

- Ship Release 7 app build to TestFlight / Play closed testing
- Confirm Norway pricing tier in App Store Connect
- `npm audit` in `functions/` (low priority)

## Deploy

```bash
firebase use dev
firebase deploy --only functions

firebase use prod
firebase deploy --only functions
```

Prod functions were deployed on 2026-06-02 with the callables above.
