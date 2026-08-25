# Step 36 — Replace the no-op Firebase SDK adapters with no-op interface implementations

Builds without Firebase (web, Linux, Windows, Android profile) stood up fake
FlutterFire **SDK objects** so the real wrappers had something to talk to. That
meant 608 lines mirroring vendor API surfaces to be handed to three wrappers
whose own interfaces total **13 members**.

## Re-verification against `main`

| No-op SDK adapter | Lines | Its only consumer |
| --- | --- | --- |
| `no_op_firebase_analytics_adapter.dart` | 418 | `firebase_register_module.dart:43` |
| `no_op_firebase_messaging_adapter.dart` | 87 | `firebase_register_module.dart:35` |
| `no_op_firebase_crashlytics_adapter.dart` | 64 | `firebase_register_module.dart:51` |
| `no_op_firebase_app_adapter.dart` | 39 | `firebase_register_module.dart:27` |

Each SDK type reaches exactly one thin wrapper of a small `module_core` /
`sesori_shared` interface:

| SDK type | Wrapper | Interface | Members |
| --- | --- | --- | --- |
| `FirebaseAnalytics` | `FirebaseAnalyticsClient` | `AnalyticsClient` | 2 |
| `FirebaseCrashlytics` | `CrashlyticsFailureReporter` | `FailureReporter` | 3 |
| `FirebaseMessaging` | `FirebasePushMessagingSource` | `PushMessagingSource` | 8 |
| `FirebaseApp` | — | — | DI only |

`client/desktop/lib/core/platform/no_op_analytics_client.dart` is already the
11-line version of this pattern, so this makes the mobile shell consistent with
the desktop one rather than inventing an approach.

## What changed

- Three no-ops added under `client/app/lib/core/platform/firebase/`:
  `NoOpAnalyticsClient`, `NoOpFailureReporter`, `NoOpPushMessagingSource`,
  each `@firebaseDisabledEnvironment`.
- The three Firebase wrappers gain `@firebaseEnabledEnvironment`.
- The four no-op SDK adapters and their disabled-environment registrations are
  deleted. `FirebaseRegisterModule` now registers only real SDK objects.

Net **-524 lines** in `client/app/lib` (excluding generated DI).

### Two things deliberately kept

- **`FirebaseMessagingStaticAdapter` keeps its disabled registration.**
  `main.dart` calls `getIt<FirebaseMessagingStaticAdapter>().registerBackgroundHandler(...)`
  unconditionally, so both environments must resolve it.
- **`PushMessagingSource` needs a disabled binding even though notification
  startup is Firebase-guarded.** `NotificationRegistrationService` depends on it
  and is resolved from `settings_screen.dart:40` and `profile_screen.dart:32` on
  every platform. Omitting the binding would throw when a disabled build opens
  Settings.

## Behavior

Enabled builds (iOS, macOS, Android release/debug) are untouched — they resolve
the same wrappers over the same real SDK objects.

One real difference in **disabled** builds, stated rather than glossed:

Previously `FirebaseAnalyticsClient` ran with an `AnalyticsRuntimeCapability`
that `main.dart:163` always reports disabled there, so `logProductEvent` threw
`StateError`; `AnalyticsRepository._deliver` caught it and returned
`AnalyticsDeliveryResult.failed`, which made `ProductAnalyticsService`
short-circuit at `product_analytics_service.dart:171` and log
"Failed to deliver analytics schema readiness".

Now `NoOpAnalyticsClient` returns normally, so delivery reports
`acceptedBySdk` and the dispatch pipeline runs to completion, discarding events
into the no-op. Events reach no sink either way; the disabled build simply stops
logging a failure warning for a sink that was never expected to exist. This is
already how `client/desktop` behaves with its own `NoOpAnalyticsClient`.

The capability check still matters where it always did: an **enabled**-environment
build with analytics runtime-disabled (a debug iOS build, or Firebase Test Lab)
keeps `FirebaseAnalyticsClient` and its `StateError` path unchanged.

`NoOpPushMessagingSource.devicePlatform` returns `DevicePlatform.android` and
says so in a comment: both `registerToken` call sites
(`notification_registration_service.dart:97` and `:195`) are reached only
through a non-null `getToken()` or a `tokenRefreshStream` event, and the no-op
produces neither. Reporting a value beats throwing, because the settings screen
resolves this service.

## Noted, not changed

`_shouldInitializeFirebase`, `_supportsFirebaseAnalytics` and
`_supportsFirebaseCrashlytics` (`main.dart:208-242`) are three character-identical
predicates. Collapsing them is a `main.dart` concern rather than an adapter one,
and they read as intentionally separate so they can diverge per capability, so
this step leaves them alone.

## Verification

```bash
cd client/app && dart analyze --fatal-infos   # clean
cd client/app && flutter test                 # 985 passing
```

The DI registration test was rewritten rather than deleted: it previously
asserted SDK-level substitutes that no longer exist, and now asserts the
contract that matters — the three interfaces bind to no-ops, **no FlutterFire
SDK object is registered at all**, the static messaging adapter still resolves,
and the services that depend on the no-ops still construct.

`client/desktop` and `module_desktop_core` are untouched (no files in the diff).

Architecture implementation review: not run. No new layer or dependency
direction — this swaps which implementation an existing DI environment binds to
and deletes four unused classes.
