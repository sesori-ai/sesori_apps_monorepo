# sesori_flutter — Flutter App

Thin UI shell for the Sesori mobile client. All business logic, state management, and services live in `sesori_dart_core` — this package provides screens, widgets, routing, and platform-specific implementations.

See [`../AGENTS.md`](../AGENTS.md) for shared conventions (architecture layering, DI, testing, error handling).

## Flutter-Specific Conventions

- `flutter_bloc` for widget integration (`BlocProvider`, `context.watch`, `context.read`)
- Services: resolve via `getIt<Type>()`, NOT `context.read<Service>()`
- Cubits: `BlocProvider(create: (_) => MyCubit(getIt<MyService>()))`, then `context.watch`/`context.read`
- Do NOT use `BlocBuilder` — prefer `context.watch<MyCubit>().state`
- Guard `emit()` with `if (isClosed) return;` after any async gap in cubits
- DI configured in `lib/core/di/injection.dart` — calls `configureCoreDependencies(getIt)` after Flutter-specific registrations

## Project Structure

```
lib/
├── capabilities/     Voice recording subsystem (AudioRecorder, WakeLock, RecordingFileProvider)
├── core/
│   ├── di/           Flutter DI — registers platform adapters, then calls core init
│   ├── extensions/   BuildContext extensions (localization)
│   ├── platform/     FlutterSecureStorageAdapter, FlutterUrlLauncher, AppLifecycleObserver
│   ├── routing/      GoRouter routes, deep link handling (AppLinksDeepLinkSource)
│   └── widgets/      Connection overlay, modal bottom sheets
├── features/         Screen widgets (login, project_list, session_list, session_detail)
├── l10n/             Localization (English only)
└── main.dart         Entry point
```

## UI Guidelines

- Localize all user-facing text in `lib/l10n/app_en.arb`, access via `context.loc.myResource`
- English only for now

## Navigation

- GoRouter for routing (`go_router`)
- No automatic redirects — all navigation triggered by explicit user action
- Routes use web-style URLs with path/query params. Do NOT use `state.extra`

## Platform Adapters

This package provides concrete implementations of `sesori_dart_core` platform interfaces:

| Interface | Implementation | Wraps |
|-----------|---------------|-------|
| `SecureStorage` | `FlutterSecureStorageAdapter` | `flutter_secure_storage` |
| `UrlLauncher` | `FlutterUrlLauncher` | `url_launcher` |
| `DeepLinkSource` | `AppLinksDeepLinkSource` | `app_links` |

`AppLifecycleObserver` bridges Flutter's `WidgetsBindingObserver` to `ConnectionService.onAppBackgrounded()` / `onAppResumed()`.
