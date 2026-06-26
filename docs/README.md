# Engineering docs

Internal engineering documentation for the Dot Clash app repo.

**Agents:** start at [`../AGENTS.md`](../AGENTS.md) — routes tasks to the docs below.

**Current closed-testing target:** build **23** · `1.5.0+23` in [`pubspec.yaml`](../pubspec.yaml)

## Files here

| File | Purpose |
|------|---------|
| [DECISIONS.md](DECISIONS.md) | Immutable architecture and product decisions (short index) |
| [architecture.md](architecture.md) | System layers, local vs Challenge game paths, Firebase map, navigation |
| [RELEASES.md](RELEASES.md) | Build history, store notes, regression gates, upload checklists |
| [LAUNCH.md](LAUNCH.md) | **Public launch runbook** — week plan, gates, QA matrix, rollout |
| [summary.md](summary.md) | Challenge a Friend implementation log and QA notes |
| [flutter_firebase_store_release_checklist.md](flutter_firebase_store_release_checklist.md) | Store release checklist |
| [codex-workflow.md](codex-workflow.md) | Codex one-shot review workflow |

## Related (repo root)

| File | Purpose |
|------|---------|
| [AGENTS.md](../AGENTS.md) | Agent onboarding — repo map, task routing, QA gates |
| [README.md](../README.md) | Quick run, closed-testing build scripts |
| [SETUP.md](../SETUP.md) | Firebase, flavors, signing, IAP, App Check |
| [../firestore.rules](../firestore.rules) | Firestore security rules (client write boundaries) |

## CI

GitHub Actions: [`.github/workflows/dart.yml`](../.github/workflows/dart.yml) — `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test`

## Legal pages (separate repo)

Privacy Policy, Terms, Contact, and App Links hosting live in the **GitHub Pages** repo — not here:

**[vividmemories-games.github.io](https://github.com/vividmemories-games/vividmemories-games.github.io)**  
Published at: **https://vividmemories-games.github.io**

When editing legal text, update `_data/legal.yml` in that repo and keep URLs in sync with `lib/core/env/app_env.dart`.
