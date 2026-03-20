# sesori_dart_core

Pure Dart package containing all business logic, state management, services, and models for the Sesori ecosystem. Zero Flutter SDK dependency — shared by the Flutter app and future CLI/TUI tools.

See the [root README](../README.md) for the full monorepo overview.

## Usage

Add as a path dependency:

```yaml
dependencies:
  sesori_dart_core:
    path: ../sesori_dart_core
```

Initialize from your platform entry point:

```dart
import "package:sesori_dart_core/sesori_dart_core.dart";

// Register platform implementations first (SecureStorage, UrlLauncher, etc.)
// Then initialize core DI:
configureCoreDependencies(getIt);
```

## What's inside

- **Cubits** — login, project list, session list, session detail, connection overlay
- **Services** — auth, project, session, voice API, connection management, relay client
- **API layer** — HTTP clients (direct + relay-routed), models, converters, JSON parsing
- **Models** — auth state, connection status, SSE events, server config
- **Concurrency** — isolate pool, message queue, concurrent cache
- **Platform interfaces** — `SecureStorage`, `UrlLauncher`, `DeepLinkSource`
- **Logging** — `logd`/`logw`/`loge` with configurable `LogLevel`

## Test

```bash
dart test
```
