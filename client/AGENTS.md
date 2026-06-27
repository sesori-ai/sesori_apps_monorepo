# Client Workspace — Agent Rules

This file covers client-specific guidance for the mobile app, future desktop app,
and shared client modules. For general architecture, layering, class suffixes,
cohesion rules, commit discipline, and review workflow, see the repo-root
`AGENTS.md`.

## Commands

```bash
dart pub get                                              # from client/ — installs all modules
dart analyze                                              # run per module (app/, module_core/, module_auth/, and module_desktop_core/ when present)
cd app && flutter test                                    # Flutter tests
cd desktop && flutter test                                # desktop Flutter tests, when present
cd module_core && dart test                               # pure Dart tests
cd module_auth && dart test                               # pure Dart tests
cd module_desktop_core && dart test                       # pure Dart tests, when present
dart run build_runner build --delete-conflicting-outputs  # per module, after modifying annotated classes
```

## Module Dependency Direction

```
client/app ───────────────→ module_app_ui ─┐
     │                                      │
     └──────────────────────────────────────┴→ module_core → module_auth → sesori_shared
     │
     └→ module_prego

client/desktop ───────────→ module_app_ui ─┐
     │                                      │
     ├──────────────────────────────────────┴→ module_core → module_auth → sesori_shared
     │
     └→ module_desktop_core ─────────────────→ module_core
     │                         │
     │                         └→ sesori_shared
     └→ module_prego
```

NEVER reverse this. NEVER skip layers. `client/app` and `client/desktop` may
have `module_auth` as a pubspec dependency solely for the
`configureAuthDependencies(getIt)` DI call — they MUST NOT import `module_auth`
types in source code outside that DI call. All auth functionality is accessed
through `module_core` interfaces. `module_core` MUST NOT depend on
`module_desktop_core`. Product shells may import `module_prego` directly for
shell-owned presentation.

## Testing

- `flutter test` from `app/`
- `dart test` from `module_core/` and `module_auth/`
- `flutter test` from `desktop/` and `dart test` from `module_desktop_core/` when those packages exist or are touched
- Cubits in `module_core/` and `module_desktop_core/` must be testable without Flutter. Use fake streams and fake services, not `WidgetTester`.

## DI

3-phase init in `app/lib/core/di/injection.dart`:

1. `getIt.init()` — Flutter platform adapters
2. `configureAuthDependencies(getIt)` — auth module
3. `configureCoreDependencies(getIt)` — core module

New services register in their module's `configure*Dependencies()` function, not in `app/`. Respect the init order — a core service cannot depend on something that hasn't been registered yet.

Desktop uses the same first three phases, then configures desktop core:

1. Desktop platform adapters for `module_core` and `module_desktop_core`
2. `configureAuthDependencies(getIt)`
3. `configureCoreDependencies(getIt)`
4. `configureDesktopCoreDependencies(getIt)`

Desktop services register in `module_desktop_core`, not in `client/desktop`.

## State Management

BLoC/Cubit only. Mobile cubits live in `module_core/lib/src/cubits/`; desktop
cubits live in `module_desktop_core/lib/src/cubits/`. Cubits never live in
Flutter product shells (`client/app` or `client/desktop`). Cubits are NOT
registered in DI — construct them in `BlocProvider(create:)`, resolving their
service dependencies via `getIt<>()` inside the create closure.

Splash/startup cubits must stay local-only and fast. Do not call auth-server validation (`/auth/me`), token refresh, relay connection, or any other network operation from splash. Splash may only inspect locally stored auth state/tokens to choose the initial route; destination screens/services own network validation and error handling.

Cubits orchestrate: they call services/repositories and emit state. They MUST NOT:

- Import from `api/` (go through a repository or service)
- Perform HTTP calls directly
- Depend on other cubits
- Hold business logic that belongs in a Service

For reactive state (connection, SSE events), cubits subscribe to streams exposed by `ConnectionService`. Never poll.

## Class Suffix Guidance

Root `AGENTS.md` has the full suffix vocabulary. Concrete client examples:

- **Platform abstractions** (in `module_core/foundation/platform/`) are interfaces named by capability: `UrlLauncher`, `DeepLinkSource`, `LifecycleSource`, `RouteSource`, `NotificationCanceller`
- **Platform implementations** (in `app/core/platform/`) use `Adapter` or `Flutter*` prefix for the concrete Flutter version: `FlutterSecureStorageAdapter`, `FlutterUrlLauncher`, `AppLifecycleObserver`, `AppLinksDeepLinkSource`, `GoRouterRouteSource`
- **Transport Layer 0** uses `Client` / `Service`: `RelayClient` (raw WebSocket), `ConnectionService` (lifecycle + reconnect), `RelayHttpApiClient` (HTTP-over-relay)
- **Layer 1 APIs** use `Api`: `SessionApi`, `ProjectApi`, `VoiceApi`, `NotificationApi`
- **Layer 2 Repositories** use `Repository`: `SessionRepository`, `ProjectRepository`, `NotificationPreferencesRepository`
- **Layer 3 Services** use `Service`: `SseEventService`, `AuthRedirectService`
- **Layer 4 State** uses `Cubit`: `SessionListCubit`, `ProjectListCubit`, `LoginCubit`
- **Desktop Layer 0 capabilities** live in `module_desktop_core/foundation/platform/`: `SystemTray`, `WindowHost`, `LaunchAtLogin`, `AppUpdater`
- **Desktop process supervision** lives in `module_desktop_core`: `BridgeProcessRepository`, `BridgeProcessService`, `BridgeStatusTracker`, `BridgeControlCubit`

