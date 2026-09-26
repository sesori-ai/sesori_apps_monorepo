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
- Put reusable visual primitives and their native renderers in `module_prego`.
  The app shell consumes those widgets; it does not own duplicate implementations
  or manually register their platform views.
- Guard `emit()` with `if (isClosed) return;` after any async gap in cubits
- DI configured in `lib/core/di/injection.dart`: platform → persistence → auth → core → production migration → consumers

## Project Structure

```
lib/
├── capabilities/     Voice platform helpers (format, prewarm, recording path, session-safe wake-lock leases)
├── core/
│   ├── di/           Flutter DI — registers platform adapters, then calls core init
│   ├── extensions/   Mobile-only Flutter mappings
│   ├── platform/     FlutterMasterKeyStore, FlutterVoiceCapture, FlutterUrlLauncher, AppLifecycleObserver
│   ├── routing/      GoRouter routes, deep link handling (AppLinksDeepLinkSource)
│   └── widgets/      Connection overlay, modal bottom sheets
├── features/         Screen widgets (login, project_list, session_list, session_detail)
└── main.dart         Entry point
```

Shared localization, `BuildContext` localization/date helpers, connection UI,
settings/harness-management presentation, and GoRouter route observation live
in `../module_app_ui/` and are consumed by both product shells. This shell keeps
mobile DI, routes, notification preferences, package/link strategies, and
logout composition.

## UI Guidelines

- Localize shared user-facing text in `../module_app_ui/lib/src/l10n/app_en.arb`, access via `context.loc.myResource`
- English only for now
- When review feedback claims a shared widget style change unintentionally affects other screens, verify the design intent before preserving older styling. If the design changed for every consumer, keep the shared widget change and explain that in the PR reply.

## Theming

The app uses the **Prego design system** via `theme_prego`. Both light and dark themes are wired into `MaterialApp.router` with `buildPregoThemeData`, the same terminal theme-assembly helper used by desktop.

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

Third-party static plugin APIs are hidden dependencies. Always wrap them in an
injectable client or service and inject that wrapper into the platform adapter,
so the dependency is explicit and the adapter can be tested in isolation.

| Interface | Implementation | Wraps |
|-----------|---------------|-------|
| `MasterKeyStore` | `FlutterMasterKeyStore` | One scoped native item in the new persistence namespace |
| `PersistenceDirectory` | `FlutterPersistenceDirectory` | Existing app-support resolver; ready `persistence/` subtree |
| `LegacyNativeStorage` | `FlutterLegacyNativeStorageAdapter` | Temporary old-keyspace enumeration/named deletion |
| `UrlLauncher` | `FlutterUrlLauncher` | `url_launcher` |
| `DeepLinkSource` | `AppLinksDeepLinkSource` | `app_links` |

The persistence contracts come from lower-level `sesori_persistence`. Scope is
selected by `main` (release → production; debug/profile → development), then
registered explicitly before lazy platform DI. Production startup awaits the
deprecated importer before consumers; development does not construct its source.
Import failure disposes the partial graph and renders `PersistenceStartupFailureApp`
without DI, analytics or preference reads. Only OS close/reopen retries.
Android backup XML excludes the database subtree and exact legacy/new native
credential preferences; iOS retains Application Support backup eligibility.
The legacy adapter stays inside `deprecated_native_storage_v1/` and is deleted
with its core importer.

`AppLifecycleObserver` bridges Flutter's `WidgetsBindingObserver` to `ConnectionService.onAppBackgrounded()` / `onAppResumed()`.
