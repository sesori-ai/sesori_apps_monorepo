# Bridge App Onboarding

## 0. Plan Metadata

- **Status:** Finalized under user-authorized one-review/fix process — plan PR open
- **Format version:** 1
- **Generated:** 2026-07-17
- **Plan slug:** `bridge-app-onboarding`
- **Plan host:** `sesori-ai/sesori_apps_monorepo`
- **Selected implementation base:** `main`

| Repository | Implementation base | Initial audited tip | Commit date | Latest re-review | Latest audited tip | Commit date |
|---|---|---|---|---|---|---|
| `sesori-ai/sesori_apps_monorepo` | `main` | `5a76c0c420cd7db445f7fe2c8a2570265b4c84e0` | 2026-07-17T06:57:01Z | 2026-07-17 | `5a76c0c420cd7db445f7fe2c8a2570265b4c84e0` | 2026-07-17T06:57:01Z |
| `sesori-ai/sesori_auth_server` | `master` | `b17a6e760b0c70c3dc3d1cd456ff93d814c75453` | 2026-07-16T14:14:09Z | 2026-07-17 | `b17a6e760b0c70c3dc3d1cd456ff93d814c75453` | 2026-07-16T14:14:09Z |

These SHAs are audit and staleness metadata, not historical branch points. Each
wave pins the then-current tip of its declared repository/base after assessing
drift from the latest audited tip. The monorepo implementation branch is always
based on the user-selected `main`; the auth-server branch is independently based
on that repository's `master`.

## 1. Goal

Help a user who starts the standalone bridge without any registered Sesori app
client install and sign in to the app before the bridge finishes starting. The
bridge must present a scan-ready terminal QR plus the exact clickable app URL,
then wake almost immediately when the same account durably registers an iOS,
Android, macOS, Windows, or Linux app token.

The checkpoint remains explicitly skippable for the current run and never
weakens headless or desktop-supervised startup. Network outages remain
observable and recoverable without tight request loops or continuously spammed
warnings.

## 2. Success Criteria

1. An authenticated standalone interactive bridge performs a current app-token
   check after the selected plugin passes its quick availability probe and
   before runtime provisioning or plugin startup.
2. If any current app token exists for the same account on iOS, Android, macOS,
   Windows, or Linux, startup continues without new output.
3. If no token exists, the terminal immediately prints same-account setup
   instructions, a QR when terminal capabilities and width allow it, and the
   byte-identical URL `https://sesori.com/app/?openStore=true` beneath the QR.
4. A token registration committed after the bridge begins waiting wakes all
   same-user long polls without a client-side polling interval; the bridge
   prints a brief success line and resumes startup.
5. Once confirmed absence or a transient warning exposes onboarding/skip
   guidance, `s` or `skip`, case-insensitive after trimming and followed by
   Enter, cancels any active token-refresh/status request or retry delay, waits
   for cancellation settlement, and skips only the current run. Input typed
   during the initial silent check remains queued for the next real prompt.
6. A normal 30-second server long-poll expiry returns `registered: false`, emits
   no warning, and is followed immediately by another long poll.
7. Network failures, client-side request timeouts, HTTP 408/429, and HTTP 5xx
   produce at most one warning for that failed attempt, wait a fixed 60 seconds,
   and retry indefinitely until registration or explicit skip. The delay is
   cancellable by skip.
8. Permanent protocol failures, unsupported older/custom servers, and a second
   401 after one forced token refresh warn once and fail open instead of
   blocking startup.
9. Desktop-supervised, noninteractive, legacy post-update, piped, and otherwise
   unsupported terminal starts perform no onboarding wait or output.
10. Existing provider, email/password, replacement, and logout prompts retain
    their text, echo, EOF, default-answer, and noninteractive behavior after
    terminal input moves under one asynchronous owner.
11. QR output includes a four-module light quiet zone, never exceeds known
    terminal width, and renders only through explicit black/white ANSI plus
    Unicode when both capabilities are proven. Unknown polarity, missing ANSI/
    Unicode, or unsafe width uses the plain-URL-only fallback.
12. Auth-server and bridge automated verification passes, and the advisory QR
    scan matrix records representative dark/light and platform evidence without
    adding product analytics or post-release observation targets.

## 3. Scope

### In Scope

- An additive authenticated auth-server app-client status endpoint with an
  immediate mode and a 30-second long-poll mode.
- A repository existence query over current device-token records.
- A race-safe, process-local app-client presence service that owns durable token
  registration signaling, timeout cleanup, and disconnect cancellation.
- Reuse/extraction of the auth server's proven request-close abort seam.
- A consolidated per-provider `SesoriAuthApi` -> Repository -> Service ->
  runtime-consumer flow for current registration checks, cancellable token
  refresh, failure classification, retry, and skip.
- One asynchronous bridge terminal-input owner reused by existing prompts.
- A pure-Dart QR dependency and terminal formatter with capability/width
  fallbacks.
- Additive shared Freezed email-login/refresh request DTOs plus a bridge-local
  typed response, with all generated JSON output produced by tools rather than
  hand-edited.
- Focused unit, route, service, lifecycle, runner, formatting, and regression
  tests plus one advisory manual checkpoint.
- Compatibility behavior and an exact cleanup marker for bridges talking to an
  auth server that predates the new endpoint.

### Non-Goals

- A live app heartbeat, socket-presence signal, last-seen policy, or proof that
  a registered FCM token still corresponds to an installed/running app.
- Changing app token registration/logout behavior or adding mobile/desktop UI.
- Opening a browser or app store from the bridge.
- Persisting skip, suppressing future prompts, or adding a bridge CLI/config
  option for this checkpoint.
- Running the checkpoint in desktop-supervised or noninteractive bridge modes.
- Reusing lifetime `mobileSetupAt` activation history as current presence.
- New database collections, indexes, migrations, Redis, change streams, leases,
  or horizontal-scaling abstractions.
