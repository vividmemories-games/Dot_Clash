# Dot Clash — Architecture

Connected map of how the Flutter app boots, routes users, runs game logic, and syncs progression. **Gameplay is client-authoritative** (`GameRules` on device). Firebase handles auth, profile, match **history**, and settlement callables. **Online PvP / matchmaking is not implemented** (`lib/features/multiplayer/` is an empty scaffold).

For an interactive version (tabbed graphs, click nodes for file hints), open the Cursor Canvas: `dot-clash-architecture.canvas.tsx` in the IDE canvases panel (beside chat).

---

## How to read this

| Flow type | What to trace |
|-----------|----------------|
| **Control** | `main.dart` → `GoRouter` redirects → screens → `GameNotifier.makeMove` |
| **Data** | `authStateProvider` → `profileRepositoryProvider` → `profileProvider` → UI; game-over → callables or Firestore fallback |
| **Out of scope** | Live board sync, matchmaking, server move validation |

---

## 1. System layers

```mermaid
flowchart TB
  subgraph presentation [Presentation]
    Screens[Feature screens]
    Widgets[Shared widgets AppShell neon UI]
    Board[BoardWidget CustomPainter]
  end

  subgraph state [Riverpod composition root]
    Providers[Providers StateNotifier StreamProvider]
    Router[appRouterProvider GoRouter]
  end

  subgraph domain [Domain pure Dart]
    GameRules[GameRules GameState]
    Campaign[Campaign levels evaluator]
    ProfileDom[UserProfile Rank Lives]
    AI[AiPlayer]
  end

  subgraph data [Data layer]
    ProfileRepo[ProfileRepository]
    FirestoreRepo[FirestoreProfileRepository]
    MockRepo[MockProfileRepository]
    CampaignJSON[CampaignContentRepository assets]
    Callable[CallableBackend]
  end

  subgraph external [External]
    FirebaseAuth[Firebase Auth]
    Firestore[(Firestore)]
    Functions[Cloud Functions]
    AdMob[AdMob IAP Analytics]
  end

  Screens --> Providers
  Board --> Providers
  Providers --> Router
  Providers --> GameRules
  Providers --> Campaign
  Providers --> ProfileRepo
  GameRules --> AI
  ProfileRepo --> FirestoreRepo
  ProfileRepo --> MockRepo
  FirestoreRepo --> Firestore
  FirestoreRepo --> Callable
  Callable --> Functions
  CampaignJSON --> Campaign
  Providers --> FirebaseAuth
  Screens --> AdMob
```

| Layer | Location | Role |
|-------|----------|------|
| Entry | `lib/main.dart` → `lib/app.dart` | Firebase, App Check, `ProviderScope`, theme from profile |
| Router | `lib/core/router/app_router.dart` | Routes, auth/onboarding redirects |
| Game engine | `lib/features/game/domain/` | Pure rules; no Firebase during moves |
| Profile | `lib/features/profile/` | Repo switch + Firestore/mock |
| Backend | `functions/src/` | Settlement only (no move validation) |

---

## 2. Boot and control flow

```mermaid
sequenceDiagram
  participant Main as main.dart
  participant FB as Firebase AppCheck
  participant Scope as ProviderScope
  participant App as DotClashApp
  participant Router as GoRouter
  participant Auth as auth_provider
  participant Onboard as onboarding_provider

  Main->>FB: initializeApp optional skip if unconfigured
  Main->>Scope: runApp
  Scope->>App: build
  App->>Router: watch appRouterProvider
  App->>App: postFrame adService.init
  Router->>Auth: redirect reads currentUser
  Router->>Onboard: redirect reads onboardingSeen
  alt first launch
    Router->>Router: /splash
  else no user and Firebase on
    Router->>Router: / auth
  else signed in
    Router->>Router: /home tab shell
  end
```

**Key control nodes**

- `lib/main.dart` — portrait lock, optional Firebase + Crashlytics
- `lib/app.dart` — `MaterialApp.router`, theme from `profileProvider.themeId`
- `lib/core/router/app_router.dart` — `refreshListenable` merges auth + onboarding refresh
- `lib/shared/widgets/app_shell.dart` — Home, Campaign, Profile, Shop tabs

---

## 3. Navigation graph

