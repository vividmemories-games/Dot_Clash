# Dot Clash — Architecture decisions

Immutable decisions agents and contributors should not reverse without an explicit product/architecture discussion. For flows and file paths, see [architecture.md](architecture.md). Agent entry point: [../AGENTS.md](../AGENTS.md).

**Code describes current behavior. This file describes intended invariants.** If they conflict, report the discrepancy and confirm intent with the user before changing code or decisions — do not update this file to match a suspected regression.

---

## Game architecture

| ID | Decision | Rationale |
|----|----------|-----------|
| **G-1** | **Two game backends.** Campaign, Quick Match, Local, and Daily use client `GameRules`. Challenge a Friend uses server `functions/src/game_rules.ts` + callables. | Prevents cheating in live PvP; keeps offline modes fast. |
| **G-2** | **Game logic stays out of widgets.** Rules, move validation, scoring, timers, and settlement live in providers, domain, repositories, services, or Cloud Functions. | Testable, release-safe; matches clean architecture. |
| **G-3** | **Challenge sync is separate from `gameProvider`.** Use `ChallengeGameNotifier` / `challengeGameProvider` only. | Avoids regressions in Campaign and Quick Match. |
| **G-4** | **Live 1v1 lives in `lib/features/challenge/`** — not a generic multiplayer module. | Single implementation path for PvP. |
| **G-5** | **`GameScreen` disables local listeners when in Challenge mode** (`_isChallenge`): no campaign settlement, boosts, or local `gameProvider.isOver` handling. | Challenge outcome comes from the room, not local state. |
| **G-6** | **Challenge settlement listens to Firestore room status** (`finished` / `abandoned`), not local `gameProvider.isOver`. | Server is authority; clients can desync briefly. |
| **G-7** | **Dart and TypeScript game rules stay in parity.** Change `game_rules.dart` and `game_rules.ts` together; run `test/game/rules_test.dart`. | Server and client must agree on legal moves and scoring. |
| **G-8** | **Challenge board geometry is server allowlist-only.** Host sends `boardPresetId` on `createChallenge`; clients never send raw `rows`/`cols`/`disabledCells`. Presets live in `functions/src/challenge_board_presets.ts` (mirrored in Dart for picker UI only). Launch presets: **Classic** 6×6, **Blitz** 4×4, **Fortress** 5×5 (center void). Missing `boardPresetId` → `challenge_classic` (build 19 compat). `joinChallenge` seeds `gameState` from the room preset, not hardcoded 6×6. Moves still validated in `commitChallengeMoveInTransaction`. | Prevents client-side board cheating; enables host-chosen layouts without free-form grids. |
| **G-9** | **Host = player A, guest = player B** on the server. Each client maps “you” via `GameConfig.myPlayerId`. | Consistent turn order and score labels across devices. |
| **G-10** | **Guest preview before join.** Join-by-code opens lobby read-only; guest taps **JOIN CHALLENGE** to call `joinChallenge`. No auto-join when the lobby loads. Host picks board via CREATE → preset sheet. | Guest sees host layout before committing; avoids surprise unfair boards. |
| **G-11** | **Rematch inherits source preset.** Post-match rematch/re-challenge passes the finished room's `boardPresetId`. Rivalry-row re-challenge from the hub defaults Classic unless launched from post-match rematch. | Same layout for revenge; hub re-challenge stays simple until history stores preset. |

---

## Challenge economy and profile

| ID | Decision | Rationale |
|----|----------|-----------|
| **C-1** | **Challenge v1 is history-only.** `recordChallengeMatch` writes match rows and H2H stats; it does **not** grant coins, XP, lives, or rating. | Keeps economy in campaign/quick-match settlement callables; simpler anti-abuse. |
| **C-2** | **Aggregate stats** (wins, games played, coins, rating) come from campaign / quick match only — not Challenge settlement. | See C-1. |
| **C-3** | **Challenge rivalries and recent matches UI live on the Challenge hub** (`ChallengeHomeScreen`, `ChallengeHistoryScreen`) — not on the Profile tab. | Profile = identity, economy, campaign progress; Challenge = social rivalry. |
| **C-4** | **Match history** stored at `profiles/{uid}/matches` with `modeLabel: 'Challenge'`. | Unified history model; Challenge is a mode label, not a separate collection. |