- A server-sent-event/WebSocket presence channel or importing/refactoring a
  plugin SSE implementation into auth.
- QR images/files, OSC hyperlinks, terminal probing commands, or unbounded
  support claims for every terminal/font/camera combination.
- Auth, relay, plugin, shared wire, mobile, desktop, trust-posture, or
  multi-bridge protocol changes unrelated to this onboarding flow.
- Analytics, telemetry, rollout percentages, post-release targets, dashboards,
  or observation work.

## 4. Audited Baseline

### Plan host and branch choice

The plan was invoked on branch `bridge-onboarding-optimization`, while the
repository default base is `main`. The user explicitly selected `main` as the
implementation base. The current unrelated active plan
`.plan/active/session-pull-request-monitoring/` may continue independently;
workers assess drift at each wave rather than imposing speculative ordering.

### Auth-server current behavior

- `src/repositories/device-token-repo.ts:15-45` durably upserts app tokens and
  can list every token for a user, but has no existence-only query.
- `src/models/device.ts:3-9` defines every supported app platform: `ios`,
  `android`, `macos`, `windows`, and `linux`.
- `src/routes/notifications.ts:55-72` authenticates token registration, awaits
  `DeviceTokenRepository.upsertToken`, then best-effort records the lifetime app
  setup milestone. It publishes no post-commit signal.
- `src/routes/notifications.ts:75-83` deletes a user's token on app logout.
- `src/services/activation-service.ts` and activation state model lifetime
  history. A historical `mobileSetupAt` remains present after token removal and
  therefore cannot answer current registration.
- `src/routes/auth/session-status.ts:42-101` implements an existing 30-second
  OAuth long poll, checks connection liveness before reply delivery, and uses a
  request-close `AbortSignal`.
- `src/services/pending-auth-store.ts:419-508` demonstrates race-safe waiter
  registration, timeout/abort cleanup, and a post-registration state recheck.
  That OAuth store is session-token keyed and must not be reused for user app
  presence.
- `src/server.ts:68-72` has a global 100-request/minute limiter. One normal
  status request per 30 seconds and one transient retry per 60 seconds remain
  within that existing policy.
- `AGENTS.md:67-72` records a single-instance production constraint for current
  in-memory wait/debounce systems. This plan preserves that constraint rather
  than inventing distributed signaling.
- The auth application version declared in `package.json` is `0.1.0`; no schema
  or package dependency change is required.

### Bridge current behavior

- `bridge/app/lib/src/bridge/runtime/bridge_runtime_runner.dart:238-268`
  constructs one `TerminalPromptApi`/`TerminalPromptRepository` and the
  interactive auth flow.
- `bridge_runtime_runner.dart:442-468` authenticates standalone or supervised
  startup, then logs the authenticated user. No app-registration checkpoint
  exists.
- `bridge_runtime_runner.dart:479-501` resolves and checks the selected plugin
  before runtime provisioning/startup. This quick failure boundary should stay
  ahead of onboarding.
- `bridge_runtime_runner.dart:503-559` provisions and starts the plugin, including
  later single-live-bridge prompts. The onboarding wait must not hold the
  startup mutex or begin provisioning.
- `bridge_runtime_runner.dart:568-605` currently creates standalone
  `TokenManager`/registration dependencies only after plugin startup. This PR
  renames that substantially changed class to `TokenService`, composes it earlier,
  and reuses one instance rather than duplicating token authority, so the
  onboarding service can perform the one authorized 401 refresh while the
  repository remains token-authority neutral.
- `bridge/app/lib/src/server/api/terminal_prompt_api.dart:18-47` currently detects
  interactivity but reads lines synchronously. `bridge_runtime_auth.dart:38-71`
  also reads provider choice directly from global stdin.
- `terminal_prompt_repository.dart:10-67` owns replacement and email/password
  prompts, while `login_email_repository.dart:7-18` receives a synchronous
  credential callback. These paths require a behavior-preserving asynchronous
  migration before a cancellable skip listener can coexist with later prompts.
- Dart's `Stdin` contract allows synchronous and asynchronous reads but declares
  mixing them undefined. A temporary async skip listener followed by existing
  `readLineSync` calls is therefore rejected.
- `bridge/app/lib/src/auth/login_oauth_service.dart:13-17,208-253` already uses a
  30-second-server/35-second-client long-poll relationship, but its polling
  service does not classify or delay network failures for this new indefinite
  checkpoint.
- `bridge/app/lib/src/auth/bridge_registration_service.dart:152-162` provides
  the established one-refresh-on-401 repository/service pattern.
- `bridge/app/pubspec.yaml` declares `http: ^1.6.0`; that version exposes
  `AbortableRequest` and `RequestAbortedException`. No QR dependency exists.
- `TerminalGlyphValidator` and `TerminalColorValidator` already centralize
  UTF-8/ANSI capability policy. `Stdout.terminalColumns` supplies width without
  an external terminal-size package.
- The bridge version is `1.5.1` in `bridge/app/pubspec.yaml` and
  `bridge/app/lib/src/version.dart`. Workers re-read it immediately before
  writing the compatibility marker.

### Historical evidence

The audited tips `b17a6e760b0c70c3dc3d1cd456ff93d814c75453` and
`5a76c0c420cd7db445f7fe2c8a2570265b4c84e0` are the shipped-history points for
the behavior above. Auth-server history and active instructions explicitly
distinguish current device-token rows from lifetime activation milestones; the
bridge history retains headless operation, configurable auth endpoints, one
token-refresh authority, and terminal capability validators. This plan extends
those seams instead of introducing a second source of truth.

## 5. Architecture and Data Flow

### Auth-server boundaries

All new dependencies flow Foundation -> API/Repository -> Service -> route
consumer. Same-layer classes remain independent.