```mermaid
flowchart LR
  Splash["/splash Onboarding"]
  Auth["/ AuthScreen"]
  subgraph shell [StatefulShellRoute AppShell]
    Home["/home"]
    Campaign["/campaign"]
    Profile["/profile"]
    Shop["/shop"]
  end
  Game["/game GameScreen"]
  CampPlay["/campaign/play/:id"]
  Daily["/daily-puzzle"]
  Settings["/settings"]
  Contact["/contact"]

  Splash -->|signed in| Home
  Splash -->|onboarding done| Auth
  Auth -->|login| Home
  Home -->|local practice| Game
  Home -->|daily| Daily
  Campaign --> CampPlay
  CampPlay --> Game
  Daily --> Game
  Home --> Settings
  Home --> Contact
  Game -->|campaign result| LevelResult[LevelResultScreen]
```

**Navigation inputs**

- `context.go` / `context.push` from feature screens
- `GameConfig` via `GoRouterState.extra` or route builder (campaign/daily)
- `gameConfigProvider` updated when `GameScreen` mounts

---

## 4. Game control flow (one match)

```mermaid
flowchart TD
  Entry[Home or Campaign route] --> Config[gameConfigProvider GameConfig]
  Config --> Screen[GameScreen]
  Screen --> Watch[watch gameProvider matchSession turnTimer settings profile]
  Tap[BoardWidget onEdgeTap] --> MakeMove[GameNotifier.makeMove]
  MakeMove --> Rules[GameRules.applyMove]
  Rules --> State[GameState updated]
  State --> ExtraTurn{box captured?}
  ExtraTurn -->|yes same player| Tap
  ExtraTurn -->|no| Timer[turnTimerProvider tick]
  State --> AiCheck{AI turn?}
  AiCheck -->|yes| AiPlayer[AiPlayer.pickMove delayed]
  AiPlayer --> MakeMove
  Timer -->|timeout| OnTimeout[onTurnTimedOut]
  State --> Listen[ref.listen gameProvider isOver]
  Listen --> LocalSettle[settleMatch recordMatch]
  Listen --> CampSettle[settleCampaignLevel or settleDailyPuzzle]
  LocalSettle --> Repo[ProfileRepository]
  CampSettle --> Repo
```

| Step | File |
|------|------|
| Rules | `lib/features/game/domain/rules/game_rules.dart` |
| State machine | `lib/features/game/providers/game_provider.dart` (`GameNotifier`) |
| Session meta | `lib/features/game/domain/models/match_session.dart`, `match_session_provider.dart` |
| UI + listeners | `lib/features/game/presentation/game_screen.dart` |
| Board input | `lib/features/game/presentation/widgets/board_widget.dart` |
| AI | `lib/features/ai/ai_player.dart` |

**No Firebase calls** between `makeMove` and game-over listeners.

---

## 5. Data flow (Riverpod + Firebase)

```mermaid
flowchart TD
  AuthState[authStateProvider Firebase Auth stream]
  CurrentUser[currentUserProvider]
  AuthState --> CurrentUser

  CurrentUser --> RepoSwitch{user null?}
  RepoSwitch -->|yes| Mock[MockProfileRepository in-memory]
  RepoSwitch -->|no| FS[FirestoreProfileRepository uid]

  Mock --> ProfileStream[profileProvider StreamProvider]
  FS --> ProfileStream

  ProfileStream --> HomeUI[HomeScreen lives XP missions]
  ProfileStream --> Theme[AppTheme from themeId]
  ProfileStream --> GameBoosts[powerUpInventory boosts]
  ProfileStream --> Shop[ShopScreen]

  GameOver[Game over settlement] --> FS
  FS --> TryCallable[CallableBackend HTTPS]
  TryCallable -->|success| Functions[completeCampaignLevel completeDailyPuzzle claimDailyMission]
  TryCallable -->|fail dev fallback| DirectWrite[Firestore transaction write]
  FS --> MatchHistory["profiles/uid/matches subcollection"]

  Settings[settingsProvider SharedPreferences] --> GameScreen
  Catalog[MockCatalogRepository] --> Shop
```

Repository wiring (`lib/features/profile/providers/profile_providers.dart`):

```dart
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return MockProfileRepository();
  return FirestoreProfileRepository(uid: user.uid);
});
```

Campaign **content** loads from bundled JSON (`assets/campaign/world_*.json`), not Firestore during play.

---

## 6. Firebase backend map

```mermaid
flowchart LR
  Client[Flutter app]
  Auth[Firebase Auth]
  AC[App Check]
  FS[(Firestore)]
  CF[Cloud Functions us-central1]

  Client --> Auth
  Client --> AC
  Client --> FS
  Client --> CF

  subgraph collections [Firestore collections]
    Profiles["profiles/uid"]
    Matches["profiles/uid/matches"]
    Deletions["accountDeletions server only"]
  end

  FS --> Profiles
  FS --> Matches

  subgraph callables [Callable functions]
    CCL[completeCampaignLevel]
    CDP[completeDailyPuzzle]
    CDM[claimDailyMission]
    DEL[deleteUserData]
  end

  CF --> CCL
  CF --> CDP
  CF --> CDM
  CF --> DEL
  CCL --> Profiles
  CDP --> Profiles
  DEL --> Profiles
  DEL --> Auth
```

