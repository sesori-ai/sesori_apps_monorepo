# Sesori Mobile App

Flutter UI shell providing screens, navigation, and platform adapters for the Sesori mobile client. All business logic lives in [`module_core`](../module_core/).

See the [root README](../README.md) for the full monorepo overview.

## Screens

| Screen | Description |
|--------|-------------|
| `LoginScreen` | OAuth and email sign-in entry point |
| `HomeScreen` | Lists every project's recent sessions, with onboarding and offline states |
| `SessionDetailScreen` | Full session view with message thread, voice input, and live updates |

## Key Components

**Routing**

`AppRouter` (`app_router.dart`) — `go_router`-based router built from `AppRoute` enum values defined in `module_core`. Handles session restore on startup and ignores incoming deep links.

**Dependency Injection**

Startup order in `configureDependencies()`:
1. Register the build-mode `PersistenceScope` and Flutter platform adapters (`getIt.init()`)
2. `configurePersistenceDependencies(getIt: getIt)` — shared SQL/crypto repositories
3. `configureAuthDependencies(getIt)` — auth module
4. `configureCoreDependencies(getIt)` — core module
5. Production only: await the isolated deprecated native-storage import
6. Prepare analytics and resolve normal consumers

Development never constructs the legacy source. Import failure attempts scoped
local reset before normal logged-out startup; cleanup errors remain observable.
Persistent native storage denial can still fail a login write, but no separate
blocking migration screen prevents access to the normal login flow.

**Platform Adapters**

| Adapter | Interface |
|---------|-----------|
| `FlutterMasterKeyStore` | `MasterKeyStore` (`sesori_persistence`) |
| `FlutterPersistenceDirectory` | `PersistenceDirectory` (`sesori_persistence`) |
| `FlutterLegacyNativeStorageAdapter` (temporary) | `LegacyNativeStorage` |
| `FlutterUrlLauncher` | `UrlLauncher` |
| `AppLifecycleObserver` | `LifecycleSource` |

**Widgets**

`ConnectionOverlay` — wraps the app and shows connection status banners driven by `ConnectionOverlayCubit`.

**Voice Features**

`FlutterVoiceCapture` (shared with desktop in `module_app_ui/lib/src/platform/voice/`) — adapts the `record` package into one native capture session per composer; the app adds only its native recorder prewarm. Module-core `VoiceTranscriptionService` owns recording/transcription policy through `VoiceRepository`, while `VoiceInputCubit` exposes lifecycle state to the shell. `WakeLockService` coordinates session leases over the process-wide `wakelock_plus` capability.

## Running

```bash
flutter pub get
dart run build_runner build
flutter run
```

## Singular mobile attribution

The Android/iOS app includes Singular's basic install/session attribution integration. It starts in eligible release
builds using the required compile-time credentials. Debug/profile builds remain disabled.
An unauthenticated Android build newer than the latest production submission in Firebase Remote Config defers startup;
successful interactive authentication starts Singular before reporting its conversion events, while crawlers that never
authenticate stay off. The Remote Config decision is resolved asynchronously and never delays the first product frame.

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

The integration does not set a custom user ID or send event properties. After interactive authentication it sends
Singular's parameter-free standard login event, plus the standard complete-registration event only when the auth
server reports that the operation created the account. Session restore and token refresh send neither event. It also
sends parameter-free `bridge_paired` and `first_session_run` activation events at most once per installation. Partner
data sharing is permitted for campaign attribution while advertising identifiers remain limited, and Android removes
both advertising-ID permissions. Distributed builds must satisfy the privacy/store disclosure checklist in
[`docs/PRODUCT_ANALYTICS_DISCLOSURE.md`](docs/PRODUCT_ANALYTICS_DISCLOSURE.md).

## Testing

```bash
flutter test
```

### Driving the app on a simulator

Automated on-device checks run as integration tests on an iOS simulator. Build them with
`--dart-define=SESORI_TEST_MODE=true` (`sesoriTestMode` in `lib/core/sesori_test_mode.dart`). It skips both native
notification permission prompts, never starts the founder call sheet or the automatic rating prompt, and starts the
composer in typing mode. Release builds ignore it, but any debug or profile build honors it, including one on a physical
device, so pass it only for unattended simulator runs.

Keep the dev-account credentials out of the command line and shell history: put them in the gitignored
`sesori_test_defines.json` in this directory, mode 0600:

```json
{
  "SESORI_TEST_EMAIL": "<dev-account-email>",
  "SESORI_TEST_PASSWORD": "<dev-account-password>"
}
```

Pass `--no-uninstall` so the app, and its sign-in, stays installed between runs:

```bash
flutter test integration_test/sim_smoke_test.dart -d <simulator-udid> --no-uninstall \
  --dart-define=SESORI_TEST_MODE=true --dart-define-from-file=sesori_test_defines.json
```

`sim_smoke_test.dart` signs in with email only when the app is signed out, opens the newest session and types into its
composer; it is skipped without the flag and credentials, and needs a bridge signed in to the same account. Find the
composer with `PromptInput.textFieldKey` and its Send button with `PromptInput.sendButtonKey`. In typing mode the
composer rests as a compact pill: tap `PromptInput.startTypingKey` first to open the text field. Keyed finders match
only the current composer layout, also while two layouts cross-fade.

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
| Typed preferences and encrypted secrets | `sesori_persistence` (Drift/crypto) |
| Native master key | `flutter_secure_storage` |
| URL launching | `url_launcher` |
| Audio recording and wake lock | `record`, `wakelock_plus` (via `module_app_ui`) |
| Markdown rendering | `flutter_markdown_plus` |
