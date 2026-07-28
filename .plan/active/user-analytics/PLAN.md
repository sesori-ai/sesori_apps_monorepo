# User Analytics Expansion Plan

**Slug:** `user-analytics`
**Goal:** Instrument the mobile app with a full activation-funnel + engagement event taxonomy, add GoRouter screen-view tracking, set up BigQuery views for investor metrics, and codify analytics practices in AGENTS.md + a new skill.
**Branch:** `user-analytics-plan` (worktree)
**PR strategy:** Multiple PRs, each titled `[user-analytics] <description> [step <x>/<y>]`

---

**Architecture review:** Passed after corrections (Aristotle). Key corrections applied:
- `AnalyticsReporter`/`AnalyticsEvent` live in `module_core/lib/src/platform/` (Layer-0 seam, same as `UrlLauncher`/`RouteSource`), not an unclassified `reporting/` directory.
- `FirebaseAnalyticsReporter` stays in `client/app` and is registered during mobile phase-1 DI; `module_core` never registers the implementation.
- Desktop registers a `NoOpAnalyticsReporter` during its phase-1 DI; all desktop `BlocProvider` call sites for shared cubits are updated.
- `bridgeConnected` is reported by a dedicated `BridgeConnectionAnalyticsListener` (Layer 4), not by `ConnectionService` (Layer 0 transport).
- `voiceTranscriptionCompleted` fires from the `PromptInput` call site, not from `VoiceTranscriptionService`.
- Route tracking uses `AnalyticsRouteListener` (Layer 4, in `module_core`), not `AnalyticsRouteObserver` in the app shell.

---

## Current State

- Firebase Analytics wired in `client/app` only (mobile, iOS/Android/macOS targets).
- `AnalyticsReporter` interface + `AnalyticsEvent` sealed union in `client/app/lib/core/analytics/`.
- `FirebaseAnalyticsReporter` implements the interface, forwards to `FirebaseAnalytics.logEvent()`.
- `AnalyticsUserIdTracker` syncs SHA-256-hashed `AuthUser.id` to Firebase `setUserId`.
- **Only 7 events tracked** — all onboarding UI interactions (install command copies, support link taps, "why bridge" explainer).
- No login, connection, session, message, screen-view, or activation events.
- Desktop app has **no analytics** (deferred per user decision).
- `GoRouterRouteSource` in `client/app/lib/core/platform/go_router_route_source.dart` already emits `AppRouteDef?` on every route change — the hook for screen-view tracking.

## Decisions (confirmed with user)

| # | Decision | Choice |
|---|----------|--------|
| 1 | `first_assistant_message` dedup | BigQuery `MIN(event_timestamp)` per user — no client-side flag |
| 2 | `message_sent` source param | Yes — `source: typed \| voice` to track voice-first adoption over time |
| 3 | Screen-view tracking | Yes — via `GoRouterRouteSource.currentRouteStream` → typed route names |
| 4 | Desktop analytics | Deferred to follow-up phase |
| 5 | Login provider | Parameter on events (`provider: github \| google \| apple \| email`), not separate events |
| 6 | AGENTS.md update | Add analytics-as-recurring-practice guidance |
| 7 | New skill | `.opencode/skills/add-analytics/` with event-design guidelines |

---

## PR Breakdown

### PR 1: `[user-analytics] Add analytics plan, practice docs, and BigQuery views [step 1/4]`

Already implemented on the `user-analytics-plan` branch:

- `.plan/active/user-analytics/PLAN.md` — this plan
- `.opencode/skills/add-analytics/SKILL.md` — analytics event-design skill
- `docs/analytics/bigquery_views.sql` — 9 BigQuery views (DAU, retention, funnel, voice adoption, etc.)
- `AGENTS.md` — new "Analytics" section making event consideration a recurring practice

Docs/instruction changes only — no Dart/Flutter suites needed.

---

### PR 2: `[user-analytics] Move analytics seam to module_core [step 2/4]`

Move `AnalyticsReporter` interface and `AnalyticsEvent` union from `client/app` to `client/module_core` so cubits and services (pure Dart) can log events without importing Flutter.

**Changes:**

