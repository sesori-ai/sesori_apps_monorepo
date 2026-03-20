# AGENTS.md — Sesori Apps Monorepo

## Monorepo Layout

- `bridge/` — pure Dart CLI workspace (relay server + plugin system)
- `mobile/` — Flutter workspace (mobile client)
- `shared/sesori_shared/` — pure Dart, shared crypto and protocol types

Two independent Dart workspaces. `shared/sesori_shared` is consumed via path dependency by both.

## Workspace Commands

Run `dart pub get` from the workspace root, not from individual module dirs:

```sh
cd bridge && dart pub get
cd mobile && dart pub get
```

Bridge workspace also exposes:

```sh
cd bridge
make codegen   # runs build_runner across all bridge modules
make test      # runs dart test across all bridge modules
make analyze   # runs dart analyze across all bridge modules
```

## Generated Files

Never edit `*.freezed.dart`, `*.g.dart`, or `*.config.dart` by hand.

After modifying a `@freezed` class, regenerate from the module dir:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Git

Conventional commits: `fix:`, `feat:`, `ci:`, `docs:`, `chore:`.

Branch naming: `type/short-description` (e.g. `feat/relay-reconnect`).

## Testing

| Location | Command |
|---|---|
| bridge modules | `dart test` |
| mobile/app | `flutter test` |
| mobile pure Dart modules | `dart test` |

## Analysis

Strict analysis is enabled across all packages. Don't add `// ignore:` comments without a written justification in the same line.

## Forbidden

- Don't modify `shared/sesori_shared` without considering impact on both bridge and mobile consumers.
- Don't create a root-level `pubspec.yaml`. There is no root workspace.
