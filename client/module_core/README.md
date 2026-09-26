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

**Repositories**

| Repository | Purpose |
|------------|---------|
| `SessionRepository` | Session creation, listing, mutation, and message fetching |

**Services and capabilities**

| Component | Purpose |
|-----------|---------|
| `ConnectionService` | Manages the relay WebSocket lifecycle |
| `RelayClient` | Low-level relay WebSocket client with E2E encryption |
| `SseEventTracker` | Tracks SSE events from the relay: project activity, session activity, and project timestamp updates |

**Platform Interfaces**

These abstract interfaces are defined here and implemented by Flutter adapters in `app/lib/core/platform/`:

| Interface | Flutter Adapter |
|-----------|----------------|
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

// After platform → configurePersistenceDependencies → configureAuthDependencies:
configureCoreDependencies(getIt);
```

Shared persistence registers before auth, which registers before core. Shells
supply `PersistenceScope`, `MasterKeyStore` and `PersistenceDirectory` from
`sesori_persistence`; core consumes its typed `PersisterRepository` and
`SecureStorageRepository`, retaining domain keys and serialization here.
Production mobile awaits the isolated deprecated import before consumers;
development and desktop do not invoke it. See `app/lib/core/di/injection.dart`
and `desktop/lib/core/di/injection.dart` for complete composition.

## Testing

```bash
dart test
```

Pure Dart — no Flutter toolchain needed.

## Important

This module must not import `package:flutter`. Any Flutter-specific code belongs in `app/`. If you need a new platform capability, define an abstract interface here and implement it as a Flutter adapter in `app/lib/core/platform/`.
