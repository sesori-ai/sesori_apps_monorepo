# sesori_dart_core — Pure Dart Package

Business logic, state management, services, and models for the Sesori ecosystem. Zero Flutter SDK dependency — usable from both the Flutter app and a future CLI/TUI tool.

## Error Handling

**Never silently swallow** (see the repo-root `AGENTS.md`): a `catch` that swallows and continues (no-op/best-effort) must log, and a catch-all especially. But don't double-log when the catch already surfaces the failure (rethrows, or returns/yields an explicit failure the caller renders). Pass the error as the logger argument (`Log.w("msg", error, st)`), don't string-interpolate it.

## Package Structure

```
lib/src/
├── api/              HTTP clients (base, relay-routed), models, converters, parsing
├── capabilities/     Domain services
│   ├── project/      ProjectService
│   ├── relay/        RelayClient, RoomKeyStorage, relay config
│   ├── server_connection/  ConnectionService, SSE models, connection status
│   ├── session/      SessionService
│   └── voice/        VoiceApi (HTTP calls only — recording stays in Flutter)
├── concurrency/      Isolate pool, message queue, concurrent cache
├── cubits/           All state management (login, project_list, session_list, etc.)
├── di/               @InjectableInit for core DI registration
├── extensions/       Dart utility extensions (sugar_dart, iterable_x)
├── logging/          logd/logw/loge with configurable LogLevel
├── platform/         Abstract interfaces: UrlLauncher, DeepLinkSource, LifecycleSource
├── reporting/        Error reporting helpers
└── routing/          AppRoute enum, AuthRedirectService
```

## Conventions

- Pure Dart only — NO `package:flutter*` imports
- `package:bloc` for cubits (NOT `flutter_bloc`)
- `package:meta` for `@visibleForTesting` (NOT `package:flutter/foundation.dart`)
- Relative imports within this package; `package:sesori_dart_core/...` from external code
- `@lazySingleton` for services; cubits are NOT registered in DI
- Public named parameters use `required` even when nullable. Prefer `required String? value` over optional named nullable parameters so call sites must pass intent explicitly.
- **Service request bodies use shared Freezed models** — when a service method sends a POST/PUT body to the bridge, serialize with a Freezed class from `sesori_shared`: `FooRequest(field: value).toJson()`. Never use inline `{"key": value}` maps.

## Platform Interfaces

The core package defines abstract interfaces that each platform must implement:

- `SecureStorage` — key-value secure storage (defined in `sesori_auth`, re-exported by core; Flutter: `flutter_secure_storage`, CLI: OS keyring)
- `UrlLauncher` — open URLs in browser (Flutter: `url_launcher`, CLI: `Process.run("open", ...)`)
- `DeepLinkSource` — stream of incoming deep link URIs (Flutter: `app_links`, CLI: unused)
- `LifecycleSource` — app lifecycle state stream (Flutter: `AppLifecycleObserver`)

## DI Initialization

```dart
// Called by the platform (Flutter app, CLI, etc.)
// Order matters: platform → auth → core
configureAuthDependencies(getIt);  // from sesori_auth
configureCoreDependencies(getIt);  // from sesori_dart_core
```

Platform must register implementations of `SecureStorage`, `UrlLauncher`, `DeepLinkSource`, and `LifecycleSource` before calling auth/core init. Auth DI must run before core DI (core depends on auth interfaces).

## Logging

```dart
setLogLevel(LogLevel.debug);  // Per-isolate, defaults from dart.vm.product
logd("debug message");
loge("error", error, stackTrace);
```

## Testing

- Use `package:test`, NOT `package:flutter_test`
- Use `mocktail` for mocks
- Mock `SecureStorage`/`UrlLauncher` interfaces — never concrete Flutter types
