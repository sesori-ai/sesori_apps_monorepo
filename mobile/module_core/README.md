# Sesori Core (sesori_dart_core)

Pure Dart package containing all business logic, state management, services, and platform interfaces for the Sesori mobile client. Zero Flutter dependency — can be used from the Flutter app, a CLI, or any Dart environment.

See the [root README](../README.md) for the full monorepo overview.

## Key Exports

**Cubits**

| Cubit | Purpose |
|-------|---------|
| `LoginCubit` | OAuth sign-in flow, session restore |
| `ProjectListCubit` | Fetches and holds the project list |
| `SessionListCubit` | Fetches sessions for a project |
| `SessionDetailCubit` | Manages live session state, messages, and SSE updates |
| `ConnectionOverlayCubit` | Tracks relay connection status for the overlay widget |

**Services**

| Service | Purpose |
|---------|---------|
| `ProjectService` | CRUD operations for projects |
| `SessionService` | Session creation, listing, and message fetching |
| `ConnectionService` | Manages the relay WebSocket lifecycle |
| `RelayClient` | Low-level relay WebSocket client with E2E encryption |
| `SseEventRepository` | Buffers and dispatches SSE events from the relay |

**Concurrency** (re-exported from `sesori_shared`)

`SingleTaskIsolate`, `MultiTaskIsolate` — typed isolate wrappers with persistent and transient pool variants. `ConcurrentCache` — async-safe cache with per-key locking.

**Platform Interfaces**

These abstract interfaces are defined here and implemented by Flutter adapters in `app/lib/core/platform/`:

| Interface | Flutter Adapter |
|-----------|----------------|
| `SecureStorage` | `FlutterSecureStorageAdapter` |
| `UrlLauncher` | `FlutterUrlLauncher` |
| `DeepLinkSource` | `DeepLinkSource` (app_links) |
| `LifecycleSource` | `AppLifecycleObserver` |

**Routing**

`AppRoute` — enum of all named routes with path builders. `AuthRedirectService` — checks token state on startup to decide whether to skip the login screen.

**Logging**

`logd` / `logw` / `loge` — structured log helpers with a configurable `LogLevel`.

## DI Registration

```dart
import "package:sesori_dart_core/sesori_dart_core.dart";

// Must be called after platform adapters and auth module are registered:
configureCoreDependencies(getIt);
```

The auth module (`configureAuthDependencies`) must be initialized first. The full three-phase order is in `app/lib/core/di/injection.dart`.

## Testing

```bash
dart test
```

Pure Dart — no Flutter toolchain needed.

## Important

This module must not import `package:flutter`. Any Flutter-specific code belongs in `app/`. If you need a new platform capability, define an abstract interface here and implement it as a Flutter adapter in `app/lib/core/platform/`.
