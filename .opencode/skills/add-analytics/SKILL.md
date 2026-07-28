---
name: add-analytics
description: Guidelines for adding analytics events to the Sesori app. Use when adding new user-facing features, evaluating whether an event is worth tracking, or designing event parameters. Covers the event taxonomy, hook points, BigQuery view updates, and the decision framework for what to track.
---

# add-analytics

How to add analytics events to the Sesori mobile app.

## Decision framework: is this event worth tracking?

Ask these questions in order. If any answer is "no", skip the event.

1. **Does it answer a product question?** ("How many users use voice?" not "How many times was this button tapped?")
2. **Would it appear in an investor update?** (Activation rate, DAU, retention, feature adoption)
3. **Would it change a product decision?** (If the metric moved, would you do something differently?)
4. **Is it actionable?** (Can you tie it to a funnel step, retention cohort, or feature?)

If all 4 are "yes", add the event. If any is "no", don't.

## Event naming

- GA4 event name: `snake_case`, letters/digits/underscores only, max 40 chars
- Use a verb or verb_phrase: `login_completed`, `message_sent`, `diff_viewed`
- Prefix with the domain when ambiguous: `bridge_connected` not just `connected`
- The `@FreezedUnionValue` annotation pins the wire name — never change it after release

## Parameters

- Max 25 parameters per event (GA4 limit)
- Parameter names: `snake_case`, max 40 chars
- Use enums for closed sets (e.g., `AuthProvider`, `MessageSource`) — never free-form strings
- Use `String` for open-ended values (e.g., `pluginId`)
- Register custom parameters in GA4 console → Admin → Custom Definitions for them to appear in the GA4 UI (they appear in BigQuery automatically)

## Where to add the hook

| Event type | Hook location | Example |
|-----------|---------------|---------|
| User intent (tap, submit) | Cubit method entry | `loginStarted` in `LoginCubit.loginWithProvider()` |
| Confirmed outcome | Cubit method after success | `loginCompleted` on `LoginSuccess` emit |
| Reactive transition | Dedicated Layer-4 listener subscribing to a service stream | `BridgeConnectionAnalyticsListener` subscribes to `ConnectionService.status` |
| Screen navigation | Dedicated Layer-4 listener subscribing to `RouteSource` | `AnalyticsRouteListener` subscribes to `GoRouterRouteSource.currentRouteStream` |
| Flutter-only capability outcome | UI call site after the capability returns | `voiceTranscriptionCompleted` in `PromptInput._stopAndTranscribe()` |

**Prefer cubit hooks or dedicated listeners over modifying services.** Never add
analytics calls to Layer-0 transport (`ConnectionService`, `RelayClient`) or to
app-shell capability services (`VoiceTranscriptionService`). If a stream
transition needs tracking, create a small listener class in `module_core` that
subscribes to the stream and delegates to `AnalyticsReporter`.

## Architecture rules

- `AnalyticsReporter` and `AnalyticsEvent` live in `module_core/lib/src/platform/` — they are a Layer-0 seam, same as `UrlLauncher` and `RouteSource`.
- The concrete implementation (`FirebaseAnalyticsReporter`) stays in the product shell (`client/app`) and is registered during phase-1 DI, before `configureCoreDependencies`.
- `module_core` never registers the implementation. Desktop registers a `NoOpAnalyticsReporter` during its phase-1 DI.
- Stream-driven events use dedicated Layer-4 listeners in `module_core/lib/src/services/`, not modifications to Layer-0 services.

## Step-by-step checklist

1. [ ] Add the event case to `module_core/lib/src/platform/analytics_event.dart`
2. [ ] Add any new enums to the same file (with `@JsonValue` wire names)
3. [ ] Run `dart run build_runner build --delete-conflicting-outputs` in `module_core/`
4. [ ] Add `AnalyticsReporter` parameter to the cubit/service constructor
5. [ ] Add `getIt<AnalyticsReporter>()` to the `BlocProvider(create:)` closure (both mobile and desktop if the cubit is shared)
6. [ ] Log the event at the correct hook point (see table above)
7. [ ] Add/update tests: verify the event fires on success, doesn't fire on failure
8. [ ] Run `dart analyze` in touched modules
9. [ ] Run `dart test` (module_core) and/or `flutter test` (app)
10. [ ] If the event adds a new dimension, update `docs/analytics/bigquery_views.sql` with a view that uses it
11. [ ] Register the new parameter in GA4 console → Admin → Custom Definitions

## What NOT to track

- **Sensitive data**: No message content, file paths, code snippets, or PII beyond the hashed user ID
- **High-frequency events**: No per-keystroke, per-frame, or per-scroll events (GA4 quotas)
- **Redundant events**: If `session_created` already implies `project_selected`, don't add both
- **Debug/diagnostic events**: Use Crashlytics or logs, not analytics

## BigQuery view updates

When adding an event that enables a new investor metric, add a corresponding view to `docs/analytics/bigquery_views.sql`. Follow the existing naming convention: `v_<metric_name>`.

## Existing event taxonomy

See `module_core/lib/src/platform/analytics_event.dart` for the complete, auditable list of all tracked events. This file is the single source of truth.
