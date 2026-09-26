# sesori_desktop — Flutter Desktop Product Shell

The desktop app shell (macOS/Windows/Linux). It wires DI, owns presentation
(window/tray composition), and implements concrete platform adapters. ALL
desktop business logic lives in `module_desktop_core` — never here.

## Target Package Structure (built out step by step — see `.plan/active/desktop-app/PLAN.md`)

```
lib/
├── core/platform/           # concrete implementations of module_core/module_desktop_core interfaces
├── core/di/                 # DI wiring (5-phase, see below)
├── core/routing/            # window/router composition
├── core/widgets/            # desktop-only presentation
├── app.dart                 # root widget
└── main.dart
```

## DI — 5-phase init (`lib/core/di/injection.dart`)

1. Register scope and `getIt.init()` — desktop platform capabilities
2. `configurePersistenceDependencies(getIt: getIt)` — shared SQL/crypto repositories
3. `configureAuthDependencies(getIt)` — auth module
4. `configureCoreDependencies(getIt)` — core module
5. `configureDesktopCoreDependencies(getIt)` — desktop core module

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
  `sesori_desktop_core` / `sesori_persistence` and live in `lib/core/platform/`. Adapters stay dumb —
  no process lifecycle or status state.
- May import `theme_prego` directly for shell-owned presentation and
  `module_app_ui` for shared localization, route presentation, settings/harness
  management, and adaptive UI. Desktop keeps DI, route callbacks, package/link
  strategies, and supervised logout composition.
- Never import bridge-workspace code (e.g. the bridge's OAuth browser opener);
  desktop equivalents go through platform adapters (ADR A11).
- Follow the repo-root `AGENTS.md` error-handling and naming rules.

## Shared Persistence

Bootstrap registers the build-mode scope explicitly and native master/directory
capabilities lazily before the shared persistence module. Auth/core consumers
use the same typed SQL/crypto repositories as mobile.
The persistence directory reuses `DesktopApplicationSupportDirectory` without
moving logs, helper state or other desktop files. macOS uses the new master-item
service in classic Keychain mode; Windows/Linux keep existing native plugin
protection and use the scoped logical master key. No desktop legacy importer or
automatic credential cleanup is added. Primary-process admission remains before
storage I/O. Desktop is unpublished: sign out in an old per-value-storage build
before replacing it, then sign in once. New-store logout cannot revoke an old
build's separate session.

## Commands

```bash
flutter test                       # from this dir
dart analyze --fatal-infos
flutter build macos|windows|linux
flutter run -d macos               # dev run
```