If a class doesn't fit one of these, reconsider its responsibilities before labeling it `Manager`, `Helper`, or `Wrapper`.

## Feature Checklist

Adding a new mobile feature follows the same shape every time:

1. **API** (if new endpoint): add a class in `module_core/lib/src/api/<thing>_api.dart` using the correct transport (`RelayHttpApiClient` for bridge, `AuthenticatedHttpApiClient` for auth server).
2. **Repository**: add `module_core/lib/src/repositories/<thing>_repository.dart`, even if it only delegates to one API. Map API DTOs to internal models here.
3. **Service** (only if there's real orchestration or business logic): add in `module_core/lib/src/services/`. Otherwise, the Cubit talks to the repository directly.
4. **Cubit**: add a folder under `module_core/lib/src/cubits/<feature>/` with the cubit and its state class. Subscribe to streams in the constructor, cancel subscriptions in `close()`.
5. **DI**: register new services/repositories/APIs in `module_core`'s `configureCoreDependencies`.
6. **Screen**: add `app/lib/features/<feature>/` with the screen widget. Wire the cubit via `BlocProvider(create: (_) => MyCubit(getIt(), getIt()))`.
7. **Route** (if new route): add the enum value to `AppRoute` in `module_core/lib/src/routing/`, then the route config in `app/lib/core/routing/`.

Screens NEVER instantiate services or call APIs directly. They consume cubit state via `BlocBuilder` / `BlocListener` and dispatch intents via cubit methods.

Adding a desktop-specific feature follows the same shape inside
`module_desktop_core`: API/storage/process boundary → repository/tracker →
service when orchestration is needed → cubit. `client/desktop` only wires the
cubit into Flutter widgets and provides concrete platform adapters.

## Platform Abstraction

If a mobile feature needs a platform capability not already abstracted:

1. Define an abstract interface in `module_core/lib/src/foundation/platform/<capability>.dart`
2. Implement it in `app/lib/core/platform/flutter_<capability>.dart`
3. Register the implementation in DI phase 1 (`getIt.init()`)
4. Consume it from `module_core` via the interface — never reach for `package:flutter` from `module_core`

There is ONE production implementation per interface **per product/platform**.
Mobile adapters live in `client/app`; desktop adapters for shared `module_core`
interfaces live in `client/desktop`. Do not add factories, alternatives, or
abstract factories unless there is a real second production implementor for the
same product/platform (e.g., a test fake is NOT a second implementor — see "No
Pointless Interfaces" philosophy in the bridge AGENTS.md; `implements` works on
any class in Dart 3).

Desktop-only platform capabilities are defined in
`module_desktop_core/lib/src/foundation/platform/` and implemented in
`desktop/lib/core/platform/`. Do not put tray, window, updater, bridge-process,
or single-instance business logic in `client/desktop`.

## Error Handling

**Never silently swallow.** The target is a `catch` that discards an error and continues with no trace (`catch (e) { /* no-op */ }`). A handler that swallows and continues (no-op/best-effort cleanup included) must log, and a catch-all (`on Object catch`/`catch (e)`) especially, since the cause is unknown. But do NOT add a redundant log when the catch already surfaces the failure — rethrows, throws a typed exception, or returns/yields an explicit failure the caller renders — that just double-logs. When you log a caught error, pass it as the logger argument (`Log.w("msg", error, stackTrace)`), don't string-interpolate it.

## Forbidden

- `module_core` MUST NOT import `package:flutter`. It is pure Dart and must remain testable without Flutter.
- `module_desktop_core` MUST NOT import `package:flutter`. It is pure Dart and must remain testable without Flutter.
- `module_auth` MUST NOT import `module_core`. Dependencies never flow upward.
- `app` and `desktop` MUST NOT import `module_auth` types in source code outside DI wiring.
- `client/desktop` MUST NOT contain bridge process services, repositories, control dispatchers, or cubits; those belong in `module_desktop_core`.
- Do NOT edit `*.freezed.dart`, `*.g.dart`, or `*.config.dart` — these are generated.
- Do NOT instantiate cubits in DI. Construct them in `BlocProvider(create:)`.
- Do NOT add state-management libraries other than BLoC/Cubit.

## Git

- Never use `git commit --amend` in the client workspace. If follow-up changes are needed after a commit, create a new commit instead.

## Definition of Done

- `dart pub get` exits 0 from `client/`
- `dart analyze` exits 0 in touched modules
- All relevant tests pass (`flutter test` for product shells, `dart test` for pure Dart modules)

## Per-Module Details

- [`app/AGENTS.md`](app/AGENTS.md) — Flutter shell conventions, routing, widget patterns
- [`module_core/AGENTS.md`](module_core/AGENTS.md) — pure Dart conventions, cubit/service patterns
- [`module_auth/AGENTS.md`](module_auth/AGENTS.md) — auth package public API, token lifecycle
- `desktop/AGENTS.md` and `module_desktop_core/AGENTS.md` should be added when those packages are created.