| Component | Layer / expected path | Ownership |
|---|---|---|
| `createRequestCloseSignal` extraction | Foundation, `src/lib/request-close-signal.ts` | Convert Fastify socket/reply close/finish events into one cleaned-up `AbortSignal`; no route or domain decisions. Reused by OAuth status and app-client status routes. |
| `appClientStatusQuerySchema` / `appClientStatusReplySchema` | API contract, existing `src/models/api.ts` | Strict Zod query/reply schemas with inferred TypeScript types; route uses `safeParse` for both inbound query and outbound candidate reply. |
| `DeviceTokenRepository.hasAnyForUser` | Repository, existing `src/repositories/device-token-repo.ts` | Perform one indexed existence query and return a boolean; no waiter or retry policy. |
| `AppClientPresenceService` | Service, `src/services/app-client-presence-service.ts` | Own token registration used by notification routes, wake same-user waiters only after successful durable upsert, perform immediate/recheck reads, and clean up per-request timeout/abort state. Token deletion remains a direct existing route -> repository call because it has no waiter logic. |
| App-client route | Consumer/API boundary, `src/routes/app-clients.ts` | Authenticate, `safeParse` the strict optional `wait=true` query, call the service with the request-close signal, check reply liveness, `safeParse` `{registered}` against the reply schema, and serialize the validated boolean response. |
| `notificationRoutes` | Existing consumer | Delegate registration to `AppClientPresenceService`, keep deletion directly on `DeviceTokenRepository`, and retain activation failure isolation/notification sending behavior. |
| `index.ts` / `server.ts` | Composition root | Construct one shared service instance and inject it into both routes. No route constructs a repository/service. |

The endpoint contract is additive:

```text
GET /auth/app-clients/status
Authorization: Bearer <user access token>

200 { "registered": true }   # current token exists
200 { "registered": false }  # immediate absence

GET /auth/app-clients/status?wait=true
200 { "registered": true }   # immediate current token or post-commit wake
200 { "registered": false }  # no token when the 30-second wait expires
401                           # missing/invalid user token
400                           # invalid query shape
```

No token value, platform, user id, activation timestamp, or waiter identifier is
returned.

### Auth-server registration and waiter flow

```text
bridge GET status?wait=true
  -> requireAuth identifies user
  -> AppClientPresenceService starts one absolute 30s deadline, then checks DeviceTokenRepository.hasAnyForUser
  -> initial read misses deadline: service emits typed domain timeout; route maps it to existing 500
  -> absent before deadline: register per-user waiter for only the remaining budget + abort cleanup
  -> recheck repository after waiter registration
  -> return false on 30s timeout, or hijack/return nothing after disconnect

app POST /notifications/register-token
  -> requireAuth identifies same user
  -> AppClientPresenceService.registerToken
  -> DeviceTokenRepository.upsertToken commits
  -> service resolves every same-user waiter true
  -> route best-effort records lifetime activation
  -> app receives existing { ok: true }
```

The register-then-recheck sequence closes the only meaningful lost-wakeup gap.
An upsert failure never wakes a waiter. A user with multiple bridge polls wakes
all of them; another user's waiters are untouched. Timeout, abort, and failed
recheck paths remove listener/timer/map state.

### Bridge boundaries

