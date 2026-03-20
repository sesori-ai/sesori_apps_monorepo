# Sesori Mobile

Monorepo for the Sesori mobile ecosystem. Connect to a running [OpenCode](https://github.com/anomalyco/opencode) server on your laptop via the encrypted relay and manage your coding sessions from your phone.

## Packages

| Package | Description |
|---------|-------------|
| [`sesori_auth`](sesori_auth/) | Authentication — token lifecycle, OAuth flow, authenticated HTTP client. Pure Dart. |
| [`sesori_dart_core`](sesori_dart_core/) | Pure Dart business logic — cubits, services, models, API clients. No Flutter dependency. |
| [`sesori_flutter`](sesori_flutter/) | Flutter UI shell — screens, widgets, routing, platform adapters. |

## Architecture

```
sesori_auth/          Authentication — standalone pure Dart package
  lib/src/
  ├── client/         AuthenticatedHttpApiClient (Bearer token decorator)
  ├── interfaces/     AuthTokenProvider, OAuthFlowProvider, AuthSession
  ├── models/         AuthState (freezed)
  ├── platform/       SecureStorage abstract interface
  ├── storage/        TokenStorageService, OAuthStorageService (internal)
  └── di/             Auth DI configuration

sesori_dart_core/     Pure Dart — shared by Flutter app and future CLI/TUI
  lib/src/
  ├── api/            HTTP clients (base, relay-routed), models, converters, parsing
  ├── capabilities/   Relay, server connection, project, session, voice API
  ├── concurrency/    Isolate pool, message queue, concurrent cache
  ├── cubits/         All state management (login, project_list, session_list, etc.)
  ├── di/             Core DI configuration (@InjectableInit)
  ├── extensions/     Dart utility extensions
  ├── logging/        logd/logw/loge helpers with configurable LogLevel
  ├── platform/       Abstract interfaces (UrlLauncher, DeepLinkSource, LifecycleSource)
  ├── reporting/      Error reporting
  └── routing/        AppRoute enum, AuthRedirectService

sesori_flutter/       Flutter UI shell
  lib/
  ├── capabilities/   Voice recording subsystem (Flutter-specific)
  ├── core/
  │   ├── di/         Flutter DI (registers platform adapters, calls auth + core init)
  │   ├── extensions/ BuildContext extensions (localization)
  │   ├── platform/   Platform adapters (FlutterSecureStorageAdapter, etc.)
  │   ├── routing/    GoRouter routes, deep link handling
  │   └── widgets/    Shared widgets (connection overlay, modal sheets)
  ├── features/       Screens (login, project_list, session_list, session_detail)
  └── l10n/           Localization (English)
```

## Relay connection

Sign in with your GitHub or Google account. The [Sesori Bridge CLI](https://github.com/sesori-ai/sesori_bridge) running on your laptop authenticates with the same account — the relay automatically groups both ends by account, so no QR code is needed. All traffic is end-to-end encrypted through the relay; the relay cannot read any data.

```
Phone ←──(E2E encrypted)──→ Relay Server ←──(E2E encrypted)──→ Bridge CLI → OpenCode server (localhost)
```

## Getting started

### Prerequisites

- Flutter SDK (Dart `^3.11.1`)
- iOS or Android device/emulator
- A running OpenCode server (local or via Sesori Bridge CLI)

### Run

```bash
cd sesori_flutter
flutter pub get
dart run build_runner build
flutter run
```

### Test

```bash
# Auth package
cd sesori_auth && dart test

# Core package
cd sesori_dart_core && dart test

# Flutter app
cd sesori_flutter && flutter test
```

### Code generation

All three packages use `freezed` for immutable models and `injectable` for DI. After modifying annotated classes:

```bash
cd sesori_auth && dart run build_runner build
cd sesori_dart_core && dart run build_runner build
cd sesori_flutter && dart run build_runner build
```

## Related

- [Sesori Bridge CLI](https://github.com/sesori-ai/sesori_bridge) — laptop-side bridge
- [Sesori Relay Server](https://github.com/sesori-ai/sesori_relay_server) — WebSocket relay
- [OpenCode (not affiliated with Sesori)](https://github.com/anomalyco/opencode) — the AI coding assistant