| Callable | Source | Client |
|----------|--------|--------|
| `completeCampaignLevel` | `functions/src/index.ts` | `lib/services/backend/callable_backend.dart` |
| `completeDailyPuzzle` | same | via `firestore_profile_repository.dart` |
| `claimDailyMission` | same | same |
| `deleteUserData` | `functions/src/compliance.ts` | `lib/features/account/data/account_deletion_service.dart` |

---

## 7. Cross-cutting services

```mermaid
flowchart LR
  App[DotClashApp]
  Ads[AdService AdMob]
  Consent[AdConsentService UMP]
  Rewards[AdRewardRouter]
  IAP[IapService remove ads]
  Analytics[AnalyticsService]
  AppCheck[AppCheckService]

  App --> Ads
  Ads --> Consent
  Rewards --> ProfileRepo[ProfileRepository grants]
  GameScreen --> Rewards
  IAP --> ProfileRepo
  Analytics --> FirebaseAnalytics
  Main[main.dart] --> AppCheck
```

---

## 8. Feature module dependencies

```mermaid
flowchart TB
  core[core env theme router legal]
  auth[auth]
  onboarding[onboarding]
  home[home]
  game[game]
  campaign[campaign]
  profile[profile]
  shop[shop]
  settings[settings]
  ai[ai]
  powerups[powerups]
  services[services ads backend firebase iap analytics]
  shared[shared widgets layout]

  home --> profile
  home --> campaign
  home --> game
  campaign --> game
  campaign --> profile
  game --> ai
  game --> powerups
  game --> profile
  game --> services
  shop --> profile
  settings --> profile
  settings --> account[account deletion]
  account --> services
  auth --> profile
  app[app.dart] --> core
  app --> profile
  app --> services
  router[app_router] --> auth
  router --> onboarding
  router --> home
  router --> game
  router --> campaign
  router --> shop
  router --> profile
  router --> settings
  router --> contact[contact]
```

---

## 9. Mental model

| Question | Answer |
|----------|--------|
| Where is state? | Riverpod per feature; router in `core/router` |
| Where are moves validated? | `GameRules` only (client) |
| When does Firebase run? | Auth, profile stream, settlement, shop/IAP, analytics |
| Guest vs signed-in? | `MockProfileRepository` vs `FirestoreProfileRepository` |
| Multiplayer? | Not built; `matches` is **history**, not live sync |

---

## File index (key paths)

| Path | Role |
|------|------|
| `lib/main.dart` | Entry: Firebase, App Check, `ProviderScope` |
| `lib/app.dart` | `MaterialApp.router`, ads init, theme from profile |
| `lib/core/router/app_router.dart` | All routes and redirects |
| `lib/core/env/app_env.dart` | Flavor, timers, OAuth client IDs |
| `lib/features/auth/providers/auth_provider.dart` | Auth stream, sign-in actions |
| `lib/features/onboarding/providers/onboarding_provider.dart` | First-launch flag |
| `lib/features/profile/providers/profile_providers.dart` | Repo switch, `profileProvider` |
| `lib/features/profile/data/firestore_profile_repository.dart` | Firestore + callables + match history |
| `lib/features/profile/data/mock_profile_repository.dart` | Guest/offline progression |
| `lib/features/game/providers/game_provider.dart` | `GameNotifier`, turn timer |
| `lib/features/game/domain/rules/game_rules.dart` | Pure game rules |
| `lib/features/game/presentation/game_screen.dart` | Board UI, settlement listeners |
| `lib/features/campaign/data/campaign_content_repository.dart` | Campaign JSON from assets |
| `lib/features/campaign/providers/campaign_providers.dart` | Level loading, progress |
| `lib/features/ai/ai_player.dart` | AI move selection |
| `lib/services/backend/callable_backend.dart` | HTTPS callable wrapper |
| `lib/services/firebase/app_check_service.dart` | App Check activation |
| `lib/services/ads/ad_reward_router.dart` | Rewarded ads → profile grants |
| `functions/src/index.ts` | Campaign/daily/mission callables |
| `functions/src/compliance.ts` | `deleteUserData` |
| `firestore.rules` | Security rules |

---

*Last updated with codebase snapshot (~108 Dart files under `lib/`). Regenerate Canvas graph data when adding major features (e.g. online PvP).*
