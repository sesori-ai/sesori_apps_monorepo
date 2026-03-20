# Bridge Workspace — Agent Rules

## Commands

From `bridge/`:
- `dart pub get` — install dependencies for the workspace
- `make codegen` — regenerate Freezed/JSON files across all modules
- `make test` — run tests in all modules that have a `test/` directory
- `make analyze` — static analysis across all modules

From `bridge/app/`:
- `make build` — build all targets (host-native + Linux cross-compiled)
- `make build-host` — native binary only
- `make build-linux` — Linux cross-compiled binaries only

## Module Order

Dependencies flow in one direction:

1. `sesori_plugin_interface` — no internal deps; defines the contract
2. `sesori_plugin_opencode` — depends on interface + `sesori_shared`
3. `app` — depends on both plugin packages + `sesori_shared`

When changing shared types, update in this order.

## Forbidden

- Don't edit `*.freezed.dart` or `*.g.dart` — these are generated; run `make codegen` instead.
- Don't modify `sesori_plugin_interface` without checking all implementors (`sesori_plugin_opencode` and any others).
- Don't add Flutter dependencies — this is a pure Dart workspace.
- Don't modify `sesori_shared` from here; it lives in the monorepo root and is shared with the mobile app.

## Testing

- `dart test` from `app/` and `sesori_plugin_opencode/`
- `sesori_plugin_interface` has no tests (it's a contract package)

## Conventions

- Freezed models use `build.yaml` options: `format: false`, `map: false`, `when: false`
- Plugin implementations must implement all 8 `BridgePlugin` methods — no partial implementations
- SSE events use sealed classes (see `bridge_sse_event.dart`)

## Definition of Done

- `dart pub get` exits 0
- `make analyze` exits 0
- `make test` all pass