1. Move `client/app/lib/core/analytics/analytics_reporter.dart` → `client/module_core/lib/src/platform/analytics_reporter.dart`
2. Move `client/app/lib/core/analytics/analytics_event.dart` → `client/module_core/lib/src/platform/analytics_event.dart`
3. Regenerate freezed files (`analytics_event.freezed.dart`, `analytics_event.g.dart`) via `build_runner` in `module_core`
4. Export new files from `module_core/lib/sesori_dart_core.dart`
5. Update `FirebaseAnalyticsReporter` import in `client/app/lib/core/analytics/firebase_analytics_reporter.dart` to import from `sesori_dart_core`
6. Update `AnalyticsUserIdTracker` import similarly
7. Update all existing call sites (`onboarding_view.dart`, test helpers) to import from `sesori_dart_core` instead of local analytics files
8. **No DI registration change in `module_core`** — `FirebaseAnalyticsReporter` stays in `client/app` and is registered during mobile phase-1 DI (before `configureCoreDependencies`), same as today. `module_core` only defines the interface; the shell owns the implementation.
9. **Desktop no-op registration** — Register a `NoOpAnalyticsReporter` in `client/desktop` during desktop phase-1 DI so shared cubits that require `AnalyticsReporter` can resolve it. Update all desktop `BlocProvider(create:)` call sites for shared cubits (`LoginCubit`, `ProjectListCubit`, `NewSessionCubit`, `SessionDetailCubit`, `SessionListCubit`, `DiffCubit`) to pass `getIt<AnalyticsReporter>()`.

**Why `platform/`:** `AnalyticsReporter` is a shell-implemented platform seam — the same Layer-0 classification as `UrlLauncher`, `RouteSource`, `DeepLinkSource`, and `LifecycleSource` which already live in `module_core/lib/src/platform/`. The `AnalyticsEvent` union is the typed contract that both the interface and its consumers share, so it lives alongside the reporter.

**Why this shape:** `FailureReporter` precedent — interface in shared code, implementation in the app shell. Cubits in `module_core` already depend on `FailureReporter` (from `sesori_shared`); `AnalyticsReporter` follows the same pattern but lives in `module_core` since it's client-only.

**Files touched:** ~12 (2 moved, 2 regenerated, 6 import updates, 1 new NoOp, 1 desktop DI update)

**Verification:**
- `dart pub get` exits 0 from `client/`
- `dart analyze` exits 0 in `module_core/`, `app/`, and `desktop/`
- `cd app && flutter test` passes
- `cd module_core && dart test` passes
- `cd desktop && flutter test` passes

---

### PR 3: `[user-analytics] Add activation funnel + engagement events [step 3/4]`

Add all new `AnalyticsEvent` union cases and hook them into cubits/services.

#### New events

**Auth:**
```dart
@FreezedUnionValue("login_started")
const factory AnalyticsEvent.loginStarted({required AuthProvider provider}) = LoginStarted;

@FreezedUnionValue("login_completed")
const factory AnalyticsEvent.loginCompleted({required AuthProvider provider}) = LoginCompleted;

@FreezedUnionValue("login_failed")
const factory AnalyticsEvent.loginFailed({required AuthProvider provider}) = LoginFailed;
```

**Connection / Activation:**
```dart
@FreezedUnionValue("bridge_connected")
const factory AnalyticsEvent.bridgeConnected() = BridgeConnected;

@FreezedUnionValue("project_discovered")
const factory AnalyticsEvent.projectDiscovered() = ProjectDiscovered;

@FreezedUnionValue("session_created")
const factory AnalyticsEvent.sessionCreated({required String pluginId}) = SessionCreated;

@FreezedUnionValue("first_assistant_message")
const factory AnalyticsEvent.firstAssistantMessage() = FirstAssistantMessage;
```

**Engagement:**
```dart
@FreezedUnionValue("message_sent")
const factory AnalyticsEvent.messageSent({required MessageSource source}) = MessageSent;

@FreezedUnionValue("voice_transcription_completed")
const factory AnalyticsEvent.voiceTranscriptionCompleted() = VoiceTranscriptionCompleted;

@FreezedUnionValue("diff_viewed")
const factory AnalyticsEvent.diffViewed() = DiffViewed;

@FreezedUnionValue("permission_replied")
const factory AnalyticsEvent.permissionReplied({required PermissionReply reply}) = PermissionReplied;

@FreezedUnionValue("session_archived")
const factory AnalyticsEvent.sessionArchived() = SessionArchived;

@FreezedUnionValue("session_deleted")
const factory AnalyticsEvent.sessionDeleted() = SessionDeleted;

@FreezedUnionValue("session_renamed")
const factory AnalyticsEvent.sessionRenamed() = SessionRenamed;

@FreezedUnionValue("project_created")
const factory AnalyticsEvent.projectCreated() = ProjectCreated;
```