| Component | Layer / expected path | Ownership |
|---|---|---|
| `EmailLoginRequest` / `RefreshTokenRequest` | Shared API DTOs, `shared/sesori_shared/lib/src/models/auth/` | Freezed request bodies with exact existing `email`/`password` and `refreshToken` JSON keys. Export from `sesori_shared.dart`; bridge auth API serializes them instead of inline maps. No relay/mobile/desktop behavior changes. |
| `AppClientPresenceResponse` | API DTO, `bridge/app/lib/src/auth/app_client_presence_response.dart` | Freezed/JSON transport shape with required non-null `registered`; generated output only through build_runner. |
| `SesoriAuthApi` | Layer 1, `bridge/app/lib/src/auth/sesori_auth_api.dart` | Sole `Api` owner for the configurable Sesori auth server. Absorb existing email, OAuth, profile/me, refresh, bridge-registration and new app-status HTTP operations; own URI/header/body/typed decode plus abortable request/deadline mechanics. The PR deletes superseded use-case API classes and top-level HTTP functions rather than forwarding through them. |
| `AuthRepository` | Layer 2, `bridge/app/lib/src/auth/auth_repository.dart` | Map profile/access-token validation and typed refresh results from `SesoriAuthApi`; distinguish transient, unavailable, and cancelled refresh failures without message parsing. |
| `TokenStorage` | Layer 1 auth persistence API, `bridge/app/lib/src/auth/token_storage.dart` | Own raw token-file string read/write/clear over the existing path/permissions. It contains no JSON/provider/legacy mapping and only `TokenRepository` consumes it. |
| `TokenRepository` | Layer 2 auth repository, `bridge/app/lib/src/auth/token_repository.dart` | Map `TokenStorage` missing/corrupt/persisted state into typed token-domain results and expose read/write/clear/legacy-id operations to services. `TokenService`, `BridgeRuntimeAuthService`, bridge-id migration, and logout depend on this repository rather than Layer 1 storage or callbacks. |
| `BridgeIdStorage` / `BridgeIdRepository` | Layer 1/2 auth persistence seam, `bridge_id_storage.dart` and new `bridge_id_repository.dart` | Storage retains raw bridge-id file I/O. Repository owns typed read/write/clear mapping and is the only storage consumer; registration, migration, and logout services consume the repository. |
| `LoginOAuthRepository` | Layer 2, `bridge/app/lib/src/auth/login_oauth_repository.dart` | Map OAuth init/status/ACK calls from the consolidated API for `LoginOAuthService`. |
| Existing auth repositories | Layer 2, `login_email_repository.dart`, `bridge_registration_repository.dart` | Consume the same `SesoriAuthApi` directly and preserve their domain exception/result mapping; no forwarding API wrappers remain. |
| `AppClientPresenceRepository` | Layer 2, `bridge/app/lib/src/auth/app_client_presence_repository.dart` | Accept an access token from its caller, delegate app status to `SesoriAuthApi`, normalize registered/absent/unauthorized/unavailable/transient/cancelled outcomes, and own the old-server compatibility seam. It has no token authority, retry, output, or delay policy. |
| `TokenRefresher` / `TokenService` | Existing service contract and renamed `bridge/app/lib/src/auth/token_service.dart` implementation | Require both named `forceRefresh` and auth-local `AuthRequestCancellationSignal` on token acquisition, add typed access-failure kinds, and use abortable refresh via `AuthRepository`. Update both production implementors and every caller/fake. During onboarding the newly composed standalone service is the only token caller, so skip owns and terminates its refresh request. |
| `AppOnboardingFormatter` | Foundation/pure formatter, `bridge/app/lib/src/foundation/app_onboarding_formatter.dart` | Convert URL + QR modules + width/ANSI/Unicode capabilities into bounded explicit black/white ANSI+Unicode text with a light quiet zone, or URL-only when polarity/capability/width safety is not proven. No I/O or lifecycle. |
| `TerminalInteractionMode` / `TerminalRenderingCapabilities` | Foundation typed models | `interactive` / `unavailable` / `legacyPostUpdate` and immutable ANSI/Unicode/width facts. Composition roots never derive these models from raw terminal/environment values. |
| `TerminalPromptApi` / `TerminalPromptRepository` | Root Layer 1/2, `bridge/app/lib/src/api/terminal_prompt_api.dart` and `lib/src/repositories/terminal_prompt_repository.dart` | Move the substantially changed terminal boundaries out of the minimal `server/` subsystem. API owns raw async terminal I/O, attached-handle/environment facts, and capability reads. Repository is the sole mapper from those Layer-1 facts to typed mode/rendering capabilities and provider/credentials/yes-no/onboarding outcomes. |
| `AppClientOnboardingService` | Layer 3, `bridge/app/lib/src/services/app_client_onboarding_service.dart` | Own access-token acquisition, exactly one forced refresh/retry after 401, checkpoint state, terminal subscription, cancellation, long-poll loop, internal retry timer, output, and exactly-once completion. It depends on root repositories/Foundation plus `TokenRefresher`, not on the `server/` subsystem. |
| `BridgeRuntimeAuthService` | Root Layer 3, moved to `bridge/app/lib/src/services/bridge_runtime_auth_service.dart` | Delegate provider/credential input to root `TerminalPromptRepository`, use injected auth repositories, preserve auth decisions/persistence, and import no runtime options/type. |
| `BridgeRuntimeRunner` | Existing process-startup composer | Retain the startup ownership locked by the active desktop and parallel-plugin plans: construct auth/terminal/token/onboarding and existing process-startup collaborators; authenticate, check availability, onboard, then continue mutex/provision/plugin startup and runtime handoff. |
| Existing `Orchestrator` | Existing post-start session composer | Remain the room/session/event composer after plugin startup. `BridgeRuntime.create` stays the existing session-phase handoff factory and gains no onboarding, auth, terminal, or process-startup policy. |

The user explicitly approves a narrow B-B5 exception for the established
two-phase composition boundary required by the active desktop and parallel-
plugin plans: `BridgeRuntimeRunner` is the process-startup composer and the
existing `Orchestrator` is the post-start room/session/event composer.
`BridgeRuntime.create` remains only the existing handoff inside the latter
phase and gains no new startup ownership. No third startup orchestrator is
introduced. This waiver does not authorize other cross-layer composers.

The user explicitly approves a narrow exception to the repository's push-based
default for the existing authentication request/response flow and this
server-held app-presence long poll. `AppClientOnboardingService` may issue the
next `wait=true` request immediately after a normal 30-second false response;
the server still pushes registration through the currently held request after
durable upsert, and there is no client timer between healthy rounds. This does
not authorize pull loops elsewhere, an SSE abstraction, or moving retry/output
policy below the service.

Production constructor and lifecycle ownership is explicit:

```text
SesoriAuthApi(
  required authBackendUrl,
  required shared http.Client)
  # stores but never closes the shared client

AuthRepository(
  required SesoriAuthApi,
  required refreshRequestTimeout) # composition passes 15 seconds

TokenStorage(required tokenFilePath)
TokenRepository(required TokenStorage)
BridgeIdStorage(required bridgeIdFilePath)
BridgeIdRepository(required BridgeIdStorage)

LoginEmailRepository(required SesoriAuthApi)
LoginOAuthRepository(
  required SesoriAuthApi,
  required AuthClientType,
  required DeviceInfo)
BridgeRegistrationRepository(required SesoriAuthApi)
AppClientPresenceRepository(
  required SesoriAuthApi,
  required statusRequestTimeout) # composition passes 35 seconds

TokenService(
  required initialToken,
  required AuthRepository,
  required TokenRepository)

AppClientOnboardingService(
  required AppClientPresenceRepository,
  required TokenRefresher,
  required TerminalPromptRepository,
  required AppOnboardingFormatter,
  required retryDelay) # composition passes 60 seconds
  # owns AuthRequestCancellationController, terminal subscription, and cancellable Timer

AppOnboardingFormatter(
  required TerminalRenderingCapabilities capabilities)
  # repository-produced immutable model; no I/O or collaborator lifecycle

TerminalPromptApi(required Stdin, required Stdout, required environment)
  # also receives invocation environment facts; owns/disposes lazy input + FIFO

TerminalPromptRepository(required TerminalPromptApi)
  # maps raw API facts to typed interaction mode/rendering capabilities
```

The duration comments describe production values, not optional constructor
defaults: callers pass them explicitly. `BridgeRuntimeRunner` retains ownership
of the shared HTTP client's close lifecycle; `SesoriAuthApi` borrows it.
`AppClientOnboardingService` creates/cancels its one-shot `Timer` internally and
tests virtual time with `fake_async`; no delay callback or timer peer is added.

