# Mobile Workspace — Agent Rules

## Commands

```bash
dart pub get                                              # from mobile/ — installs all modules
dart analyze                                              # run per module (app/, module_core/, module_auth/)
cd app && flutter test                                    # Flutter tests
cd module_core && dart test                               # pure Dart tests
cd module_auth && dart test                               # pure Dart tests
dart run build_runner build --delete-conflicting-outputs  # per module, after modifying annotated classes
```

## Module Dependency Direction

```
app -> module_core -> module_auth -> sesori_shared
```

NEVER reverse this. NEVER skip layers. `app` does not import `module_auth` directly.

## Forbidden

- `module_core` MUST NOT import `package:flutter`. It is pure Dart.
- `module_auth` MUST NOT import `module_core`.
- Do NOT edit `*.freezed.dart`, `*.g.dart`, or `*.config.dart` — these are generated.

## DI

3-phase init in `app/lib/core/di/injection.dart`:

1. `getIt.init()` — Flutter platform deps
2. `configureAuthDependencies(getIt)` — auth module
3. `configureCoreDependencies(getIt)` — core module

New services register in their module's `configure*Dependencies()` function, not in `app/`.

## State Management

BLoC/Cubit only. New features: add a Cubit in `module_core/`, add a UI widget in `app/`. Cubits are NOT registered in DI — construct them in `BlocProvider(create:)`.

## File Size
- Maximum file length: 250 lines per file
- If a file exceeds 250 lines, split it into smaller focused files (by use-case, component, or concern)
- Prefer many small files over few large files

## Definition of Done

- `dart pub get` exits 0 from `mobile/`
- `dart analyze` exits 0 in all three modules
- All tests pass (`flutter test` for `app/`, `dart test` for `module_core/` and `module_auth/`)

## Per-Module Details

- [`app/AGENTS.md`](app/AGENTS.md) — Flutter shell conventions, routing, widget patterns
- [`module_core/AGENTS.md`](module_core/AGENTS.md) — pure Dart conventions, cubit/service patterns
- [`module_auth/AGENTS.md`](module_auth/AGENTS.md) — auth package public API, token lifecycle