**New enums:**
```dart
enum MessageSource {
  @JsonValue("typed") typed,
  @JsonValue("voice") voice,
}

enum AuthProvider {  // already exists in module_auth — reuse, don't redefine
  github, google, apple, email,
}
```

#### Hook points (file → method → event)

| File | Method | Event | Notes |
|------|--------|-------|-------|
| `module_core/lib/src/cubits/login/login_cubit.dart` | `loginWithProvider()` | `loginStarted(provider)` | At entry |
| `module_core/lib/src/cubits/login/login_cubit.dart` | `loginWithProvider()` | `loginCompleted(provider)` | On `LoginSuccess` emit |
| `module_core/lib/src/cubits/login/login_cubit.dart` | `loginWithProvider()` | `loginFailed(provider)` | On `LoginFailed` emit |
| `module_core/lib/src/cubits/login/login_cubit.dart` | `loginWithApple()` | Same 3 events with `AuthProvider.apple` | |
| `module_core/lib/src/cubits/login/login_cubit.dart` | `loginWithEmail()` | Same 3 events with `AuthProvider.email` | |
| `module_core/lib/src/services/bridge_connection_analytics_listener.dart` (new) | Listens to `ConnectionService.status` stream | `bridgeConnected()` | Fire once per non-connected → connected transition. Layer-4 listener, not transport. |
| `module_core/lib/src/cubits/project_list/project_list_cubit.dart` | `discoverProject()` | `projectDiscovered()` | On success |
| `module_core/lib/src/cubits/project_list/project_list_cubit.dart` | `createProject()` / `createDirectory()` | `projectCreated()` | On success |
| `module_core/lib/src/cubits/new_session/new_session_cubit.dart` | `createSession()` | `sessionCreated(pluginId)` | On `NewSessionCreated` emit |
| `module_core/lib/src/cubits/session_detail/session_detail_cubit.dart` | `_onMessageUpdated()` | `firstAssistantMessage()` | Only when `message is MessageAssistant` and it's a new message (not an update to existing) |
| `module_core/lib/src/cubits/session_detail/session_detail_cubit.dart` | `sendMessage()` | `messageSent(source)` | On success (not error/requeue). Track `source` param — requires threading origin through `QueuedSessionSubmission` |
| `module_core/lib/src/cubits/session_detail/session_detail_cubit.dart` | `_drainQueuedMessages()` | `messageSent(source)` | Same — when queued send succeeds |
| `module_core/lib/src/cubits/session_detail/session_detail_cubit.dart` | `replyToPermission()` | `permissionReplied(reply)` | On success |
| `module_core/lib/src/cubits/session_list/session_list_cubit.dart` | `archiveSession()` | `sessionArchived()` | On success |
| `module_core/lib/src/cubits/session_list/session_list_cubit.dart` | `deleteSession()` | `sessionDeleted()` | On success |
| `module_core/lib/src/cubits/session_list/session_list_cubit.dart` | `renameSession()` | `sessionRenamed()` | On success |
| `module_core/lib/src/cubits/session_diffs/diff_cubit.dart` | `_fetchAndEmit()` | `diffViewed()` | On `DiffLoaded` emit (first load per mount) |
| `client/app/lib/features/session_detail/widgets/prompt_input.dart` | `_stopAndTranscribe()` | `voiceTranscriptionCompleted()` | On success (transcript returned). Fired from the UI call site, not from `VoiceTranscriptionService` — keeps the app-shell service free of analytics decisions. |

#### Voice source threading

`messageSent(source)` requires knowing whether the message text originated from voice. The approach:

1. `PromptInput._stopAndTranscribe()` already sets the transcribed text into the input controller. Add a flag `_lastInputWasVoice` that is set to `true` after transcription and cleared on any manual text edit.
2. When `PromptInput._handleSend()` calls `SessionDetailCubit.sendMessage()`, pass the source.
3. `sendMessage()` stores the source in `QueuedSessionSubmission` (add a `source` field) so queued sends retain their origin.
4. Both `sendMessage()` and `_drainQueuedMessages()` log `messageSent(source)` with the stored source.

**Changes to `QueuedSessionSubmission`:** Add `required MessageSource source` field (defaults to `MessageSource.typed` for backward compat during migration, but make it required since we control all call sites).

#### Cubit constructor changes

Each cubit that logs events gains a new required `AnalyticsReporter analyticsReporter` parameter. Call sites in `BlocProvider(create:)` closures add `getIt<AnalyticsReporter>()`.

