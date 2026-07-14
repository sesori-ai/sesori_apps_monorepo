# sesori_flutter — Flutter App

Thin UI shell for the Sesori mobile client. All business logic, state management, and services live in `sesori_dart_core` — this package provides screens, widgets, routing, and platform-specific implementations.

See [`../AGENTS.md`](../AGENTS.md) for shared conventions (architecture layering, DI, testing, error handling).

## Error Handling

**Never silently swallow** (see the repo-root `AGENTS.md`): a `catch` that swallows and continues (no-op/best-effort) must log, and a catch-all especially. But don't double-log when the catch already surfaces the failure (rethrows, or returns/yields an explicit failure the caller renders). Pass the error as the logger argument (`Log.w("msg", error, st)`), don't string-interpolate it.

## Flutter-Specific Conventions

- `flutter_bloc` for widget integration (`BlocProvider`, `context.watch`, `context.read`)
- Services: resolve via `getIt<Type>()`, NOT `context.read<Service>()`
- Cubits: `BlocProvider(create: (_) => MyCubit(getIt<MyService>()))`, then `context.watch`/`context.read`
- Do NOT use `BlocBuilder` — prefer `context.watch<MyCubit>().state`
- Do not reduce visible animation cadence as a battery optimization without explicit design approval. For long-lived busy indicators, first isolate repaint damage and profile the smooth animation; use a static indicator when continuous frames are unacceptable.
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
- When review feedback claims a shared widget style change unintentionally affects other screens, verify the design intent before preserving older styling. If the design changed for every consumer, keep the shared widget change and explain that in the PR reply.

## Theming

The app uses the **Prego design system** via `theme_prego`. The theme is wired into `MaterialApp.router` in `main.dart` using `PregoColors`, `PregoTextTheme`, and `PregoDesignSystem` for both light and dark modes.

**ALWAYS access colors, text styles, spacing, radius, and shadows through `context.prego`.** Never reach for `Theme.of(context).colorScheme` or `Theme.of(context).textTheme` when a Prego token exists. This ensures every screen stays consistent with the Figma design system.

### Correct usage

```dart
// Colors
context.prego.colors.textPrimary
context.prego.colors.bgBrandSolid
context.prego.colors.fgErrorPrimary

// Text styles
context.prego.textTheme.textMd.bold
context.prego.textTheme.textSm.regular

// Spacing / radius / shadows
context.prego.spacing.md
context.prego.radius.lg
context.prego.shadows.sm
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
- For pageless routes such as modal sheets, align the enclosing `Page` key with the logical owner so Flutter's Navigator lifecycle removes them naturally. Prefer correct page identity and a current-route presentation gate over manually tracking `ModalRoute`s or listening to `GoRouter.routerDelegate` from a feature widget.

## Platform Adapters

This package provides concrete implementations of `sesori_dart_core` platform interfaces:

| Interface | Implementation | Wraps |
|-----------|---------------|-------|
| `SecureStorage` | `FlutterSecureStorageAdapter` | `flutter_secure_storage` |
| `UrlLauncher` | `FlutterUrlLauncher` | `url_launcher` |
| `DeepLinkSource` | `AppLinksDeepLinkSource` | `app_links` |

`AppLifecycleObserver` bridges Flutter's `WidgetsBindingObserver` to `ConnectionService.onAppBackgrounded()` / `onAppResumed()`.