`TokenRefresher.getAccessToken` requires named `bool forceRefresh` and
`AuthRequestCancellationSignal cancelled`. Existing callers explicitly pass
`forceRefresh: false` and `AuthRequestCancellationSignal.never`; onboarding
passes false for ordinary attempts, true for its one forced retry, and its owned
controller's signal. `TokenService` forwards the signal through `AuthRepository`
to `SesoriAuthApi.refreshTokens`, whose `AbortableRequest` races cancellation
and an active 15-second deadline.
`ControlChannelTokenService`, the other production implementor, removes and
completes its correlated pending request on abort; it never runs onboarding but
keeps the shared contract symmetric. It maps caller cancellation to
`cancelled`, control disconnection/request timeout to `transient`, and
signed-out/null-token or disposed authority to `unavailable`; supervised
bootstrap preserves its existing auth-required exit for transient/unavailable.
`TokenAccessException` carries the kind plus safe cause/stack instead of
requiring message parsing. Every implementation, caller, and fake is updated.
`AuthRequestCancellationSignal`/`AuthRequestCancellationController` live inside
the self-contained `auth/` subsystem with `never`, `canCancel`, `isCancelled`,
a broadcast cancellation stream, and idempotent `cancel`; plugin-specific `StartAbortSignal`
remains untouched. When `canCancel` is true,
`TokenService` awaits a near-expiry refresh instead of launching the legacy
detached background-refresh branch, so onboarding completion can prove no
refresh remains. Existing `never` callers retain background behavior.

`TokenRepository` maps raw file/JSON state into typed available, missing,
corrupt, and failure outcomes. `TokenService` preserves the shipped business
distinction between initial corruption and corruption observed only on the
post-refresh re-read. Initial corruption is unavailable. A post-response
corrupt outcome retains only `lastProvider` from the valid pre-refresh snapshot
and writes the newly issued tokens through the repository to repair the file; a
missing/cleared post-refresh outcome still aborts persistence so logout cannot
be resurrected.

`runBridgeApp` and `BridgeRuntimeRunner.run` remain in
`bridge_runtime_runner.dart`, matching the active desktop and parallel-plugin
plans. The runner replaces its touched inline/API/callback seams with the
declared APIs, repositories, and services, runs onboarding at the locked point,
then continues its existing mutex/provision/plugin-start flow and invokes
`BridgeRuntime.create`. The existing session `Orchestrator` remains responsible
for room/session/event composition after that handoff. The runner retains the
existing shutdown coordinator/failure/exit lifecycle.

### Bridge state and cancellation flow

```text
BridgeRuntimeRunner composes startup graph
  -> standalone interactive + authenticated + plugin available
  -> AppClientOnboardingService gets current access token
  -> immediate AppClientPresenceRepository check(accessToken)
     -> unauthorized once: service forces token refresh and retries immediately
     -> unauthorized twice: unavailable/permanent
      -> registered: continue silently; initial typed lines remain queued
     -> unavailable/permanent: warn once, cancel input, fail open
      -> transient: show warning/skip guidance, arm input, race skip vs fixed 60s delay, retry immediate check
      -> absent: render instructions + QR/fallback + exact URL, arm input
        -> long-poll status?wait=true
           -> registered: cancel input/request, print success, continue
           -> normal absent: immediately start next long poll, no warning
           -> transient: warn once, race skip vs fixed 60s delay
           -> unavailable/permanent: warn once and fail open

terminal `s`/`skip` + Enter at any guided waiting point
  -> typed skip event
  -> cancel owned AuthRequestCancellationController and retry timer
  -> cancel input subscription
  -> print current-run skip confirmation
  -> continue startup exactly once

startup settles onboarding
  -> provision/start plugin
  -> existing BridgeRuntime.create/session Orchestrator handoff
  -> runner executes existing ready-runtime lifecycle
```

If EOF or terminal loss makes the already-started prompt unanswerable, the
service follows the noninteractive policy: cancel and fail open with one concise
warning. Invalid lines do not cancel the network request; they reprint the
accepted aliases and continue waiting.

## 6. Locked Decisions

1. The monorepo implementation base is `main`; the auth-server base is
   `master`.
2. This plan is independent of `session-pull-request-monitoring`; every wave
   still performs normal drift assessment.
3. The plan slug is `bridge-app-onboarding`.
4. Current presence means at least one current device-token row on any supported
   app platform, not lifetime setup history and not live connectivity.
5. Only standalone interactive bridge starts run the checkpoint.
6. Existing app registration continues silently.
7. Missing registration shows terminal-only setup instructions, QR when safe,
   and exact URL `https://sesori.com/app/?openStore=true`; no browser opens.
8. The app must register under the same account as the authenticated bridge.
9. Registration while waiting prints a brief success message.
10. `s` and `skip`, case-insensitive with surrounding whitespace ignored and
    followed by Enter, skip only the current run. Skip state is never persisted.
11. Interactive startup waits indefinitely for registration or explicit skip
    across transient outages.
12. Normal 30-second long-poll expiry is silent and immediately repolled.
13. Every transient non-normal failure waits a fixed 60 seconds before another
    request. There is no exponential growth or shorter retry.
14. Each failed attempt produces at most one warning; no layer double-logs it.
15. Permanent/unsupported protocol outcomes fail open after one warning.
16. One 401 triggers one forced refresh and immediate retry; a second 401 fails
    open.
17. Dart terminal input is unified under one asynchronous owner with a FIFO
    pending-line buffer, preserving ordinary type-ahead across sequential
    prompts rather than moving onboarding after plugin startup or relying on
    mixed reads. Secret reads discard all lines queued before echo is disabled
    and require fresh no-echo input.
18. `SesoriAuthApi` becomes the sole API owner for the external auth provider;
    existing use-case APIs/top-level HTTP are migrated and removed in the bridge
    PR rather than wrapped.