Cubits affected: `LoginCubit`, `ProjectListCubit`, `NewSessionCubit`, `SessionDetailCubit`, `SessionListCubit`, `DiffCubit`.

Services affected: None — `bridgeConnected` moves to a new `BridgeConnectionAnalyticsListener` (Layer 4), and `voiceTranscriptionCompleted` fires from the UI call site.

**New Layer-4 listener:**

`BridgeConnectionAnalyticsListener` in `module_core/lib/src/services/bridge_connection_analytics_listener.dart`:

```dart
class BridgeConnectionAnalyticsListener {
  final AnalyticsReporter _reporter;
  final ConnectionService _connectionService;
  StreamSubscription<ConnectionStatus>? _subscription;
  bool _wasConnected = false;

  BridgeConnectionAnalyticsListener({
    required AnalyticsReporter reporter,
    required ConnectionService connectionService,
  }) : _reporter = reporter, _connectionService = connectionService {
    _subscription = _connectionService.status.listen(_onStatusChanged);
  }

  void _onStatusChanged(ConnectionStatus status) {
    final isConnected = status is ConnectionConnected;
    if (isConnected && !_wasConnected) {
      unawaited(_reporter.logEvent(event: const AnalyticsEvent.bridgeConnected()));
    }
    _wasConnected = isConnected;
  }

  void dispose() => _subscription?.cancel();
}
```

Instantiated in `main.dart` alongside `AnalyticsUserIdTracker`, passing `getIt<AnalyticsReporter>()` and `getIt<ConnectionService>()`. Mobile only — desktop does not instantiate this listener.

**Verification:**
- `dart analyze` exits 0 in `module_core/` and `app/`
- `cd module_core && dart test` passes (add tests for new event logging in cubit tests)
- `cd app && flutter test` passes (update onboarding analytics test, add connected_empty_view test if needed)
- Existing analytics events still fire correctly (no regressions)

---

### PR 4: `[user-analytics] Add screen-view tracking [step 4/4]`

Create `AnalyticsRouteListener` in `module_core/lib/src/services/analytics_route_listener.dart`:

```dart
class AnalyticsRouteListener {
  final AnalyticsReporter _reporter;
  final RouteSource _routeSource;
  StreamSubscription<AppRouteDef?>? _subscription;
  AppRouteDef? _lastLoggedRoute;

  AnalyticsRouteListener({
    required AnalyticsReporter reporter,
    required RouteSource routeSource,
  }) : _reporter = reporter, _routeSource = routeSource {
    _subscription = _routeSource.currentRouteStream.listen(_onRouteChanged);
  }

  void _onRouteChanged(AppRouteDef? route) {
    if (route == null || route == _lastLoggedRoute) return;
    _lastLoggedRoute = route;
    unawaited(_reporter.logEvent(
      event: AnalyticsEvent.screenViewed(screen: route.name),
    ));
  }

  void dispose() => _subscription?.cancel();
}
```

Pure Dart — no Flutter dependency. The `RouteSource` interface and `AppRouteDef` enum are already in `module_core`, so this listener lives there. Only its construction and app-lifetime ownership belong in `client/app/main.dart`.

**New event:**
```dart
@FreezedUnionValue("screen_view")
const factory AnalyticsEvent.screenViewed({required String screen}) = ScreenViewed;
```

Note: GA4 reserves `screen_view` as an automatic event name, but since we're logging it manually with our own parameter (`screen` instead of `firebase_screen`), it will appear as a custom event. This is intentional — GA4's automatic screen tracking doesn't work with `go_router`.

**Wire-up:** Instantiate in `main.dart` alongside `AnalyticsUserIdTracker`, passing `getIt<AnalyticsReporter>()` and `getIt<RouteSource>()`. Mobile only.

**Verification:**
- `dart analyze` exits 0 in `module_core/` and `app/`
- `cd module_core && dart test` passes (add `AnalyticsRouteListener` tests)
- `cd app && flutter test` passes

---

## BigQuery Console Setup Checklist (manual, one-time)

The SQL views live in `docs/analytics/bigquery_views.sql` (delivered in PR 1). To activate:

