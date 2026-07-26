# Bridge-Ready Mobile Onboarding

## Status

- **Plan slug:** `bridge-ready-onboarding`
- **Status:** architecture review corrections applied; in review on plan PR
  [#580](https://github.com/sesori-ai/sesori_apps_monorepo/pull/580)
- **Plan date:** 2026-07-26
- **Implementation base:** `origin/main` at
  `f8c71eb78987aa8c64e397e8e8e3bb72eefa0692`
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Delivery:** two sequential bridge-only PRs

## Goal

Make standalone interactive first setup show the mobile-app QR/link only after
the bridge is locally ready to serve a phone through the relay. A user who
installs or opens the app from that prompt should find an already-running
bridge, rather than an app that reports the bridge offline while the bridge is
still paused waiting for mobile notification registration.

The implementation must also keep bridge availability independent from mobile
push-token registration. The app-registration check remains useful for deciding
whether the one-time prompt is needed, but it must not gate relay startup.

## Success Criteria

1. For a standalone interactive start that needs app onboarding, bridge
   registration succeeds, the relay WebSocket is established, the bridge auth
   frame is sent, startup listeners are initialized, and the first inbound relay
   read is armed before the QR/link is rendered.
2. The bridge can complete key exchange and serve phone traffic while the QR is
   visible. Mobile push-token registration is not a prerequisite for relay
   availability.
3. If initial bridge registration, relay connection, or local serving startup
   fails, the install/open prompt is not shown; the existing startup failure is
   surfaced instead.
4. A missing mobile registration produces one prompt and no long-poll or retry
   loop. The bridge remains running whether or not the app registers a push
   token during that process lifetime.
5. Existing marked accounts and accounts already reporting a registered mobile
   client remain silent. A mobile client installed during the current run is
   recognized and marked by the immediate check on a later bridge start.
6. Supervised and non-interactive bridge starts retain their current behavior
   and never show the standalone app prompt.
7. Registration ordering, reconnect/backoff behavior, relay takeover handling,
   token re-authentication, signal-driven shutdown, and teardown error
   propagation remain unchanged.
8. Each implementation PR remains below 1,500 changed lines, counting additions
   plus deletions against its PR base, including tests.

## Current Behavior

- `BridgeRuntimeRunner` awaits `AppClientOnboardingService.run` immediately
  after plugin setup inspection and availability checks
  (`bridge/app/lib/src/bridge/runtime/bridge_runtime_runner.dart:691-714`).
- When the auth server reports no app client, the service prints the generic
  app-store QR/link and enters an unbounded loop of 30-second server long-polls,
  refreshing auth and retrying failures every five seconds
  (`bridge/app/lib/src/services/app_client_onboarding_service.dart:56-106`).
- The status endpoint is backed by notification-device-token presence, not a
  phone-to-bridge handshake
  (`client/module_core/lib/src/services/notification_registration_service.dart:97-106`;
  auth-server repository `sesori-ai/sesori_auth_server` reference
  `src/services/app-client-presence-service.ts:36-50`).
- Single-live ownership, bridge registration, `RelayClient` construction,
  runtime composition, and `OrchestratorSession.run` all happen after that gate
  (`bridge_runtime_runner.dart:715-904`).
- `OrchestratorSession.run` currently combines two distinct lifecycle phases:
  finite initial registration/connection/listener setup and the long-lived
  relay read/reconnect/teardown loop
  (`bridge/app/lib/src/bridge/orchestrator.dart:712-966`).
- The phone already authenticates to the relay without a bridge, parks its
  socket, and immediately reconnects for E2E key exchange after the relay sends
  `bridge_connected`. No relay or client change is required for wake-up
  (`client/module_core/lib/src/capabilities/server_connection/connection_service.dart:293-327,496-517`).
- The displayed QR is a generic app URL with no bridge or startup-session
  identifier (`bridge/app/lib/src/foundation/app_onboarding_formatter.dart:12`).

## Locked Decisions And Boundaries

- This plan changes only `bridge/app`. It adds no relay role, relay control
  frame, auth-server endpoint, shared wire model, client connection state, or
  mobile UI state.
- "Ready" is an explicit local bridge guarantee: auth registration has
  succeeded; the WebSocket connection has opened; the bridge auth frame has
  been sent; startup subscriptions/listeners and the initial summary have been
  initialized; and the first inbound relay read is armed. The current relay
  protocol has no bridge-auth acknowledgement, so this plan does not claim a
  cryptographic server acknowledgement before rendering the QR.
- The refactor PR is standalone and preserves user-visible startup behavior. It
  contains lifecycle separation, complete partial-start teardown ownership, and
  lockstep test updates only. It does not move onboarding, change terminal copy,
  or remove the app-registration wait.
- The feature PR consumes the final lifecycle API from the refactor PR. It does
  not reopen or broaden the lifecycle design.
- `OrchestratorSession` remains the sole owner of relay serving, reconnect, and
  teardown. `BridgeRuntimeRunner` sequences lifecycle phases but does not own a
  second relay loop or duplicate teardown.
- Sequential relay-frame handling must remain sequential. Arming the initial
  read must not replace the current `await for` semantics with uncoordinated
  asynchronous `listen` callbacks.
- `AppClientOnboardingService` is preparation-only. It performs the local marker
  lookup and one immediate status request, returns a typed presentation
  decision, and owns no formatter or `Console` output. The runner captures that
  finite preparation future and starts the session without awaiting it, so
  mobile-registration infrastructure cannot gate relay readiness.
- A private `BridgeRuntimeRunner` method at the CLI composition boundary renders
  the prompt synchronously only after session startup and preparation both
  complete while the lifecycle remains active. Do not add a one-consumer
  presenter class. The captured immediate check may overlap session startup,
  but there is no timer, long-poll, uncaptured task, cancellation owner, or new
  process-lifetime service.
- Existing endpoint-unavailable behavior remains fail-open and
  presentation-silent: it emits no onboarding `Console` prompt/success content
  and never blocks or fails startup. It preserves the existing `Log.w`
  diagnostic, which remains observable at the configured log level. This plan
  does not change the released 404/405 compatibility fallback for older or
  custom auth deployments.
- The existing per-auth-backend/user marker remains authoritative. When a user
  installs the app after preparation reported absence, the next immediate
  status check writes the marker; no current-run background observer is needed.
- Internal Dart contracts have no external consumers. Replace `run` call sites
  in lockstep; do not retain a compatibility wrapper or deprecated alias. Step
  2 also removes the internal status API/repository `wait` parameter and the
  `wait=true` query branch once their only production consumer is gone.
- The series target is 1,000 changed lines or fewer per PR. At 1,300 projected
  changed lines, stop and reassess before implementation crosses the user's
  1,500-line ceiling. Do not move refactoring into the feature PR to stay under
  the first PR's estimate.
- Keep one implementation PR open at a time. Step 2 starts from updated
  `origin/main` after Step 1 merges; it is not opened as a stacked PR.

## Delivery Sequence

| Step | Branch | Exact PR title | Estimate | Review boundary |
|---|---|---|---:|---|
| 1/2 | `bridge-ready-onboarding-session-lifecycle` | `[bridge-ready-onboarding] refactor(bridge): separate session startup from serving [step 1/2]` | 500-800 | Standalone lifecycle refactor with no onboarding behavior change. |
| 2/2 | `bridge-ready-onboarding-relay-first` | `[bridge-ready-onboarding] fix(bridge): start relay before mobile onboarding [step 2/2]` | 450-750 | Relay-ready prompt ordering, removal of the notification-registration gate, and deletion of the unused long-poll API variant. |

"Standalone" in Step 1 means the PR is refactor-only, independently valid, and
safe to merge without Step 2. Because it is an enabling part of this intentional
two-PR delivery, it still uses the required series title and `[step 1/2]`
wrapper.

## Step 1/2: Separate Session Startup From Serving

### Purpose

Give the composition root an honest readiness boundary without mixing the UX
change into a lifecycle refactor. Today `OrchestratorSession.run` does not return
until shutdown, so the runner cannot both establish readiness and then render
the prompt without launching an unowned long-lived future.

### Lifecycle Contract

Replace `OrchestratorSession.run` with a typed, one-shot startup operation and a
separate wait operation:

```dart
enum OrchestratorSessionStartResult { ready, cancelled }

Future<OrchestratorSessionStartResult> start();
Future<void> waitUntilStopped();
```

Calling `start` synchronously creates, stores, and internally observes one
lifecycle future before the first startup operation can acquire a resource or
fail, then returns the separate readiness future. Before awaiting readiness, the
runner immediately captures `waitUntilStopped`, which is available as soon as
`start` has been invoked and exposes that same lifecycle future to the shutdown
coordinator. That lifecycle future owns startup, serving, and teardown under one
`try/finally`:

1. register the bridge with auth;
2. connect `RelayClient`, which opens the socket and sends the existing bridge
   auth frame;
3. initialize the existing completion, maintenance, project-activity,
   permission, plugin-event, PR, unseen, and token re-auth subscriptions;
4. build and publish the initial project summary exactly as today;
5. create the initial connection's `StreamIterator` from `RelayClient.read()`
   and invoke its first `moveNext()` to establish the inbound subscription; and
6. complete the startup handshake immediately after invoking that first
   `moveNext()`, without awaiting an inbound frame.

The serving loop awaits that same pending first `moveNext()`, processes the
current frame completely, then invokes/awaits the next `moveNext()`. This locks
the readiness point without waiting for a phone or relay frame and preserves
sequential frame processing. Each connection owns its own iterator: when the
stream ends, cancel that iterator before reconnecting; after every successful
`RelayClient.reconnect()`, create a fresh iterator from the replacement
channel, invoke its first `moveNext()`, and serve that pending read. Only the
initial iterator completes the startup-readiness handshake. The lifecycle
`finally` also cancels whichever iterator is currently active before/with the
existing failure-isolated teardown. Do not replace the loop with uncoordinated
asynchronous `listen` callbacks, continue an exhausted iterator after reconnect,
or treat WebSocket opening alone as readiness.

Immediately after `start` is invoked, `waitUntilStopped` exposes that same
internally observed lifecycle future, including its pre-readiness startup and
cleanup. It continues to own:

- relay frame processing and key exchange;
- reconnect and takeover backoff;
- bridge-revocation re-registration;
- all existing failure-isolated teardown; and
- propagation of the first teardown error.

The lifecycle is one-shot. A second `start` fails immediately;
`waitUntilStopped` before the first `start` invocation fails immediately; every
call after that invocation observes the same lifecycle completion, including
pre-readiness failure/cleanup. `beginShutdown` and `cancel` remain callable by
the existing shutdown coordinator and signal handlers and must still wake
startup, an active normal backoff, or a takeover backoff promptly.

If registration, connection, listener initialization, summary construction, or
initial read arming fails before readiness, the lifecycle future runs complete
partial-start teardown before `start` rethrows that failure.
The already-captured wait future lets a concurrent shutdown drain that teardown
before later phases dispose plugin/shared resources. If shutdown is requested
before readiness, the lifecycle future tears down acquired resources, `start`
returns `cancelled`, the runner shows no onboarding prompt, and the existing
clean or supervised-sentinel shutdown outcome is preserved.

`BridgeRuntimeRunner` adopts the new API in behavior-preserving sequence:

```text
existing app-onboarding gate
-> startFuture = session.start
-> sessionRun = session.waitUntilStopped (capture before awaiting readiness)
-> await startFuture
-> ready: await sessionRun
-> cancelled: return through the existing clean/sentinel outcome
```

The shutdown coordinator's drain phase continues to await the captured serving
future. The internally observed lifecycle future exists before startup can fail,
so neither a partial-start failure nor the interval before runner capture can
surface as an unhandled asynchronous error.

### Expected Files

Production:

- `bridge/app/lib/src/bridge/orchestrator.dart`
- `bridge/app/lib/src/bridge/runtime/bridge_runtime_runner.dart`

Lockstep tests and harnesses:

- `bridge/app/test/bridge/orchestrator_registration_test.dart`
- `bridge/app/test/bridge/orchestrator_error_recovery_test.dart`
- `bridge/app/test/bridge/orchestrator_emit_bridge_event_test.dart`
- `bridge/app/test/bridge/orchestrator_token_reauth_test.dart`
- `bridge/app/test/bridge/debug_server_test.dart`
- a focused orchestrator lifecycle test if the contract is clearer outside the
  existing registration/error suites

No new production collaborator or interface is planned. If clean ownership
requires moving substantial pre-existing responsibilities into a new class,
stop and update this plan rather than hiding that refactor in Step 2.

### Acceptance

- Existing standalone/supervised user-visible runner ordering is unchanged.
- `start` does not complete before registration, connect/auth send, startup
  initialization, and initial read arming.
- Registration, initial relay, listener, summary, or read-arming failure runs
  partial-start teardown and then throws from `start`; the wait future captured
  at start invocation observes that same lifecycle completion for coordinator
  draining.
- Shutdown before readiness tears down, returns `cancelled`, and never shows a
  prompt or becomes a startup error.
- Key exchange and request handling work after `start` while a caller has not
  yet awaited `waitUntilStopped`.
- A normal drop, token re-authentication, and every successful reconnect create
  a fresh iterator for the replacement relay channel and process a frame from
  it; no exhausted iterator is reused.
- All current reconnect, revocation, takeover, token re-auth, event ordering,
  and shutdown tests retain their behavior under the split API.
- Every former `session.run()` production/test caller is updated in lockstep;
  no compatibility method remains.

### Verification

From `bridge/app`:

```bash
dart test test/bridge/orchestrator_registration_test.dart \
  test/bridge/orchestrator_error_recovery_test.dart \
  test/bridge/orchestrator_emit_bridge_event_test.dart \
  test/bridge/orchestrator_token_reauth_test.dart \
  test/bridge/debug_server_test.dart
dart analyze --fatal-infos
```

Run `aristotle-impl-review` against the Step 1 branch versus `main` because this
PR changes lifecycle ownership and a production class contract.

## Step 2/2: Render Onboarding After Relay Readiness

### Purpose

Use the lifecycle seam from Step 1 to ensure the bridge is already serving when
the install/open prompt appears, and remove the incorrect dependency on mobile
notification registration.

### Onboarding Preparation

Refactor `AppClientOnboardingService` into a finite, preparation-only decision.
Use a concrete enum such as `AppClientOnboardingDecision { skip, prompt }`; do
not use an empty string or nullable modern domain state. Its exact public
operation becomes:

```dart
Future<AppClientOnboardingDecision> prepare({
  required String accessToken,
  required String authBackendUrl,
});
```

Preparation preserves:

- JWT `userId` parsing and warning behavior;
- per-auth-backend/user marker lookup;
- one immediate app-client status request;
- immediate marker write when a registered app is already present;
- independent marker read/write warnings; and
- existing endpoint-unavailable compatibility behavior.

Preparation removes:

- `TokenRefresher` from this service;
- `AppOnboardingFormatter` and all `Console` output from this service;
- the unbounded polling loop;
- the five-second retry timer; and
- the terminal claims that startup is paused or later continuing.

Remove the now-unused long-poll variant from the internal lower layers in the
same PR: `AppClientStatusRepository.getStatus` and
`SesoriServerApi.getAppClientStatus` become immediate-status operations without
a `wait` parameter, and the API no longer builds a `wait=true` query.

Preparation emits no QR or onboarding copy and recovers every status/marker
failure into its typed decision after preserving the existing warning. The
runner starts this captured preparation future and the session lifecycle without
awaiting the status result first. For a `prompt` decision, a private
`BridgeRuntimeRunner` method constructs/uses the existing formatter and writes
the generic QR/link only after the bridge session is ready and its lifecycle
future has been captured. Copy must state that the bridge is running and that
the user should install/open Sesori and sign into the same account. It must not
claim that notification registration, relay pairing, or E2E connection has
already completed.

### Runner Ordering

For standalone interactive starts only:

```text
plugin inspect/availability
-> ownership, diagnostics, database, and runtime composition
-> capture onboarding preparation future (finite immediate check; do not await)
-> capture startFuture = session.start and sessionRun = session.waitUntilStopped
-> await startFuture while onboarding preparation runs concurrently
-> ready: race/coordinate the preparation result with sessionRun
-> preparation wins while lifecycle remains active: synchronously render the prompt decision
-> sessionRun completes first: render no prompt and surface/preserve its outcome
-> await the captured serving future
```

Supervised and non-interactive starts skip preparation/presentation and use the
same `capture start -> capture wait -> await ready/cancelled -> await wait`
lifecycle.

If session startup fails, the prompt is never rendered. If presentation itself
throws, the existing outer runner `finally` shuts down and drains the already
captured serving future. A `cancelled` startup result also renders no prompt and
returns through the existing clean/sentinel outcome. A slow immediate status
request can delay only the decision to show the prompt after readiness; it can
never delay bridge registration, relay connection, or the inbound read loop.

### Expected Files

Production:

- `bridge/app/lib/src/services/app_client_onboarding_service.dart`
- `bridge/app/lib/src/repositories/app_client_status_repository.dart`
- `bridge/app/lib/src/api/sesori_server_api.dart`
- `bridge/app/lib/src/bridge/runtime/bridge_runtime_runner.dart`

Tests:

- `bridge/app/test/services/app_client_onboarding_service_test.dart`
- `bridge/app/test/repositories/app_client_status_repository_test.dart`
- `bridge/app/test/api/sesori_server_api_test.dart`
- `bridge/app/test/bridge/runtime/bridge_runtime_runner_test.dart` for the
  standalone/supervised/non-interactive decision guard
- the Step 1 lifecycle suite for the after-start serving guarantee

Do not extract a production coordinator or presenter solely to make runner
ordering easier to mock. Verify the meaningful seams directly: lifecycle
readiness in the orchestrator suite, output-free preparation in the onboarding
service suite, immediate-only status API/repository behavior in their owning
suites, and formatter/copy output at the existing CLI composition boundary.

### Acceptance

- Missing app registration performs exactly one immediate status request and
  returns a prompt decision.
- The immediate status request starts without being awaited before
  `session.start`; its 35-second deadline cannot delay relay readiness.
- Preparing a prompt emits no stdout onboarding content.
- The service has no formatter or `Console` dependency; the runner's private
  presentation method emits the QR/link and revised ready-state copy.
- The status API/repository expose no `wait` parameter and never send
  `wait=true`.
- Marker-present and immediate-registered paths remain silent; immediate
  registration still writes the marker.
- Status-unavailable and marker-failure behavior remains observable and
  non-fatal according to the current compatibility behavior.
- The runner starts and captures the session-serving future before prompt
  presentation.
- If the lifecycle ends while preparation is pending, no prompt is rendered and
  the lifecycle completion remains authoritative.
- A phone can join, complete key exchange, and issue the health request while
  the prompt is visible and without registering a notification token.
- Signal/restart shutdown drains the same serving future and does not wait for
  an onboarding poll or timer.

### Verification

From `bridge/app`:

```bash
dart test test/services/app_client_onboarding_service_test.dart \
  test/repositories/app_client_status_repository_test.dart \
  test/api/sesori_server_api_test.dart \
  test/bridge/runtime/bridge_runtime_runner_test.dart \
  test/bridge/orchestrator_registration_test.dart \
  test/bridge/orchestrator_error_recovery_test.dart
dart analyze --fatal-infos
```

Advisory manual check with a fresh standalone data directory/account:

1. Start the bridge and confirm relay startup output precedes the QR/link.
2. Install/open the mobile app and sign into the same account.
3. Confirm the app reaches the bridge without a prolonged bridge-offline state.
4. Withhold or fail push-token registration and confirm bridge relay/key-exchange
   availability is unaffected.
5. Delay/fail the immediate app-status request and confirm relay readiness is
   established before that request completes.
6. Restart after app registration and confirm the prompt is skipped and the
   marker is written by the immediate status check.

Run `aristotle-impl-review` against the Step 2 branch versus `main` because this
PR changes the composition-root lifecycle trigger and onboarding data flow.

## Compatibility And Security

- No client/bridge transport contract changes. Old and new mobile apps continue
  using the existing `bridge_connected`/`bridge_disconnected`, key exchange,
  health, and SSE flows.
- No auth or relay deployment ordering is introduced. The current auth status
  request and bridge registration endpoints remain unchanged.
- No source data, paths, prompt content, or startup phase is exposed to the
  relay. The bridge still authenticates with the existing account token and
  bridge ID.
- The local lifecycle API updates every in-repository caller in lockstep, as
  required for internal Dart contracts.
- The generic QR remains account-based and contains no bridge identifier or
  secret.

## Material Risks

- **Readiness overclaim:** WebSocket open plus auth-frame send is not a relay
  acknowledgement. The plan therefore defines and tests local readiness only.
  An exact remote "bridge accepted" acknowledgement would require a separate
  relay protocol change and is out of scope.
- **Lifecycle-future ownership:** Startup and serving begin before prompt
  presentation. Step 1 creates and internally observes one lifecycle future
  before resource acquisition, keeps startup/serving/teardown under its
  `try/finally`, and exposes it to the runner immediately after `start` is
  invoked. The runner captures it before awaiting readiness or presenting, so
  concurrent shutdown, errors, and cleanup are never orphaned.
- **Reconnect iterator ownership:** A read iterator is bound to one relay
  channel. Step 1 cancels the exhausted iterator and creates/arms a fresh one
  after every reconnect; only the initial iterator controls startup readiness.
- **Concurrent preparation:** The one bounded immediate status request overlaps
  session startup so it cannot gate relay readiness. The runner renders only
  when both readiness and a prompt decision exist while the lifecycle remains
  active; lifecycle completion suppresses a stale prompt.
- **Teardown drift:** Moving code across `run` can accidentally omit or duplicate
  teardown. Step 1 keeps all teardown on the single lifecycle future and verifies
  existing failure/reconnect/shutdown suites before any UX change.
- **Prompt timing:** The QR appears later than today because ownership,
  diagnostics, database composition, registration, and relay startup now finish
  first. That delay is intentional to provide the selected ready-before-QR
  guarantee; existing terminal startup output remains the progress signal.
- **Marker timing:** A newly installed app is not marked during the same process
  because background polling is removed. The next immediate startup check
  writes the marker. This affects only whether a later prompt is skipped and
  does not affect connectivity.

## Out Of Scope

- Mobile copy or visual-state changes.
- A relay-level `bridge_starting` role or control frame.
- Auth startup leases, bridge-status polling, or heuristic use of
  `lastSeenAt`.
- Eager backend-plugin startup or catalog behavior changes.
- Desktop supervised startup UX.
- New analytics/telemetry contracts.
- General `Orchestrator` decomposition or cleanup unrelated to the explicit
  start/wait lifecycle seam.