19. Token acquisition requires explicit named `forceRefresh` and an
    `AuthRequestCancellationSignal`; skip actively terminates refresh/status
    transport and waits for settlement. Typed refresh failures are never
    classified by parsing messages.
20. The substantially changed standalone token owner is `TokenService`, not a
    manager, and receives `TokenRepository`; only that repository consumes the
    concrete `TokenStorage`. Touched token load/save/clear callback plumbing is
    removed. Registration/migration/logout similarly consume
    `BridgeIdRepository`, never `BridgeIdStorage` directly.
21. The auth subsystem imports no `server/` or root core layer. Terminal API,
    repository, prompt contracts, and interaction mode move to root layer paths;
    the root onboarding service depends inward on auth repositories.
22. To align with the active desktop and parallel-plugin plans, the user waives
    strict B-B5 only for the established two-phase boundary:
    `BridgeRuntimeRunner` remains the process-startup composer and the existing
    `Orchestrator` remains the post-start session-control composer.
    `BridgeRuntime.create` stays an unchanged handoff within the session phase;
    no `BridgeStartupOrchestrator` or third composer is added. This exact waiver
    also retains the existing `BridgeRuntimeRunner` name while it performs the
    startup-composition role already locked by those active plans; it does not
    authorize another misnamed composer.
23. The bounded QR contract targets common interactive macOS/Linux/Windows
    terminals and renders only with explicit black/white ANSI plus Unicode when
    polarity, glyphs, and width are safe. URL-only is required for missing ANSI/
    Unicode, unknown polarity/width, or too-narrow rendering.
24. No analytics, rollout telemetry, or post-release observation work is part
    of the plan.
25. The user explicitly approves the existing authentication request/response
    flow and this bounded server-held long poll as narrow exceptions to the
    push-based default. Do not replace either with SSE or broaden the exception.
26. For this PR-feedback round, the user explicitly directs one full plan review
    followed by one finite correction pass, with no further Aristotle re-review.
    The two findings from that review are corrected in the final plan; this is a
    narrow process-gate waiver against an endless review/fix loop, not a waiver
    of the findings or implementation review.

## 7. Backward Compatibility and Migration

### Auth-server compatibility

The new endpoint and repository method are additive. Existing apps retain the
same token registration/deletion request and `{ ok: true }` response. Existing
bridges never call the endpoint. No database or environment migration occurs.

If the auth endpoint is rolled back after the bridge ships, the bridge's
old-server fallback treats 404/405 as unavailable and continues startup. The
server should nevertheless deploy before bridge release so intended onboarding
works on first use.

### Bridge compatibility

The bridge continues to accept configurable auth backends. In the repository
branch that maps 404/405 endpoint absence, add this source marker immediately
above the fallback using the actual implementation date and the version
re-read from `bridge/app/pubspec.yaml` / `version.dart`:

```dart
// COMPATIBILITY <implementation-date> (v1.5.1): Auth servers predating app-client status return 404/405, so onboarding must fail open for older/custom deployments. Remove this fallback and its endpoint-omission tests after every supported auth server exposes GET /auth/app-clients/status.
```

Affected pairs are bridge `v1.5.1+` with auth deployments before S01-W01-P01,
including custom backends that retain the otherwise-supported auth API. The
normal permanent-failure policy for malformed/forbidden requests is not itself
legacy compatibility code and is not marked.

Existing prompt text/defaults remain stable. The synchronous-to-asynchronous
terminal implementation is internal and adds no CLI/config contract. No
persisted data or wire model is migrated.

`SesoriAuthApi` consolidation and the required auth cancellation parameter
are bridge-internal source changes delivered atomically. Every email, OAuth,
profile/validation, refresh, bridge registration/deletion consumer and test fake
moves in the same PR; old use-case API files/top-level HTTP functions are deleted
instead of retained as aliases. Existing auth wire requests/responses and
user-visible failures remain regression contracts.

The shipped `v1.3.0` legacy bridge-id reader/marker moves with its compatibility
JSON mapping into `TokenRepository`; raw file access remains in `TokenStorage`.
The repository exposes the typed legacy read to `BridgeIdMigrationService`. The
marker is not duplicated or removed. Its cleanup text is updated mechanically to
remove the repository method and migration service once pre-v1.3.0 installs are
unsupported.

### Generated-code workflow

S01-W02-P01 adds shared Freezed `EmailLoginRequest` and
`RefreshTokenRequest` models under `shared/sesori_shared`, exports them from the
barrel, and uses their `toJson()` output for the two migrated auth request
bodies. It also changes the bridge-local Freezed response model and adds `qr` to
`bridge/app/pubspec.yaml`. The worker runs the shared package's build_runner
command and the bridge workspace `make codegen`, then reviews and commits only
tool-produced `*.freezed.dart` / `*.g.dart`, relevant lockfiles, and declared
source/export changes. Generated files are never hand-edited. There is no Drift
work and no shared relay/protocol contract change.

## 8. Rollout and Verification

### Release order

1. Merge and deploy S01-W01-P01 to the auth server.
2. Confirm the immediate and long-poll endpoint against the deployed auth
   environment without exposing bearer tokens in retained evidence.
3. Merge S01-W02-P01 to monorepo `main` only after the auth PR merge barrier.
4. Release the bridge through its existing process. No flag or staged cohort is
   required because old-server failure is explicitly compatible.
5. Execute the advisory QR/platform checkpoint when representative terminals
   and a disposable same-account app registration are available.

### Cross-repository tracker handoff

S01-W01-P01's implementation branch lives only in the auth-server repository,
so it cannot commit the plan-host `TRACKER.md`. After this plan PR merges and
before creating the auth implementation branch, the worker creates/fetches the
remote monorepo branch `plan/bridge-app-onboarding/tracking` from the selected
`main` tip. It commits only the S01/W01 pinned auth baseline there, then updates
that same branch with the auth implementation branch/PR URL and optimistic
checked row after the auth PR opens. This administrative state branch adds no
implementation PR and never mixes auth-server product files into the monorepo.