1. [ ] Open Firebase Console → Project Settings → Integrations → BigQuery
2. [ ] Click "Link" → choose BigQuery project and region (match your GCP project)
3. [ ] Enable "Daily export" (free tier: 10GB storage, 1TB queries/month)
4. [ ] Wait 24h for first export (or use streaming export for real-time)
5. [ ] Note the dataset name (format: `analytics_<project_number>`)
6. [ ] Run the SQL from `docs/analytics/bigquery_views.sql` (replace `<project>` and `<dataset>`)
7. [ ] In GA4 console → Admin → Custom Definitions → register custom dimensions:
   - `provider` (event-scoped)
   - `source` (event-scoped)
   - `screen` (event-scoped)
   - `reply` (event-scoped)
   - `pluginId` (event-scoped)
   - `surface` (event-scoped)
   - `method` (event-scoped)
   - `os` (event-scoped)
   - `channel` (event-scoped)
8. [ ] Optional: Create a Looker Studio dashboard connected to BigQuery for live investor metrics

---

## Event Taxonomy Summary

| Event | Parameters | Funnel stage | Investor metric |
|-------|-----------|--------------|-----------------|
| `first_open` | — (automatic) | Install | New users |
| `session_start` | — (automatic) | Engagement | DAU/WAU/MAU |
| `screen_view` | `screen` | Engagement | Navigation patterns |
| `login_started` | `provider` | Acquisition | Provider mix |
| `login_completed` | `provider` | Activation step 1 | Signup rate |
| `login_failed` | `provider` | Activation step 1 (drop) | Auth friction |
| `bridge_connected` | — | Activation step 2 | Bridge setup rate |
| `project_discovered` | — | Activation step 3 | Project setup rate |
| `project_created` | — | Activation step 3 (alt) | Project creation |
| `session_created` | `pluginId` | Activation step 4 | First usage |
| `first_assistant_message` | — | **Aha moment** | **Activation rate** |
| `message_sent` | `source` | Engagement | Daily usage, voice adoption |
| `voice_transcription_completed` | — | Engagement | Voice feature adoption |
| `diff_viewed` | — | Engagement | Review behavior |
| `permission_replied` | `reply` | Engagement | AI control patterns |
| `session_archived` | — | Engagement | Session management |
| `session_deleted` | — | Engagement | Session cleanup |
| `session_renamed` | — | Engagement | Session organization |
| `onboarding_need_help_opened` | `surface` | Onboarding | Support-seeking |
| `onboarding_support_link_opened` | `channel`, `surface` | Onboarding | Support channel mix |
| `onboarding_why_bridge_opened` | `surface` | Onboarding | Education engagement |
| `bridge_install_command_copied` | `method`, `os`, `surface` | Onboarding | Install intent |
| `bridge_install_command_shared` | `method`, `os`, `surface` | Onboarding | Install intent |
| `bridge_run_command_copied` | `surface` | Onboarding | Run intent |
| `bridge_run_command_shared` | `surface` | Onboarding | Run intent |

**Total: 23 events** (7 existing + 16 new)

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| `first_assistant_message` fires on history load (not live) | Only fire when `_onMessageUpdated` receives a **new** `MessageAssistant` (index < 0 in existing list), not an update to an existing message |
| `messageSent` double-fires from both `sendMessage()` and `_drainQueuedMessages()` | Fire only on success path; if `sendMessage` enqueues, the event fires when `_drainQueuedMessages` succeeds, not on enqueue |
| `bridgeConnected` fires on every reconnect (noisy) | `BridgeConnectionAnalyticsListener` tracks `_wasConnected` and only fires on non-connected → connected transitions, not on steady-state replays |
| `screen_view` floods GA4 with duplicate events | `AnalyticsRouteListener` deduplicates consecutive identical routes |
| Freezed regeneration breaks existing events | The `@FreezedUnionValue` annotations pin wire names; regenerated code is identical for unchanged cases |
| GA4 custom parameter limits | Max 25 params/event, max 50 custom dimensions — we're well under |
| BigQuery costs | Free tier: 10GB storage, 1TB queries/month. Our volume is negligible. |

---

## What We're NOT Doing (and why)

| Skipped | Reason |
|---------|--------|
| Desktop analytics | Desktop app has no Firebase setup; bridge supervision still in progress. Follow-up phase. |
| Client-side `first_assistant_message` dedup flag | BigQuery `MIN(event_timestamp)` per user handles dedup. No client state to sync. |
| Bridge-side analytics | Bridge is a CLI tool; no analytics infrastructure. Relay-level metrics would need server work. |
| Crashlytics → BigQuery | Crashlytics is error reporting, not product analytics. Separate concern. |
| Session duration tracking | GA4 `session_start` + `session_end` (automatic) already provides this. |
| Custom user properties (e.g., "primary_provider") | Adds complexity without clear investor value. Can derive from event parameters. |
