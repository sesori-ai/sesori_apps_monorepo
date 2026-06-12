# Sesori Mobile

Flutter workspace containing the Sesori mobile client — an app that connects to the Bridge to interact with AI coding sessions on the go.

## Modules

| Module | Purpose |
|--------|---------|
| `app/` | Flutter UI shell. Screens, routing, DI setup, platform adapters. All business logic delegates to `module_core`. |
| `module_core/` | Pure Dart business logic. Zero Flutter dependency. Cubits, services, relay client, platform interfaces. |
| `module_auth/` | Authentication. OAuth PKCE flow, token refresh, authenticated HTTP client. |

## Architecture

**Dependency direction**: `app` -> `module_core` -> `module_auth` -> `sesori_shared`. Never reverse, never skip layers.

```
app/
  lib/
  ├── core/
  │   ├── di/         DI setup — 3-phase init (platform → auth → core)
  │   ├── routing/    GoRouter routes, deep link handling
  │   └── widgets/    Shared widgets (ConnectionOverlay, modal sheets)
  └── features/       Screens: Login, ProjectList, SessionList, SessionDetail

module_core/
  lib/src/
  ├── cubits/         LoginCubit, ProjectListCubit, SessionListCubit, SessionDetailCubit, ConnectionOverlayCubit
  ├── services/       ProjectService, SessionService, ConnectionService
  ├── relay/          RelayClient (WebSocket relay connection)
  └── platform/       Abstract interfaces (UrlLauncher, DeepLinkSource, LifecycleSource)

module_auth/
  lib/src/
  ├── auth_manager/   AuthManager — owns token lifecycle, OAuth flow, auth state
  ├── client/         AuthenticatedHttpApiClient (Bearer token + 401 retry)
  ├── interfaces/     AuthTokenProvider, OAuthFlowProvider, AuthSession
  └── storage/        TokenStorageService
```

### DI initialization (3 phases)

Defined in `app/lib/core/di/injection.dart`, called once from `main()`:

1. `getIt.init()` — Flutter platform deps (SecureStorage, http.Client, platform adapters)
2. `configureAuthDependencies(getIt)` — auth module deps
3. `configureCoreDependencies(getIt)` — core module deps

### State management

BLoC/Cubit throughout. Cubits live in `module_core` (pure Dart, testable without Flutter). Widgets in `app/` consume them via `BlocProvider`.

### Authentication

`AuthManager` in `module_auth` is the single owner of token state. It implements three narrow interfaces consumed by the rest of the app:

- `AuthTokenProvider` — fresh token access for WebSocket auth
- `OAuthFlowProvider` — drives OAuth PKCE login
- `AuthSession` — auth state stream, logout, current user

## Prerequisites

- Flutter 3.41.4-stable via [asdf](https://asdf-vm.com/) (`.tool-versions` at workspace root)

## Getting started

```bash
# Install dependencies for all modules
dart pub get   # run from mobile/

# Run the app
cd app && flutter run
```

## Testing

```bash
cd app && flutter test
cd module_core && dart test
cd module_auth && dart test
```

## Code generation

After modifying `freezed` models or `injectable`-annotated classes, run from each affected module:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Related

- [Bridge workspace](../bridge/README.md) — laptop-side CLI and plugin system in this monorepo

## License

This workspace is source-available under the Functional Source License, Version 1.1, Apache 2.0 Future License (`FSL-1.1-ALv2`).

You may use it for permitted purposes, but you may not use it to launch a competing product or service.

On the second anniversary of the date this version is made available, it automatically becomes available under Apache License 2.0.

See the repo root [LICENSE](../LICENSE) for the full terms.
