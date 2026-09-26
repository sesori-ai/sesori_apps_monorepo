# sesori_dart_core — Pure Dart Package

Business logic, state management, services, and models for the Sesori ecosystem. Zero Flutter SDK dependency — usable from both the Flutter app and a future CLI/TUI tool.

## Error Handling

**Never silently swallow** (see the repo-root `AGENTS.md`): a `catch` that swallows and continues (no-op/best-effort) must log, and a catch-all especially. But don't double-log when the catch already surfaces the failure (rethrows, or returns/yields an explicit failure the caller renders). Pass the error as the logger argument (`Log.w("msg", error, st)`), don't string-interpolate it.

## Package Structure

```
lib/src/
├── api/              HTTP clients (base, relay-routed), models, converters, parsing
├── capabilities/     Domain services
│   ├── relay/        RelayClient, RoomKeyStorage, relay config
│   ├── server_connection/  ConnectionService, SSE models, connection status
│   └── voice/        VoiceApi (HTTP only; native capture stays behind the Flutter-implemented VoiceCapture contract)
├── cubits/           All state management (login, project_list, session_list, etc.)
├── di/               @InjectableInit for core DI registration
├── foundation/       Platform interfaces and shared models (analytics, composer)
├── logging/          logd/logw/loge with configurable LogLevel
├── migrations/       Isolated deprecated upgrade compatibility; never a runtime storage backend
├── platform/         Abstract interfaces (UrlLauncher, DeepLinkSource, LifecycleSource,
│                  RouteSource, NotificationCanceller, …); Flutter adapters live in
│                  the product shell, mostly under app/lib/core/platform/
├── repositories/     API mapping and domain-facing data operations
├── routing/          AppRoute enum, AuthRedirectService
└── services/         Cross-repository orchestration and lifecycle owners, including per-composer voice sessions
```

## Conventions

- Pure Dart only — NO `package:flutter*` imports
- `package:bloc` for cubits (NOT `flutter_bloc`)
- `package:meta` for `@visibleForTesting` (NOT `package:flutter/foundation.dart`)
- Relative imports within this package; `package:sesori_dart_core/...` from external code
- `@lazySingleton` for services; cubits are NOT registered in DI
- Public named parameters use `required` even when nullable. Prefer `required String? value` over optional named nullable parameters so call sites must pass intent explicitly.
- **Service request bodies use shared Freezed models** — when a service method sends a POST/PUT body to the bridge, serialize with a Freezed class from `sesori_shared`: `FooRequest(field: value).toJson()`. Never use inline `{"key": value}` maps.
- A coalesced staleness signal is consumed only after the resulting snapshot is successfully applied. Failed or connection-blocked refreshes preserve and re-arm prior staleness without discarding newer signals that arrived in flight.

## Platform Interfaces

The core package defines abstract interfaces that each platform must implement:

- `UrlLauncher` — open URLs in browser (Flutter: `url_launcher`, CLI: `Process.run("open", ...)`)
- `DeepLinkSource` — stream of incoming deep link URIs (Flutter: `app_links`, CLI: unused)
- `LifecycleSource` — app lifecycle state stream (Flutter: `AppLifecycleObserver`)

## DI Initialization

```dart
// Called by the platform (Flutter app, CLI, etc.)
// Order matters: platform → persistence → auth → core
configurePersistenceDependencies(getIt: getIt); // from sesori_persistence
configureAuthDependencies(getIt);              // from sesori_auth
configureCoreDependencies(getIt);              // from sesori_dart_core
```

Platform registers persistence's `MasterKeyStore`, `PersistenceDirectory` and
`PersistenceScope`, plus core's `UrlLauncher`, `DeepLinkSource` and `LifecycleSource`.
Shared persistence DI precedes auth, which precedes core. Normal core consumers
use typed `PersisterRepository`/`SecureStorageRepository` from the persistence
public barrel; keys and serialization remain core-owned.

## Temporary Mobile Storage Import

`migrations/deprecated_native_storage_v1/` contains the explicitly deprecated,
layered importer and its removal checklist. Core DI registers it lazily;
production-mobile bootstrap awaits it after registration and before analytics,
auth restoration or preferences. Development and desktop never resolve it.
Shared storage remains below core in `module_persistence`; permanent domain
keys live in `foundation/persistence/`. The migration service logs import failure,
resets destination secrets/preferences and the old native namespace, then attempts
to mark migration handled before allowing normal logged-out startup. It records
false in the existing completion key before destruction and retains it atomically
while clearing preferences. False retries only reset on relaunch, never import.
Incomplete recovery blocks secret use through the existing repository cache owner;
normal login UI continues but credential writes fail until recovery can finish.
The shell installs the file sink first; recovery diagnostics retain native/SQL
causes while excluding parser source buffers. Normal account analytics rules apply.

## Logging

```dart
setLogLevel(LogLevel.debug);  // Per-isolate, defaults from dart.vm.product
logd("debug message");
loge("error", error, stackTrace);
```

## Testing

- Use `package:test`, NOT `package:flutter_test`
- Use `mocktail` for mocks
- Mock typed persistence repositories and `UrlLauncher` — never concrete Flutter types
