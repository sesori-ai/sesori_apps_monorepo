# sesori_desktop — Flutter Desktop Product Shell

The desktop app shell (macOS/Windows/Linux). It wires DI, owns presentation
(window/tray composition), and implements concrete platform adapters. ALL
desktop business logic lives in `module_desktop_core` — never here.

## Target Package Structure (built out phase by phase — see docs/desktop/PLAN.md)

```
lib/
├── core/platform/           # concrete implementations of module_core/module_desktop_core interfaces
├── core/di/                 # DI wiring (4-phase, see below)
├── core/routing/            # window/router composition
├── core/widgets/            # desktop-only presentation
├── app.dart                 # root widget
└── main.dart
```

## DI — 4-phase init (`lib/core/di/injection.dart`)

1. `getIt.init()` — desktop platform adapters (SecureStorage, UrlLauncher, …)
2. `configureAuthDependencies(getIt)` — auth module
3. `configureCoreDependencies(getIt)` — core module
4. `configureDesktopCoreDependencies(getIt)` — desktop core module

All module registrations are lazy; respect the order — a later phase may
depend on registrations from an earlier one at resolution time.

## Rules

- **No business logic.** Bridge process services, repositories, trackers,
  control dispatchers, and cubits belong in `module_desktop_core`; this shell
  only constructs cubits in `BlocProvider(create:)` (resolving deps via
  `getIt`) and renders their state.
- `sesori_auth` is a pubspec dependency **solely** for the
  `configureAuthDependencies(getIt)` call — never import `sesori_auth` types
  outside `lib/core/di/`. Auth functionality is consumed through
  `sesori_dart_core` interfaces.
- Platform adapters implement interfaces from `sesori_dart_core` /
  `sesori_desktop_core` and live in `lib/core/platform/`. Adapters stay dumb —
  no process lifecycle or status state.
- May import `theme_prego` directly for shell-owned presentation.
- Never import bridge-workspace code (e.g. the bridge's OAuth browser opener);
  desktop equivalents go through platform adapters (ADR A11).
- Follow the repo-root `AGENTS.md` error-handling and naming rules.

## Commands

```bash
flutter test                       # from this dir
dart analyze --fatal-infos
flutter build macos|windows|linux
flutter run -d macos               # dev run
```
