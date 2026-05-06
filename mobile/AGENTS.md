# Mobile Workspace — Agent Rules

This file covers mobile-specific guidance. For general architecture, layering, class suffixes, cohesion rules, commit discipline, and review workflow, see the repo-root `AGENTS.md`.

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
app → module_core → module_auth → sesori_shared
```

NEVER reverse this. NEVER skip layers. `app` has `module_auth` as a pubspec dependency solely for the `configureAuthDependencies(getIt)` DI call — it MUST NOT import `module_auth` types in source code. All auth functionality is accessed through `module_core` interfaces.

## Testing

- `flutter test` from `app/`
- `dart test` from `module_core/` and `module_auth/`
- Cubits in `module_core/` must be testable without Flutter. Use fake streams and fake services, not `WidgetTester`.

## DI

3-phase init in `app/lib/core/di/injection.dart`:

1. `getIt.init()` — Flutter platform adapters
2. `configureAuthDependencies(getIt)` — auth module
3. `configureCoreDependencies(getIt)` — core module

New services register in their module's `configure*Dependencies()` function, not in `app/`. Respect the init order — a core service cannot depend on something that hasn't been registered yet.

## State Management

BLoC/Cubit only. Cubits live in `module_core/lib/src/cubits/`, never in `app/`. Cubits are NOT registered in DI — construct them in `BlocProvider(create:)`, resolving their service dependencies via `getIt<>()` inside the create closure.

Splash/startup cubits must stay local-only and fast. Do not call auth-server validation (`/auth/me`), token refresh, relay connection, or any other network operation from splash. Splash may only inspect locally stored auth state/tokens to choose the initial route; destination screens/services own network validation and error handling.

Cubits orchestrate: they call services/repositories and emit state. They MUST NOT:
- Import from `api/` (go through a repository or service)
- Perform HTTP calls directly
- Depend on other cubits
- Hold business logic that belongs in a Service

For reactive state (connection, SSE events), cubits subscribe to streams exposed by `ConnectionService`. Never poll.

## Class Suffix Guidance

Root `AGENTS.md` has the full suffix vocabulary. Concrete mobile examples:

- **Platform abstractions** (in `module_core/foundation/platform/`) are interfaces named by capability: `UrlLauncher`, `DeepLinkSource`, `LifecycleSource`, `RouteSource`, `NotificationCanceller`
- **Platform implementations** (in `app/core/platform/`) use `Adapter` or `Flutter*` prefix for the concrete Flutter version: `FlutterSecureStorageAdapter`, `FlutterUrlLauncher`, `AppLifecycleObserver`, `AppLinksDeepLinkSource`, `GoRouterRouteSource`
- **Transport Layer 0** uses `Client` / `Service`: `RelayClient` (raw WebSocket), `ConnectionService` (lifecycle + reconnect), `RelayHttpApiClient` (HTTP-over-relay)
- **Layer 1 APIs** use `Api`: `SessionApi`, `ProjectApi`, `VoiceApi`, `NotificationApi`
- **Layer 2 Repositories** use `Repository`: `SessionRepository`, `ProjectRepository`, `NotificationPreferencesRepository`
- **Layer 3 Services** use `Service`: `SseEventService`, `AuthRedirectService`
- **Layer 4 State** uses `Cubit`: `SessionListCubit`, `ProjectListCubit`, `LoginCubit`

If a class doesn't fit one of these, reconsider its responsibilities before labeling it `Manager`, `Helper`, or `Wrapper`.

## Feature Checklist

Adding a new feature follows the same shape every time:

1. **API** (if new endpoint): add a class in `module_core/lib/src/api/<thing>_api.dart` using the correct transport (`RelayHttpApiClient` for bridge, `AuthenticatedHttpApiClient` for auth server).
2. **Repository**: add `module_core/lib/src/repositories/<thing>_repository.dart`, even if it only delegates to one API. Map API DTOs to internal models here.
3. **Service** (only if there's real orchestration or business logic): add in `module_core/lib/src/services/`. Otherwise, the Cubit talks to the repository directly.
4. **Cubit**: add a folder under `module_core/lib/src/cubits/<feature>/` with the cubit and its state class. Subscribe to streams in the constructor, cancel subscriptions in `close()`.
5. **DI**: register new services/repositories/APIs in `module_core`'s `configureCoreDependencies`.
6. **Screen**: add `app/lib/features/<feature>/` with the screen widget. Wire the cubit via `BlocProvider(create: (_) => MyCubit(getIt(), getIt()))`.
7. **Route** (if new route): add the enum value to `AppRoute` in `module_core/lib/src/routing/`, then the route config in `app/lib/core/routing/`.

Screens NEVER instantiate services or call APIs directly. They consume cubit state via `BlocBuilder` / `BlocListener` and dispatch intents via cubit methods.

## Platform Abstraction

If a feature needs a platform capability not already abstracted:

1. Define an abstract interface in `module_core/lib/src/foundation/platform/<capability>.dart`
2. Implement it in `app/lib/core/platform/flutter_<capability>.dart`
3. Register the implementation in DI phase 1 (`getIt.init()`)
4. Consume it from `module_core` via the interface — never reach for `package:flutter` from `module_core`

There is ONE production implementation per interface. Do not add factories, alternatives, or abstract factories unless there is a real second implementor (e.g., a test fake is NOT a second implementor — see "No Pointless Interfaces" philosophy in the bridge AGENTS.md; `implements` works on any class in Dart 3).

## Forbidden

- `module_core` MUST NOT import `package:flutter`. It is pure Dart and must remain testable without Flutter.
- `module_auth` MUST NOT import `module_core`. Dependencies never flow upward.
- `app` MUST NOT import `module_auth` types in source code (the pubspec dep exists only for DI wiring).
- Do NOT edit `*.freezed.dart`, `*.g.dart`, or `*.config.dart` — these are generated.
- Do NOT instantiate cubits in DI. Construct them in `BlocProvider(create:)`.
- Do NOT add state-management libraries other than BLoC/Cubit.

## Definition of Done

- `dart pub get` exits 0 from `mobile/`
- `dart analyze` exits 0 in all three modules
- All tests pass (`flutter test` for `app/`, `dart test` for `module_core/` and `module_auth/`)

## Per-Module Details

- [`app/AGENTS.md`](app/AGENTS.md) — Flutter shell conventions, routing, widget patterns
- [`module_core/AGENTS.md`](module_core/AGENTS.md) — pure Dart conventions, cubit/service patterns
- [`module_auth/AGENTS.md`](module_auth/AGENTS.md) — auth package public API, token lifecycle