After S01-W01-P01 merges, the W02 worker fetches the tracking branch, verifies
its W01 state against the merged auth PR, records the assessed S01/W02 monorepo
baseline there before branch creation, creates the W02 implementation branch
from that exact assessed `main` tip, and copies only this plan's `TRACKER.md`
from the tracking branch into the implementation branch. The W02 PR therefore
carries both waves' tracker state back to `main`; after it merges, `main` is
authoritative and the tracking branch is cleanup-only. No standalone tracker PR
or third product PR is created.

Rollback is stateless: the bridge PR can be reverted without server cleanup,
and the auth PR can be reverted while new bridges fail open. No persisted skip,
waiter, or schema state survives a process.

### Automated verification

- Auth repository tests prove existence queries across all five platforms and
  invalid/empty users without loading or exposing token values.
- Auth service tests prove immediate truth, timeout false, all-same-user wake,
  cross-user isolation, post-upsert ordering, failed-upsert non-wake,
  register/recheck race closure, abort cleanup, and no timer/waiter leaks.
- Auth route tests prove authentication, query validation, immediate and
  long-poll responses, disconnect handling, and unchanged token/activation
  behavior.
- Consolidated auth API tests prove every migrated existing operation plus
  configurable URL construction, bearer header, strict typed app-status parsing,
  30s/35s relationship, active app-status/refresh abort on skip/timeout, and
  status exceptions. Every settled request detaches its cancellation listener;
  repeated long polls and successful `never` refreshes retain none.
- Bridge repository tests prove unauthorized/status classification,
  permanent/old-server normalization, malformed response handling, caller-token
  forwarding, and no token-refresh/logging ownership.
- Bridge service tests use `fake_async`, fake repositories/token refreshers, and
  captured output to prove exactly one 401 refresh, silent current registration,
  prompt ordering, exact URL equality, success, both skip
  aliases, invalid input, EOF, normal-timeout no-delay/no-warning behavior,
  fixed 60-second transient delay, indefinite retry, permanent fail-open, and
  cancellation during guided request/delay, plus preservation of lines typed
  during the initial silent check.
- Plan execution verifies the remote tracking branch records W01 before the
  cross-repository barrier and that W02 imports only this plan's tracker file;
  no product commit spans repositories.
- Terminal tests prove one lazy async stdin subscription, FIFO type-ahead across
  gaps between sequential prompts, cancellation handoff without dropping queued
  lines, EOF, pre-echo password-line discard/re-entry, password echo restoration,
  and unchanged yes/no/provider/credential/logout behavior.
- Formatter tests prove a light quiet zone, module orientation, explicit black/
  white ANSI reset, width boundaries, required URL-only fallback without ANSI or
  Unicode and for unknown polarity/width, URL permanence, and deterministic
  output for the exact URL.
- Runner tests prove startup mode gating, checkpoint location before plugin
  startup, no held startup mutex, typed terminal-repository mapping,
  early/shared `TokenService` reuse, existing session-Orchestrator creation only
  after plugin start, and continuation for success/skip/fail-open. Session tests
  prove the existing `Orchestrator` remains the post-start owner and
  `BridgeRuntime.create` gains no onboarding/startup policy.
- Shared-model tests prove `EmailLoginRequest` and `RefreshTokenRequest` emit the
  exact legacy JSON keys and values; consolidated API fixtures prove byte-
  compatible request bodies without inline JSON maps.
- Token tests prove typed access classification, required non-null cancellation
  at every caller, both production implementors, post-refresh corruption repair
  without cleared-file resurrection, and no surviving refresh/control request
  after abort.

### Manual verification

S01-W02-M01 scans real terminal output and checks dark/light, width, skip,
same-account wake, and silent-restart behavior. It is advisory and records
separate User/Worker evidence.

### Observability

- Normal `registered: false` long-poll expiry is not an error and never logs.
- A recovered transient attempt emits one concise warning identifying network,
  timeout, or HTTP class and the exact 60-second retry; the service is the only
  reporting owner.
- Permanent/compatibility failure emits one warning that startup will continue.
- Essential skip instructions are user-facing output, never hidden solely
  behind log-level filtering.
- No tokens, auth headers, local paths, device-token values, or raw response
  bodies appear in output/evidence.
- No new telemetry sink, counter, or analytics event is added.

### Security

- The endpoint requires the existing user bearer token and derives user id only
  from auth middleware.
- Responses reveal one boolean about the caller's own account and never return
  token/platform/device details.
- Raw bearer tokens remain only in HTTP headers and existing token storage; QR
  and URL contain no identity or secret.
- A password line is accepted only after terminal echo is disabled. Lines queued
  earlier are discarded and re-requested rather than consumed as credentials.
- Waiters are keyed by authenticated user id in process memory, removed on every
  completion path, and never persisted.
- Local E2E, managed trust, relay encryption, plugin boundaries, multi-bridge
  addressing, and session-control surfaces remain unchanged.

## 9. Risks and Deferrals

