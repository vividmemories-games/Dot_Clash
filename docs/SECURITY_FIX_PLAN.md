# Security fix plan

**Status:** Finding #1 (Firestore rules) is fixed in `firestore.rules`. Deploy with `firebase deploy --only firestore:rules` before or right after confirming Cloud Functions are live in production.

---

## The big picture (explain like you're 10)

Imagine Dot Clash is a **school lunch trading game**. You earn stickers (coins), level up, and buy cool pencil cases (themes). There are two ways to update your report card in the cloud:

1. **The game app** — what players see on their phone.
2. **The teacher's desk** — Cloud Functions, the only place that should be allowed to say "you really earned this."

**The problem we had:** The app was allowed to write *anything* on its own report card. A clever kid could open the notebook and write "I have 999,999 stickers" without playing. That's cheating.

**What we fixed today (#1):** We changed the rules so the app can **only** change harmless things — your nickname and which theme/avatar you wear. Stickers, levels, lives, and purchases can **only** be changed by the teacher's desk (Cloud Functions).

**What still needs fixing:** Some parts of the app still *try* to write stickers themselves (shop, ads, IAP). Those writes will fail until we move them to Cloud Functions tomorrow. Campaign / daily puzzle / missions already use Cloud Functions when deployed — those should keep working.

---

## ✅ Done today — #1 Client-forgeable profile (Critical)

### What was wrong

Firestore used a **"don't touch these few fields"** list. Everything else — coins, XP, `removeAds`, owned items, power-ups, lives — could be edited by anyone signed in.

### What we did

- Switched to a **whitelist**: clients may only update `displayName`, `themeId`, `avatarId`, `initialSkinId`, `updatedAt`.
- New profiles must start with **exact starter values** (200 coins, no ads, default cosmetics, 5 lives, etc.).
- Removed dev fallback rules that explicitly allowed campaign/mission coin writes from the client.

### Deploy

```bash
firebase deploy --only firestore:rules
```

### After deploy — expect these to fail until tomorrow

| Feature | Why |
|---------|-----|
| Shop purchases (themes, avatars, power-ups) | Client still writes coins + owned lists |
| Daily login reward / rewarded ad coins | Client writes coins directly |
| Buy life / free life from ad | Client writes lives + coins |
| Remove Ads IAP | Client writes `removeAds: true` |
| Quick match settlement (non-campaign) | Client writes coins, XP, rating |
| Campaign/daily/missions **local fallback** | Only if Cloud Functions unreachable |

Campaign, daily puzzle, and mission **claims** should work when callables are deployed (server writes via Admin SDK).

---

## Tomorrow — remaining findings

### #2 Cloud Functions trust client rewards (Critical) — **fixed in Release 7 (2026-06-02)**

**Done:** `completeCampaignLevel` loads rewards from `campaigns/dot_clash/levels/{levelId}`; client no longer sends trusted `coinReward`/`xpReward`. Prod disables local Firestore fallback.

**Kid version:** When you finish a level, the game sends a note to the server saying "I earned 50 coins." A cheater could change the note to "I earned 999,999 coins" and the server would believe it.

**What's wrong:** `completeCampaignLevel` accepts `coinReward`, `xpReward`, `starsEarned`, and `win` from the phone. It only caps stars to 0–3; it never checks the real level data.

**Fix plan:**

1. In `functions/src/index.ts`, load level rewards from Firestore `/campaigns/.../levels/{levelId}` (or a server-side catalog mirroring bundled JSON).
2. Accept only `levelId` + minimal outcome hints (`boxesCaptured`, maybe move count later).
3. Compute `coinReward`, `xpReward`, `starsEarned`, and `win` on the server — never trust client numbers.
4. Remove client-side `_settleCampaignLevelLocal` fallback (or gate it to emulator-only).
5. Add unit tests in `functions/` for reward caps and loss penalties.

**Files:** `functions/src/index.ts`, `lib/features/profile/data/firestore_profile_repository.dart`, optionally seed level rewards in Firestore.

---

### #3 IAP entitlement granted client-side (High) — **fixed in Release 7 (2026-06-02)**

**Done:** `verifyRemoveAdsPurchase` deployed; client uses callable with store receipt. `grantRemoveAds()` is dev-only. **Prod:** set `APPLE_IAP_*` secrets (see `SETUP.md` §4b and `docs/RELEASE_9.md`). **Ship new app build** for testers.

**Kid version:** When you "buy" no ads, the app tells the cloud "trust me, I paid" without showing a receipt. Anyone could also skip the store and just write `removeAds: true` — and before today they could; after today's rules they cannot, but **honest buyers** still need a real path.

**What's wrong:** `iap_service.dart` grants `removeAds` on purchase/restored events with no Apple/Google receipt check. `grantRemoveAds()` wrote directly to Firestore.

**Fix plan:**

1. Add callable `verifyRemoveAdsPurchase` in Cloud Functions:
   - iOS: validate with App Store Server API (may need an App Store Connect API key — separate from the Developer Auth Key in #4).
   - Android: validate with Google Play Developer API.
2. Store purchase token / transaction id on profile (server-only field) for idempotent restore.
3. Client: on purchase/restored, send receipt to callable; only update local UI after server confirms.
4. Remove `grantRemoveAds()` direct Firestore write from `firestore_profile_repository.dart`.

**Files:** `functions/src/` (new `iap.ts`), `lib/services/iap/iap_service.dart`, `firestore.rules` (keep `removeAds` server-only).

---

### #4 Committed Apple Auth key (Critical — repo cleanup done; rotate key in console)

**Kid version:** The key to the school's master supply closet was photocopied and left in the hallway. Anyone who finds it can pretend to be the principal.

**What was wrong:** `ios/Security Key/AuthKey_AR2XHZG3V2.p8` was in the repo and not gitignored (also a personal PDF in the same folder).

**Done in repo (2025-06-02):**

- [x] Added `*.p8`, `*.pem`, `ios/Security Key/` to `.gitignore`
- [x] Removed tracked secrets from git (`.p8` + personal PDF in that folder)
- [x] Deleted local copy of compromised `AuthKey_AR2XHZG3V2.p8`
- [x] Rewrote **local** git history (`git filter-branch`) — key no longer in any commit on `main`
- [x] Documented key handling in `SETUP.md`
- [ ] **You must do in Apple Developer:** revoke `AR2XHZG3V2` and create a new key
- [ ] **Force-push `main`** so GitHub drops the old commits (see below)

**Fix plan (remaining manual steps):**

1. **Immediately** revoke key `AR2XHZG3V2` in [Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list) (Account → Certificates, Identifiers & Profiles → Keys).
2. Create a new key; save `.p8` only under `ios/Security Key/` locally (never commit).
3. Push rewritten history to GitHub (one-time; coordinate with anyone else on the repo):
   ```bash
   git push origin main --force
   ```
   Teammates must re-clone or `git fetch && git reset --hard origin/main` after this.

---

### #5 npm audit vulnerabilities (Low–Medium)

**Kid version:** Some screws in the teacher's desk are a bit loose. The desk still works, but we should tighten them when the manufacturer sends better screws.

**What's wrong:** Transitive `uuid` issues under `firebase-admin` / `firebase-functions`. Blind `npm audit fix --force` may break functions.

**Fix plan:**

1. Run `cd functions && npm audit --omit=dev` and note advisories.
2. Bump `firebase-admin` / `firebase-functions` to latest compatible patch when release notes mention dependency fixes.
3. Re-run `npm run build` and smoke-test callables in emulator.
4. Do **not** force-downgrade admin unless Firebase docs recommend it.

---

### #6 Flutter analyzer cleanup (Low)

**Kid version:** The spell-checker found 236 typos. Most are style ("colour" vs "color"); a few are real mistakes like using a toy after you already put it away (`BuildContext` after `await`).

**Fix plan:**

1. Fix warnings first: unused imports, dead code, `use_build_context_synchronously` in `game_screen.dart` (~line 875 — add `if (!context.mounted) return` after awaits in `_settleCampaign`).
2. Batch deprecation fixes (`withOpacity` → `withValues`, etc.) in a separate PR so security work stays reviewable.
3. Target: zero **warnings**, defer **info**-level style to backlog.

---

## Suggested tomorrow schedule

| Order | Task | Time est. |
|------:|------|-----------|
| 1 | Revoke `AR2XHZG3V2` in Apple Developer + force-push git history (#4) | 15 min |
| 2 | Harden `completeCampaignLevel` (#2) | 2–3 hrs |
| 3 | Move shop / lives / ad rewards to callables (#1 follow-up) | 3–4 hrs |
| 4 | Server-side IAP verification (#3) | 2–3 hrs |
| 5 | npm dependency bump (#5) | 30 min |
| 6 | Analyzer warning sweep (#6) | 1 hr |

---

## Cloud Functions (Release 7)

| Callable | Status |
|----------|--------|
| `purchaseCosmetic` | Deployed |
| `purchasePowerUp` | Deployed |
| `purchaseLife` | Deployed |
| `claimDailyReward` | Deployed |
| `claimRewardedAd` | Deployed |
| `grantLifeFromAd` | Deployed |
| `settleQuickMatch` | Deployed |
| `consumePowerUp` / `grantPowerUp` | Deployed |
| `verifyRemoveAdsPurchase` | Deployed |
| `completeCampaignLevel` | Hardened (server-side rewards) |

---

## Verification checklist (after full fix)

- [ ] Attempt direct Firestore REST patch of `coins: 999999` → **permission denied**
- [ ] Complete campaign level via normal play → coins increase via callable only
- [ ] Call `completeCampaignLevel` with inflated rewards → server ignores client values
- [ ] Purchase Remove Ads on TestFlight → entitlement only after server verification
- [ ] `npm audit` reviewed; functions build and deploy clean
- [ ] `flutter analyze` — zero warnings
