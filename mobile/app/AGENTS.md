# sesori_flutter — Flutter App

Thin UI shell for the Sesori mobile client. All business logic, state management, and services live in `sesori_dart_core` — this package provides screens, widgets, routing, and platform-specific implementations.

See [`../AGENTS.md`](../AGENTS.md) for shared conventions (architecture layering, DI, testing, error handling).

## File Size
- Maximum file length: 250 lines per production code file
- If a file exceeds 250 lines, split it into smaller focused files (by use-case, component, or concern)
- Prefer many small files over few large files
- Test files are explicitly excluded from this limit

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

## Theming

The app uses the **Zyra design system** via `theme_zyra`. The theme is wired into `MaterialApp.router` in `main.dart` using `ZyraColors`, `ZyraTextTheme`, and `ZyraDesignSystem` for both light and dark modes.

**ALWAYS access colors, text styles, spacing, radius, and shadows through `context.zyra`.** Never reach for `Theme.of(context).colorScheme` or `Theme.of(context).textTheme` when a Zyra token exists. This ensures every screen stays consistent with the Figma design system.

### Correct usage

```dart
// Colors
context.zyra.colors.textPrimary
context.zyra.colors.bgBrandSolid
context.zyra.colors.fgErrorPrimary

// Text styles
context.zyra.textTheme.textMd.bold
context.zyra.textTheme.textSm.regular

// Spacing / radius / shadows
context.zyra.spacing.md
context.zyra.radius.lg
context.zyra.shadows.sm
```

### Incorrect usage

```dart
// Do NOT use Material colorScheme directly
Theme.of(context).colorScheme.primary
Theme.of(context).colorScheme.error

// Do NOT use Material textTheme directly
Theme.of(context).textTheme.titleMedium
Theme.of(context).textTheme.bodySmall
```

The only exception is reading `Theme.of(context).brightness` for light/dark checks, which is still acceptable.

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
