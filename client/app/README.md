# Sesori Mobile App

Flutter UI shell providing screens, navigation, and platform adapters for the Sesori mobile client. All business logic lives in [`module_core`](../module_core/).

See the [root README](../README.md) for the full monorepo overview.

## Screens

| Screen | Description |
|--------|-------------|
| `LoginScreen` | OAuth sign-in entry point, handles deep link callback |
| `ProjectListScreen` | Lists available projects for the authenticated user |
| `SessionListScreen` | Lists sessions for a selected project |
| `SessionDetailScreen` | Full session view with message thread, voice input, and live updates |

## Key Components

**Routing**

`AppRouter` (`app_router.dart`) — `go_router`-based router built from `AppRoute` enum values defined in `module_core`. Handles session restore on startup and suppresses deep link URIs that `app_links` processes separately.

**Dependency Injection**

Three-phase init in `configureDependencies()`:
1. Flutter platform adapters (`getIt.init()`)
2. `configureAuthDependencies(getIt)` — auth module
3. `configureCoreDependencies(getIt)` — core module

**Platform Adapters**

| Adapter | Interface |
|---------|-----------|
| `FlutterSecureStorageAdapter` | `SecureStorage` |
| `FlutterUrlLauncher` | `UrlLauncher` |
| `AppLifecycleObserver` | `LifecycleSource` |
| `DeepLinkSource` (app_links) | `DeepLinkSource` |

**Widgets**

`ConnectionOverlay` — wraps the app and shows connection status banners driven by `ConnectionOverlayCubit`.

**Voice Features**

`FlutterVoiceCapture` — adapts the `record` package into one native capture session per composer. Module-core `VoiceTranscriptionService` owns recording/transcription policy through `VoiceRepository`, while `VoiceInputCubit` exposes lifecycle state to the shell. `WakeLockService` coordinates session leases over the process-wide `wakelock_plus` capability.

## Running

```bash
flutter pub get
dart run build_runner build
flutter run
```

## Singular mobile attribution

The Android/iOS app includes Singular's basic install/session attribution integration. It starts in eligible release
builds using the required compile-time credentials. Debug/profile builds and unsupported platforms remain disabled.
An unauthenticated Android build newer than the latest production submission in Firebase Remote Config defers startup;
successful interactive authentication starts Singular before reporting its conversion events, while crawlers that never
authenticate stay off.

Keep credentials outside Git. Create a local JSON file such as:

```json
{
  "SESORI_SINGULAR_SDK_KEY": "your-sdk-key",
  "SESORI_SINGULAR_SDK_SECRET": "your-sdk-secret"
}
```

Then pass it to a release build with `--dart-define-from-file=/absolute/path/to/singular.json`. Automated Android and
iOS release lanes require the `SINGULAR_SDK_KEY` and `SINGULAR_SDK_SECRET` GitHub Actions secrets and inject them
through a temporary mode-0600 file. Singular's client credentials are embedded in the compiled app by design; this
handling keeps them out of Git and routine command logs, but does not make them secret from someone inspecting the
binary.

The iOS dependency bundles Singular's vendor privacy manifest. Review the binary and update Apple/Google store
declarations before distributing it; runtime flags do not alter that manifest.

The integration does not set a custom user ID or send custom Singular events. After interactive authentication it
sends Singular's parameter-free standard login event, plus the standard complete-registration event only when the
auth server reports that the operation created the account. Session restore and token refresh send neither event.
Advertising identifiers and partner data sharing are limited in SDK configuration, and Android removes both
advertising-ID permissions. Distributed builds must satisfy the privacy/store disclosure checklist in
[`docs/PRODUCT_ANALYTICS_DISCLOSURE.md`](docs/PRODUCT_ANALYTICS_DISCLOSURE.md).

## Testing

```bash
flutter test
```

## Adding a New Screen

1. Create a `Cubit` (and state) in `module_core/lib/src/cubits/`
2. Create the screen widget in `app/lib/features/<feature>/`
3. Add a new value to `AppRoute` in `module_core` and handle it in `AppRouter.toGoRoute()`
4. Register any new DI bindings in the appropriate module's `injection.dart`

## Tech Stack

| Concern | Library |
|---------|---------|
| State management | `flutter_bloc` |
| Dependency injection | `get_it` + `injectable` |
| Navigation | `go_router` |
| Secure storage | `flutter_secure_storage` |
| Deep links | `app_links` |
| URL launching | `url_launcher` |
| Audio recording | `record` |
| Wake lock | `wakelock_plus` |
| Markdown rendering | `flutter_markdown_plus` |