| Risk | Decision / mitigation |
|---|---|
| A stale FCM token makes a user look registered | Explicitly accepted: the locked source of truth is the current token row, not a heartbeat. Existing stale-token cleanup remains unchanged. |
| Token registers between initial absence and long-poll waiter setup | Service registers the waiter then rechecks Mongo; post-commit signaling wakes all same-user waiters. |
| Auth server runs multiple instances | Current deployment is documented single-instance. Distributed signaling is deferred until horizontal scaling is a real requirement. |
| Client disconnect leaks a 30-second waiter | Shared request-close signal plus service timeout/abort cleanup; route and service tests inspect leak-free state. |
| Network is unavailable indefinitely | Interactive startup retries every fixed 60 seconds as explicitly chosen; visible `s`/`skip` remains cancellable during request and delay. |
| Warning spam during outage | One reporting owner and one warning per failed request, with no request for the following 60 seconds. |
| Older/custom auth server lacks endpoint | Exact compatibility fallback for 404/405 warns once and fails open; auth deploys first. |
| User signs in to a different account | Instructions say same account; only the authenticated bridge user's durable token wakes the waiter. |
| Async stdin migration changes existing prompts | One terminal owner with a FIFO pending-line buffer, serialized/type-ahead prompt tests, pre-echo secret-line discard/re-entry, echo restoration, and runner/logout regressions; no raw-mode single-key handling. |
| Token file corrupts while refresh is in flight | Preserve the current post-response `FormatException` repair using only the valid pre-refresh provider plus new response tokens; missing/cleared state still blocks resurrection. |
| App registration and skip complete together | One service completion gate cancels remaining request/subscription/delay and emits only one continuation/result message. |
| QR scans poorly under a terminal theme/font | Render only with explicit black/white ANSI plus validated Unicode, a four-module light quiet zone, and known sufficient width; otherwise omit QR, retain the URL, and use advisory real scans. |
| QR dependency or generation broadens lock output | Add only pure-Dart `qr`, run normal workspace resolution/codegen, and reject unrelated lock/generated changes. |
| Holding startup mutex while user waits | Checkpoint runs before `startPluginUnderStartupMutex`; no mutex or runtime process exists during the wait. |
| Plugin is unavailable | Preserve the quick availability probe before onboarding so users are not asked to install the app for a bridge that cannot start. |
| Auth HTTP consolidation regresses existing flows | Migrate real methods into one `SesoriAuthApi`, delete wrappers only after callers move, and preserve email/OAuth/profile/refresh/bridge request fixtures plus user-visible mapping tests. |
| Skip occurs during token refresh | Required `AuthRequestCancellationSignal` reaches both production token authorities and abortable auth transport; cancellable near-expiry refresh is awaited, and completion waits for settlement. |
| Startup ownership conflicts with desktop/parallel-plugin plans | User-approved narrow B-B5 waiver preserves `BridgeRuntimeRunner` as process-startup composer and existing `Orchestrator` as post-start session composer; `BridgeRuntime.create` gains no new policy and no third composer is introduced. |

Deferred work includes live app liveness, distributed waiter signaling, richer
deep links, browser opening, terminal QR files, persistent onboarding choices,
and any analytics.

## 10. Stage Map

| Stage | Outcome | Waves |
|---|---|---|
| S01 — App registration checkpoint | Auth server publishes race-safe current-registration long polling, then the standalone bridge consumes it with cancellable terminal onboarding and bounded QR output. | W01: S01-W01-P01; W02: S01-W02-P01 plus advisory S01-W02-M01 |

Waves are strict merge barriers and no PR is stacked. The auth-server PR must
merge before bridge implementation starts. The manual checkpoint is advisory,
does not block merge or plan closure, and has separate User/Worker state.

## 11. App-Registration State Machines

### Server waiter states

```text
created
  -> immediate registered true
  -> initial read deadline: 500 transient failure, never false
  -> confirmed absent: waiting
       -> registered true after durable upsert
       -> false after 30s timeout
       -> cancelled after client disconnect
       -> failed if repository recheck throws
```

Every terminal edge removes the timeout, abort listener, waiter set entry, and
empty user map entry before resolving. A registration snapshots the user's
waiter set before resolving it so mutation during iteration cannot skip peers.

### Bridge failure classification

| Outcome | Handling |
|---|---|
| 200 `registered: true` | Success; silent on initial check, confirmation after prompt. |
| 200 `registered: false`, immediate | Render onboarding once, then long poll. |
| 200 `registered: false`, long poll | Normal expiry; no warning/delay, immediately long poll again. |
| 500 before server initial presence read completes | Unconfirmed/transient; no onboarding prompt, warn once, fixed cancellable 60-second delay, retry. |
| Skip-triggered `RequestAbortedException` | Expected cancellation; no warning, continue current run. |
| Repository returns unauthorized first occurrence | Service forces refresh once and retries immediately. |
| Repository returns unauthorized after refresh | Service warns once and fails open. |
| 400/403/404/405/other non-retryable 4xx | Warn once and fail open; 404/405 branch carries compatibility marker. |
| 408/429/5xx | Warn once, fixed cancellable 60-second delay, retry. |
| Socket/client/network error | Warn once, fixed cancellable 60-second delay, retry. |
| Client's active 35-second timeout | Abort socket, warn once, fixed cancellable 60-second delay, retry. |
| Token refresh socket/408/429/5xx/15-second deadline | Typed transient; abort transport, warn once, fixed cancellable 60-second delay, retry. |
| Token refresh local-token/4xx/malformed failure | Typed unavailable; warn once and fail open. |
| Skip during token refresh | Typed cancellation; actively abort and await settlement, no failure warning. |
| Malformed/missing required response field | Permanent protocol failure; warn once and fail open. |
| Terminal EOF/loss while prompted | Warn once, abort request, fail open. |

The retry delay begins after handling the failure and is always exactly 60
seconds unless registration/skip/cancellation ends the one-shot service. A
server-supplied retry hint does not create a second backoff policy in this scope.

### QR rendering order

1. Encode exactly `https://sesori.com/app/?openStore=true` with the audited
   pure-Dart QR package and a fixed error-correction choice suitable for terminal
   scanning.
2. Add four light modules on every side.
3. Require validated ANSI and Unicode support, then use compact half-block output
   with explicit black/white foreground/background and a final reset. This is
   the only QR renderer because non-ANSI Unicode/ASCII cannot prove light/dark
   polarity across terminal themes.
4. Compute complete rendered width before output. If terminal width is unknown,
   throws, or is smaller than the selected representation, omit the QR.
5. If ANSI or Unicode is unavailable, polarity is not provable, or rendering
   fails, omit the QR rather than emitting an inverted/unsafe fallback.
6. Print the exact plain URL on its own line in every prompted case, regardless
   of QR success.