---

## Firebase and security

| ID | Decision | Rationale |
|----|----------|-----------|
| **F-1** | **Two Firebase projects:** `dot-clash-dev` (dev flavor) and `dot-clash-72cc6` (prod flavor). Never mix config files or deploy targets. | Auth, Firestore, Functions, and IAP depend on correct project. |
| **F-2** | **`challenges/{code}` — clients may read; clients may not write.** All room mutations go through Cloud Functions. | Prevents move tampering and state corruption. |
| **F-2b** | **`recordChallengeMatch` must stay idempotent** — safe if invoked more than once per player per finished room. | Reconnects and duplicate bindings must not double-write history. |
| **F-3** | **Turn timeouts and stale rooms** handled by `processChallengeTimeouts` (scheduler, ~1 min) plus client backup in `ChallengeGameNotifier.onTurnTimedOut`. | Server is primary; client improves UX when push is delayed. |
| **F-4** | **Campaign level content** loads from bundled JSON (`assets/campaign/world_*.json`), not Firestore during play. | Offline-capable campaign; predictable content shipping. |
| **F-5** | **Economy mutations** (coins, XP, lives, missions) go through settlement callables — not direct client Firestore writes to profile economy fields. | Server-authoritative progression. |

---

## Build, release, and environments

| ID | Decision | Rationale |
|----|----------|-----------|
| **R-1** | **Ship and discuss by build number** (`+N` in `pubspec.yaml`), not “Release N”. Bump `+N` before every store upload. | Matches store versioning; avoids ambiguous release names. |
| **R-2** | **Closed testing on prod** uses prod Firebase + **`BETA_ADS=true`** (Google test ad units via `scripts/build_closed_testing.sh`). | Real testers on prod backend without invalid AdMob traffic. |
| **R-3** | **Do not use `BETA_ADS` for public launch.** | Production ad units and revenue only after launch. |
| **R-4** | **Deploy Functions + Firestore rules/indexes to prod** when backend changes ship to TestFlight / Play closed testing. | Client-only uploads are insufficient if callables or rules changed. |

---

## Repo, legal, and tooling

| ID | Decision | Rationale |
|----|----------|-----------|
| **T-1** | **Legal pages** (Privacy, Terms, Contact, App Links hosting) live in **[vividmemories-games.github.io](https://github.com/vividmemories-games/vividmemories-games.github.io)** — not this repo. Sync URLs with `lib/core/env/app_env.dart` / `lib/core/legal/legal_links.dart`. | Legal site is separate GitHub Pages deployment. |
| **T-2** | **Secrets stay out of git** (keystore, `.p8`, service account JSON, API keys). See [`SETUP.md`](../SETUP.md) for signing and env setup. | Security and store compliance. |
| **T-3** | **Codex review is manual one-shot** — run `./scripts/codex_review.sh`; do not auto-loop Codex fixes. See [codex-workflow.md](codex-workflow.md). | Controlled review cost and scope. |
| **T-4** | **Callable testing:** use Postman/curl with `{ "data": { ... } }` to the emulator — not `firebase functions:shell` for Gen 2 callables. | Shell does not send callable bodies correctly (400 errors). |

---

## Campaign UX (regression-sensitive)

| ID | Decision | Rationale |
|----|----------|-----------|
| **U-1** | **Campaign abandon:** leaving a level in progress does not consume a life; a fresh level with no moves shows no leave dialog. | Documented ship behavior — regressions block release. |
| **U-2** | **Mid-match navigation** (Home, MORE → Exit, system back) shows confirm dialog; **Stay** preserves board state. | Applies to Challenge and other live matches. |
