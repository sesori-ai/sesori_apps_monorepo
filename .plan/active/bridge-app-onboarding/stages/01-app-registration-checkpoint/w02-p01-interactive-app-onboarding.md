# S01-W02-P01: Add Interactive Bridge App Onboarding

## 0. Metadata

- **ID:** S01-W02-P01
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Worktree:** one dedicated monorepo worker worktree for this PR
- **Base branch:** `main`
- **Branch:** `plan/bridge-app-onboarding/s01-w02-p01-interactive-app-onboarding`
- **Wave baseline:** pin the assessed current `main` tip on remote `plan/bridge-app-onboarding/tracking`, then import this plan's `TRACKER.md` after branch creation
- **Audited reference:** `5a76c0c420cd7db445f7fe2c8a2570265b4c84e0`
- **Audited reference date:** 2026-07-17T06:57:01Z
- **Touched workspaces:** `bridge/app`, `shared/sesori_shared`
- **Contract-affecting:** Yes — auth HTTP consumption/request DTOs, CLI prompt behavior, and shipped old-server compatibility

## 1. Goal and Cohesion

Add the complete standalone interactive bridge checkpoint over the merged auth
contract: safe asynchronous terminal ownership, initial current-registration
check, bounded QR/URL guidance, instant server wake, explicit current-run skip,
fixed one-minute transient retry, and permanent fail-open compatibility.

The PR is independently cohesive because the shared auth request DTO sources,
bridge API/repository/service/terminal/composition changes, generated output,
tests, and dependency work land together. No intermediate build can start an
uncancellable prompt or consume a contract without typed fallback behavior.

The existing auth HTTP consolidation is required, not opportunistic cleanup:
the scoped architecture permits one API owner per external provider, so adding
app status cannot create another use-case API. Moving the existing operations
and cancellable refresh into `SesoriAuthApi` in this same PR is the smallest
release-safe boundary; splitting it would either leave duplicate provider APIs
or make onboarding depend on an unmerged internal stack.

## 2. Dependencies and Baseline

- S01-W01-P01 is merged to auth-server `master`; its exact endpoint contract is
  re-read rather than inferred from this plan.
- Fetch remote `plan/bridge-app-onboarding/tracking`, verify its S01/W01 baseline/
  branch/PR/checked state against the merged auth PR, and stop on mismatch.
- Auth deployment is available before bridge release. Local tests may use a fake
  server and do not require production credentials.
- Fetch monorepo `main`, assess drift from
  `5a76c0c420cd7db445f7fe2c8a2570265b4c84e0` in every expected auth/runtime/
  terminal/shared-model/pubspec/test path, and pin the exact tip before branching.
- Record that assessed S01/W02 tip on the tracking branch before creating the
  implementation branch from the same `main` commit. Copy only
  `.plan/active/bridge-app-onboarding/TRACKER.md` from tracking into the new
  implementation branch; do not merge the tracking branch or add another PR.
- Re-read existing root `AGENTS.md`, `bridge/AGENTS.md`,
  `bridge/app/AGENTS.md`, and `shared/sesori_shared/AGENTS.md`, plus
  `docs/VISION.md`, `docs/ROADMAP.md`, and current active plans. No scoped
  plugin-interface instruction file exists or is needed because this PR does not
  modify that package.
- Re-read `bridge/app/pubspec.yaml` and `lib/src/version.dart` immediately before
  writing the compatibility marker; audited version is `1.5.1`.
- Same-wave sibling baseline reuse is not applicable; this wave has one PR. The
  manual checkpoint consumes the merged/deployed result rather than a branch.

## 3. Scope

### In Scope

- Add pure-Dart `qr` as a direct `bridge/app` dependency and update workspace
  resolution/lockfile through normal tooling.
- Add bridge-local Freezed `AppClientPresenceResponse` and generated JSON code.
- Add shared Freezed `EmailLoginRequest` and `RefreshTokenRequest` sources,
  exports, generated JSON code, and exact legacy-body tests.
- Add one per-provider `SesoriAuthApi`, `AuthRepository`,
  `LoginOAuthRepository`, `AppClientPresenceRepository`, typed outcomes/
  exceptions, `AppOnboardingFormatter`, and `AppClientOnboardingService`.
- Move existing email login, OAuth init/status/ACK, profile `/auth/me`, token
  validation/refresh, and bridge register/delete HTTP operations into
  `SesoriAuthApi`; delete `LoginEmailApi`, `LoginOAuthApi`,
  `BridgeRegistrationApi`, and top-level `profile.dart` / `validate.dart` HTTP
  functions rather than retaining forwarding wrappers.
- Rewire `LoginEmailRepository`, `LoginOAuthService` through new
  `LoginOAuthRepository`, `BridgeRegistrationRepository`,
  `BridgeRuntimeAuthService`, and renamed `TokenService` to the one API owner while
  preserving their domain behavior.
- Use the configured auth backend and bearer token; support immediate and
  `wait=true` requests.
- Actively abort in-flight HTTP on skip and on the 35-second client deadline.
- Make both named `forceRefresh` and auth-local
  `AuthRequestCancellationSignal` required on `TokenRefresher.getAccessToken`;
  update `TokenService`, `ControlChannelTokenService`, every production caller,
  and every test fake.
- Route standalone refresh through `AuthRepository` and an abortable
  `SesoriAuthApi.refreshTokens` request with a 15-second active deadline. Define
  typed transient/unavailable/cancelled token-refresh failure kinds without
  parsing exception text.
- Have `AppClientOnboardingService` refresh once on the first repository
  unauthorized outcome; classify the second unauthorized/permanent
  4xx/protocol outcomes as unavailable and network/timeout/408/429/5xx as
  transient.
- Add exact old-server compatibility marker and omission tests.
- Convert `TerminalPromptApi` to one lazy process-lifetime asynchronous line
  owner with deterministic disposal, raw terminal/environment facts, capability
  reads, EOF, and password echo restoration. It contains no product decision.
- Add typed `TerminalInteractionMode` and `TerminalRenderingCapabilities`.
  `TerminalPromptRepository` alone maps raw API facts plus the legacy relaunch
  marker to those models; startup/logout consumers never interpret raw facts.
- Convert provider, credentials, replace/startup contention, and logout prompts
  to the same async owner without visible contract changes.
- Remove direct global stdin use from `BridgeRuntimeAuthService`; move email
  credential prompting into the service/terminal repository boundary so
  `LoginEmailRepository` remains focused on auth API mapping.
- Move `BridgeRuntimeAuthService` from `bridge/runtime/` to root `lib/src/services/`
  and remove its `BridgeCliOptions` dependency. Configured auth URL/client state
  is already owned by injected `SesoriAuthApi`/repositories.
- Add typed cancellable `s`/`skip` onboarding decisions to
  `TerminalPromptRepository`.
- Rename substantially changed `TokenManager`/`token_manager.dart` to
  `TokenService`/`token_service.dart`, compose one instance immediately after
  authentication, and
  reuse it for onboarding and later bridge registration/runtime.
- Run onboarding only when standalone + terminal interactive, after authenticated
  username logging and successful plugin availability, before startup mutex,
  provisioning, plugin start, relay, or bridge registration.
- Preserve the process-startup ownership locked by the active desktop and
  parallel-plugin plans: `BridgeRuntimeRunner` constructs the touched APIs,
  repositories, services, and terminal/token owners, runs onboarding at the
  declared pre-mutex point, then continues its existing provision/start/runtime
  handoff. The existing `Orchestrator` remains the post-start session composer.
- Keep `BridgeRuntime.create` as the existing session-phase handoff and add no
  onboarding/auth/terminal/startup policy to it. Do not add
  `BridgeStartupOrchestrator` or any third composition owner.
- Add Layer-2 `TokenRepository` and `BridgeIdRepository`; only those repositories
  consume `TokenStorage` and `BridgeIdStorage`. Remove persistence callback
  plumbing and direct service/storage dependencies.
- Add shared Freezed `EmailLoginRequest` and `RefreshTokenRequest` DTOs, barrel
  exports, generated files, and exact-body tests; consolidated auth operations
  must serialize these models instead of reproducing inline JSON maps.
- Add focused API/repository/service/formatter/terminal/auth/runner tests and
  compile the host native bridge.

### Non-Goals

- Changing plugins, relay, mobile, desktop, auth server, app UI, or shared relay/
  session contracts. The two additive shared auth request DTOs are in scope.
- Migrating `PushNotificationClient`: it is an existing transport `Client`, not
  another `Api` class, and its notification-send ownership remains unchanged.
- Running onboarding in `--control-url` supervised mode or any noninteractive
  path.
- A new CLI option, config field, persisted skip, browser launch, store API, or
  platform-specific deep link.
- Raw one-key input, terminal raw mode, clearing partially typed terminal input,
  shelling out to detect width/color, or adding a terminal-size dependency.
- Retrying normal long-poll expiry with a timer.
- Adding an auth SSE/WebSocket channel or importing/refactoring plugin SSE code.
- Exponential/jittered backoff, automatic transient fail-open, or separate
  `Retry-After` scheduling.
- Logging in API/repository layers or double-reporting failures.
- A live app heartbeat or validation of FCM token freshness.
- Drift schema/migration work or generated-file hand edits.
- Analytics or release observation work.

## 4. Audited Current Code and Assumptions

- `bridge_runtime_runner.dart:238-268` owns terminal/auth composition;
  `:442-501` owns auth, profile output, and plugin availability.
- `bridge_runtime_runner.dart:503-559` enters plugin start/provisioning, so the
  checkpoint must run before that boundary and never inside the mutex callback.
- `bridge_runtime_runner.dart:568-605` composes legacy `TokenManager` late; this
  PR renames it to `TokenService` because its responsibility is a Layer-3 token
  lifecycle, moves the single instance earlier, and preserves later consumers/
  disposal.
- `terminal_prompt_api.dart:18-47` uses sync input and password echo toggling.
- `terminal_prompt_repository.dart:10-67` maps yes/no and credentials.
- `bridge_runtime_auth.dart:38-71` has direct provider stdin and
  `:74-169` owns login/persistence.
- `login_email_repository.dart:7-18` currently receives a synchronous prompt
  callback and then performs the auth request.
- `bridge_logout_runner.dart:57-79` already awaits terminal decisions and can
  consume the async repository without changing its public result.
- `login_oauth_service.dart:208-253` establishes 35 seconds as the bridge-side
  cap around a 30-second auth-server long poll.
- `bridge_registration_service.dart:152-162` retries one 401 after force refresh.
- Legacy `TokenManager` serializes active refreshes and publishes refreshed access
  tokens. `AppClientOnboardingService` must use it for coordination; the
  repository must not acquire/refresh tokens or invent refresh storage.
- `token_refresher.dart:1-3` currently exposes no cancellation signal;
  `token_manager.dart:98-110` performs refresh HTTP inline and collapses every
  non-200 into legacy untyped `TokenRefreshException`. A skip cannot abort that request
  at the audited baseline.
- `ControlChannelTokenService` is the second production `TokenRefresher`; it
  already owns correlated pending requests but has no caller-cancellation input.
- `LoginEmailApi`, `LoginOAuthApi`, and `BridgeRegistrationApi`, plus top-level
  `profile.dart` / `validate.dart` and inline legacy token-manager refresh HTTP, split
  one external Sesori auth provider by use case. The new endpoint cannot add a
  fourth use-case API; this PR consolidates the touched provider boundary.
- `login_email_api.dart` and both refresh implementations currently serialize
  inline `{email, password}` / `{refreshToken}` maps. Moving those methods must
  adopt shared Freezed request models required by `bridge/app/AGENTS.md`; exact
  legacy key/value output remains the compatibility fixture.
- `TerminalGlyphValidator` and `TerminalColorValidator` are existing Layer-0
  policy; `Stdout.terminalColumns` may throw and must be treated as unknown.
- `http ^1.6.0` supports active request abort. A plain `Future.timeout` that
  leaves a request alive is insufficient.
- No `qr` dependency or terminal QR implementation exists at the audited tip.
- The exact app URL is a product constant, not the configurable auth/relay URL.

## 5. Design and Ownership

### Expected source/dependency files

- `shared/sesori_shared/lib/src/models/auth/email_login_request.dart` and
  generated `*.freezed.dart` / `*.g.dart` (new)
- `shared/sesori_shared/lib/src/models/auth/refresh_token_request.dart` and
  generated `*.freezed.dart` / `*.g.dart` (new)
- `shared/sesori_shared/lib/sesori_shared.dart` barrel exports and focused model
  tests; `shared/sesori_shared/pubspec.lock` only if normal resolution changes it
- `bridge/app/pubspec.yaml`
- `bridge/pubspec.lock`
- `bridge/app/lib/src/auth/app_client_presence_response.dart` (new)
- generated response `*.freezed.dart` / `*.g.dart`
- `bridge/app/lib/src/auth/sesori_auth_api.dart` (new sole provider API)
- `bridge/app/lib/src/auth/auth_repository.dart` (new)
- `bridge/app/lib/src/auth/login_oauth_repository.dart` (new)
- `bridge/app/lib/src/auth/app_client_presence_repository.dart` (new)
- `bridge/app/lib/src/services/app_client_onboarding_service.dart` (new)
- `bridge/app/lib/src/foundation/app_onboarding_formatter.dart` (new)
- `bridge/app/lib/src/auth/login_email_repository.dart`
- `bridge/app/lib/src/auth/login_oauth_service.dart`
- `bridge/app/lib/src/auth/bridge_registration_repository.dart`
- `bridge/app/lib/src/auth/bridge_registration_service.dart`
- `bridge/app/lib/src/auth/token_storage.dart` (new Layer-1 token-file API)
- `bridge/app/lib/src/auth/token_repository.dart` (new Layer-2 mapping boundary)
- existing `bridge_id_storage.dart` remains Layer 1; add
  `bridge_id_repository.dart` as its only Layer-2 consumer
- `bridge/app/lib/src/auth/token.dart` retains `TokenData`/path values; raw file
  I/O moves to `TokenStorage`, while current/legacy JSON mapping moves to
  `TokenRepository`
- `bridge/app/lib/src/auth/token_refresher.dart`
- rename `bridge/app/lib/src/auth/token_manager.dart` to `token_service.dart` and
  `TokenManager` to `TokenService`
- rename `bridge/app/test/auth/token_manager_test.dart` to
  `token_service_test.dart`; update every source/test reference and diagnostic
  label so the forbidden `TokenManager` name does not survive
- replace `bridge/app/lib/src/auth/token_refresh_exception.dart` with
  `token_access_exception.dart` and typed `TokenAccessFailureKind`
- remove `ControlTokenUnavailableException` from `token_refresher.dart`; both
  production authorities use `TokenAccessException` kinds
- delete superseded `login_email_api.dart`, `login_oauth_api.dart`,
  `bridge_registration_api.dart`, `profile.dart`, and `validate.dart` after
  migrating their real behavior/tests; do not leave forwarding wrappers
- `bridge/app/lib/src/auth/auth_request_cancellation.dart` (new auth-local
  read/write cancellation primitive; do not reuse plugin-specific
  `StartAbortSignal` or import root core Foundation into `auth/`)
- `bridge/app/lib/src/services/control_channel_token_service.dart`
- production token call sites in `push_notification_client.dart`,
  `bridge_registration_service.dart`, `metadata_service.dart`,
  `orchestrator.dart`, and runtime composition pass
  `AuthRequestCancellationSignal.never` when no caller cancellation exists
- move `bridge/app/lib/src/server/api/terminal_prompt_api.dart` to
  `bridge/app/lib/src/api/terminal_prompt_api.dart`
- move `bridge/app/lib/src/server/repositories/terminal_prompt_repository.dart`
  to `bridge/app/lib/src/repositories/terminal_prompt_repository.dart`
- `bridge/app/lib/src/foundation/terminal_interaction_mode.dart` and
  `terminal_rendering_capabilities.dart` (new typed repository outputs)
- move existing terminal-only `server/foundation/terminal_prompt_decision.dart`
  and `bridge_replace_prompt.dart` to root `lib/src/foundation/`; place the small
  typed onboarding outcome there as well, so the root repository has no outbound
  dependency on the minimal `server/` subsystem
- move `bridge/app/lib/src/bridge/runtime/bridge_runtime_auth.dart` to
  `bridge/app/lib/src/services/bridge_runtime_auth_service.dart`
- `bridge/app/lib/src/bridge/runtime/bridge_runtime_runner.dart` retains
  `runBridgeApp`, process-startup composition, shutdown, supervised-mode, and
  plugin lifecycle ownership while replacing touched inline/callback seams and
  inserting onboarding before the startup mutex
- `bridge/app/lib/src/bridge/runtime/bridge_runtime.dart` and existing
  `bridge/orchestrator.dart` only for dependency propagation required by the new
  repositories/contracts; they gain no new composition responsibility
- `bridge/app/bin/bridge.dart` for logout repository composition and terminal API
  disposal; it constructs dependencies but performs no storage read/clear or raw
  terminal mapping
- `bridge/app/lib/src/bridge/runtime/bridge_logout_runner.dart` only if signature
  propagation requires it; preserve behavior

Expected tests mirror each owner under `bridge/app/test/auth/`,
root `test/api/`, `test/repositories/`, `test/foundation/`, `test/services/`, and
`test/bridge/runtime/`. Move existing terminal tests with their production files.
Prefer focused new test files over growing an unrelated runner fixture, while
reusing current helpers. Update every fake `TokenRefresher` found under
`bridge/app/test/` to the required cancellation signature; migrate existing
`profile_test.dart`, `validate_test.dart`, `bridge_registration_api_test.dart`,
and login/OAuth HTTP fixtures into `sesori_auth_api_test.dart` and owning
repository/service tests rather than deleting coverage. Move
`test/bridge/runtime/bridge_runtime_auth_test.dart` to
`test/services/bridge_runtime_auth_service_test.dart` with the production class;
assert its methods accept no `BridgeCliOptions` or auth URL pass-through.

### Dependency direction

```text
EmailLoginRequest / RefreshTokenRequest (shared Freezed DTOs)
  -> SesoriAuthApi request serialization

SesoriAuthApi
  <- AuthRepository / LoginEmailRepository / LoginOAuthRepository /
     BridgeRegistrationRepository / AppClientPresenceRepository
  <- TokenService / BridgeRuntimeAuthService / LoginOAuthService /
     BridgeRegistrationService / AppClientOnboardingService

AppClientPresenceRepository
     <- AppClientOnboardingService (+ TokenRefresher)

TerminalPromptApi
  <- TerminalPromptRepository
     <- BridgeRuntimeAuthService / AppClientOnboardingService / existing consumers
     -> typed TerminalInteractionMode / TerminalRenderingCapabilities

TokenStorage <- TokenRepository
  <- TokenService / BridgeRuntimeAuthService / BridgeIdMigrationService /
     BridgeLogoutRunner

BridgeIdStorage <- BridgeIdRepository
  <- BridgeRegistrationService / BridgeIdMigrationService / logout flow

logout composition:
  TokenRepository.read typed outcome
    -> available: command constructs TokenService -> BridgeRegistrationService
    -> other: nullable registration dependency remains absent
  TokenRepository + BridgeIdRepository -> BridgeIdMigrationService
  all already-built dependencies -> BridgeLogoutRunner

AppOnboardingFormatter
  <- AppClientOnboardingService

all startup APIs/repositories/services
  <- BridgeRuntimeRunner (user-approved process-startup composer)
     -> existing BridgeRuntime.create handoff after plugin start
     -> existing Orchestrator (post-start session composer)
```

- `SesoriAuthApi` is the single per-provider HTTP/JSON/abort boundary. No
  use-case API forwards to it.
- Repository accepts a caller-supplied access token and owns only
  transport-to-domain normalization.
- Service owns access-token acquisition, exactly-one forced refresh/retry,
  timer/retry/output/race policy.
- `BridgeRuntimeRunner` remains the process-startup composition root selected by
  the active desktop and parallel-plugin plans. It constructs declared peers and
  sequences phases; it does not inline HTTP, persistence, terminal mapping, QR,
  or domain logic.
- Existing terminal repository remains the sole prompt normalization boundary;
  no auth repository depends on it as a peer.
- `LoginEmailRepository.performEmailLogin` receives already-normalized required
  email/password from `BridgeRuntimeAuthService`; the repository no longer owns
  prompt acquisition.
- `LoginOAuthService` depends on `LoginOAuthRepository`, not the API.
- `TokenService` depends on `AuthRepository` plus `TokenRepository`, not
  callbacks, storage, or the API, and implements the cancellable token contract.
  `BridgeRuntimeAuthService` uses `AuthRepository` for current `/auth/me`/refresh
  mapping and `TokenRepository` for local token state.
- `BridgeIdMigrationService` depends on `TokenRepository` and
  `BridgeIdRepository`; registration/logout services use repositories as well.
  Only repositories access the two storage APIs, and load/save/clear/legacy-read
  callbacks are removed.

### Exact constructors and lifecycle owners

```dart
EmailLoginRequest({required String email, required String password})
RefreshTokenRequest({required String refreshToken})

SesoriAuthApi({
  required String authBackendUrl,
  required http.Client client,
})

AuthRepository({
  required SesoriAuthApi api,
  required Duration refreshRequestTimeout,
})

LoginOAuthRepository({
  required SesoriAuthApi api,
  required AuthClientType clientType,
  required DeviceInfo device,
})

AppClientPresenceRepository({
  required SesoriAuthApi api,
  required Duration statusRequestTimeout,
})

TokenStorage({required String tokenFilePath})
TokenStorage.readRaw()
TokenStorage.writeRaw({required String json})
TokenStorage.clear()
TokenRepository({required TokenStorage storage})
BridgeIdStorage({required String bridgeIdFilePath})
BridgeIdRepository({required BridgeIdStorage storage})

sealed class TokenReadOutcome
TokenReadAvailable({required TokenData tokens})
TokenReadMissing()
TokenReadCorrupt({required Object cause, required StackTrace stackTrace})
TokenReadFailure({required Object cause, required StackTrace stackTrace})

TokenRepository.read()
TokenRepository.write({required TokenData tokens})
TokenRepository.clear()
TokenRepository.readLegacyBridgeId()

BridgeIdRepository.read()
BridgeIdRepository.write({required String bridgeId})
BridgeIdRepository.clear()

TokenService({
  required String initialToken,
  required AuthRepository authRepository,
  required TokenRepository tokenRepository,
})

BridgeRuntimeAuthService({
  required LoginEmailRepository loginEmailRepository,
  required LoginOAuthService loginOAuthService,
  required AuthRepository authRepository,
  required TokenRepository tokenRepository,
  required TerminalPromptRepository terminalPromptRepository,
})

BridgeRuntimeAuthService.ensureAuthenticated()
BridgeRuntimeAuthService.logAuthenticatedUser({required String accessToken})

BridgeIdMigrationService({
  required BridgeIdRepository bridgeIdRepository,
  required TokenRepository tokenRepository,
})

BridgeLogoutRunner({
  required BridgeInstanceRepository bridgeInstanceRepository,
  required BridgeInstanceService bridgeInstanceService,
  required TerminalPromptRepository terminalPromptRepository,
  required BridgeIdMigrationService bridgeIdMigrationService,
  required TokenRepository tokenRepository,
  required BridgeRegistrationService? bridgeRegistrationService,
})

AppClientOnboardingService({
  required AppClientPresenceRepository repository,
  required TokenRefresher tokenRefresher,
  required TerminalPromptRepository terminalPromptRepository,
  required AppOnboardingFormatter formatter,
  required Duration retryDelay,
})

TokenRefresher.getAccessToken({
  required bool forceRefresh,
  required AuthRequestCancellationSignal cancelled,
})

AuthRepository.refreshTokens({
  required String refreshToken,
  required AuthRequestCancellationSignal cancelled,
})

AppClientPresenceRepository.check({
  required String accessToken,
  required bool wait,
  required AuthRequestCancellationSignal cancelled,
})

SesoriAuthApi.refreshTokens({
  required String refreshToken,
  required Duration requestTimeout,
  required AuthRequestCancellationSignal cancelled,
})

SesoriAuthApi.getAppClientStatus({
  required String accessToken,
  required bool wait,
  required Duration requestTimeout,
  required AuthRequestCancellationSignal cancelled,
})

AppOnboardingFormatter({
  required TerminalRenderingCapabilities capabilities,
})

TerminalPromptApi({
  required Stdin stdin,
  required Stdout stdout,
  required Map<String, String> environment,
})

TerminalPromptRepository({required TerminalPromptApi api})
TerminalPromptRepository.interactionMode
TerminalPromptRepository.renderingCapabilities
```

`TokenRepository.read()` returns the sealed outcomes above rather than leaking
`PathNotFoundException`, `FormatException`, or raw file exceptions. Write/clear
and bridge-id repository operations throw typed repository exceptions with safe
cause/stack when raw persistence fails. Services retain business policy:
runtime auth chooses login/failure, token refresh prevents resurrection or
performs the approved corrupt-post-read repair, registration handles revocation,
and logout maps clear failure into its existing result.

Production composition passes 35 seconds and 60 seconds explicitly. The API
stores the runner's shared `http.Client` and never closes it; the runner's
shutdown coordinator remains its owner. `TerminalPromptApi` owns and
disposes its lazy stdin subscription. `AppClientOnboardingService` owns one
`AuthRequestCancellationController`, the onboarding input subscription, and one internal
cancellable `Timer` for each retry wait. It cancels that timer on
skip/success/fail-open/EOF; tests use existing `fake_async` rather than injecting
a delay callback or constructing a timer collaborator.

`AuthRepository` receives an explicit 15-second refresh request timeout and
passes the caller's `AuthRequestCancellationSignal` to `SesoriAuthApi.refreshTokens`.
`AppClientPresenceRepository` receives the 35-second status timeout and passes
the same signal to the API. `forceRefresh: false` and
`AuthRequestCancellationSignal.never` are the explicit values for existing
ordinary uncancellable callers; onboarding owns an
`AuthRequestCancellationController` and
passes its signal through token acquisition and app status. No nullable/default
cancellation or message parsing is allowed.

`AuthRequestCancellationSignal` is an auth-local read side with
`AuthRequestCancellationSignal.never`, synchronous
`canCancel`/`isCancelled`, and a broadcast `Stream<void> get cancellations`;
`AuthRequestCancellationController` is the idempotent write side owned by
onboarding. Keeping it in `auth/` preserves that subsystem's autonomy; the plan
does not reuse/modify plugin `StartAbortSignal` or import root core Foundation
into auth. Each API/token operation subscribes to `cancellations`, rechecks
`isCancelled` after subscription to close the subscribe race, and cancels that
request-scoped subscription in `finally` when the request/response settles.
`never` emits nothing but its per-request subscription is still detached.

Failure vocabulary is also explicit:

```dart
enum TokenAccessFailureKind { transient, unavailable, cancelled }

TokenAccessException({
  required TokenAccessFailureKind kind,
  required String reason,
  required Object? cause,
  required StackTrace? stackTrace,
})

SesoriAuthApiException({
  required SesoriAuthOperation operation,
  required int? statusCode,
  required Object? cause,
  required StackTrace? stackTrace,
  required String? responseBody,
})
```

`SesoriAuthOperation` is an enum, not a magic operation string. Only existing
email/bridge repository mappings may inspect `responseBody`; app-presence and
refresh output never log/retain it beyond exception lifetime.

Immediately before composing onboarding, `BridgeRuntimeRunner` asks
`TerminalPromptRepository` for typed `interactionMode` and
`renderingCapabilities`. The repository maps raw API facts with existing
`TerminalColorValidator`, `TerminalGlyphValidator`, the legacy environment
marker, and safe nullable width handling. `AppOnboardingFormatter` receives only
the immutable typed capability model and owns no stream, environment, stdout
handle, or lifecycle.

### Layer-5 startup ownership

- `runBridgeApp` and `BridgeRuntimeRunner.run` stay in
  `bridge_runtime_runner.dart`. This preserves the active parallel-plugin plan's
  process lifecycle sequence and the desktop plan's one-time standalone/
  supervised selection plus exit/shutdown semantics.
- The user explicitly waives strict B-B5 only for this established two-phase
  composition: `BridgeRuntimeRunner` wires process-startup layers and the
  existing `Orchestrator` wires the post-start room/session/event graph.
  `BridgeRuntime.create` remains the existing handoff within the session phase;
  it gains no onboarding, auth, terminal, or process-startup policy. The waiver
  includes retaining the existing `BridgeRuntimeRunner` name for the startup
  role locked by those active plans, but authorizes no additional composer or
  suffix exception.
- The runner constructs each touched API/repository/service as peers, stores no
  raw persistence or terminal mapping policy, and inserts onboarding after auth
  plus availability but before startup mutex/provision/start. It retains shared
  client, shutdown coordinator, partial-start cleanup, and typed exit ownership.
- After onboarding settles, the runner continues the existing startup sequence
  and invokes the existing runtime/session handoff. No
  `BridgeStartupOrchestrator`, wrapper context, service locator, or third
  composition owner is added.

### Typed HTTP contract and classification

`SesoriAuthApi`:

- trims one trailing slash from the configured provider base and shares the
  injected `http.Client` across `loginWithEmail`, `initOAuthSession`,
  `getOAuthSessionStatus`, `ackOAuthSessionCompletion`,
  `getAuthenticatedUser`, `refreshTokens`, `registerBridge`, `deleteBridge`, and
  `getAppClientStatus`;
- preserves each migrated method's current URI/header/body/DTO/status behavior;
  repositories retain use-case/domain mapping;
- adds `?wait=true` only to long-poll app status and sends bearer tokens only in
  authorization headers;
- accepts a required `AuthRequestCancellationSignal` and required timeout for app status
  and refresh; uses `AbortableRequest` with one combined caller-cancel/deadline
  trigger;
- uses the repository-supplied 35 seconds for app status so the healthy
  30-second server expiry wins, and 15 seconds for refresh;
- checks an already-cancelled signal before send, actively aborts on later
  cancellation/deadline, distinguishes caller cancellation from deadline, and
  cancels deadline timers plus the request-scoped cancellation subscription in
  every success/error/abort path. Normal completion settles the combined abort
  trigger so healthy long-poll rounds and `never` refreshes retain no callbacks;
- accepts only 200 app status with strict Freezed `{registered: bool}` parsing;
- throws one typed `SesoriAuthApiException` carrying operation/status and safe
  cause/stack; raw bodies remain available only where existing email/
  registration mapping requires them and are never logged by app presence.

`AppClientPresenceRepository`:

- receives required `accessToken` on every call and forwards it to the API;
- returns typed `registered`, `absent`, `unauthorized`, or `unavailable`
  outcomes;
- maps 408/429/5xx, socket/client errors, and active client deadline to one typed
  transient failure carrying safe cause/stack for the service;
- preserves skip abort as typed expected cancellation;
- maps API 401 to `unauthorized` without acquiring/refreshing a token or deciding
  whether another attempt is allowed;
- maps nonretryable 4xx and malformed/protocol responses to unavailable;
- places the required compatibility marker immediately above 404/405 mapping.

`AuthRepository` and token refresh:

- maps `getAuthenticatedUser` into typed valid/unauthorized/non-auth-failure
  results used by `BridgeRuntimeAuthService`; that service retains the shipped
  validate-then-refresh/login coordination;
- maps `refreshTokens` to required `TokenData` without owning token persistence;
- classifies socket/client/active deadline/408/429/5xx as
  `TokenAccessFailureKind.transient`, caller cancellation as `cancelled`, and
  4xx rejection or malformed response as `unavailable`;
- throws `TokenAccessException` with the enum kind and attached safe cause/stack
  so `AppClientOnboardingService` never parses text;
- `TokenService` keeps the legacy class's token-state re-read/persist/publish and
  single-flight behavior through `TokenRepository`, while sending actual refresh
  transport through `AuthRepository` with the caller signal. For
  `canCancel == true`, a token in the
  existing background-refresh TTL band is refreshed synchronously instead of
  spawning detached work; `AuthRequestCancellationSignal.never` preserves current
  background behavior for existing callers;
- `TokenRepository` maps raw storage/JSON failures to sealed present, missing,
  corrupt, and persistence-failure outcomes. `TokenService`, as token-state
  owner, decides those initial or in-flight outcomes are unavailable. Preserve
  the shipped post-response recovery seam: if only the repository's post-refresh
  re-read outcome is corrupt, retain `lastProvider` from the valid pre-refresh
  snapshot and persist the newly issued access/refresh tokens through the
  repository to repair the file. Missing/cleared post-refresh state still
  prevents resurrection;
- onboarding's freshly constructed token service has no other consumers before the
  checkpoint. Its cancellable refresh therefore exclusively owns the active
  request; skip cancels it and service completion waits for the abort to settle
  before plugin/registration consumers are composed;
- `ControlChannelTokenService` installs a detachable cancellation subscription,
  rechecks pre-cancellation, races its correlated response, and removes the
  pending id/cancels the subscription in `finally`. Caller cancellation
  throws `TokenAccessFailureKind.cancelled`; control transport disconnection and
  request timeout throw `transient`; signed-out/null-token responses and calls
  after disposal throw `unavailable`. Late GUI replies remain ignored.
  `ControlTokenUnavailableException` is removed, and supervised bootstrap maps
  both typed transient/unavailable failures to its existing `authRequired` exit
  behavior. Supervised onboarding remains gated out.

`TokenStorage` / repository ownership:

- `TokenStorage` absorbs only raw file/process behavior from `token.dart` behind
  required `readRaw`, `writeRaw`, and `clear` methods; it preserves token path,
  Unix directory/file permissions, and Windows behavior without parsing JSON;
- `TokenRepository` owns current `TokenData` JSON/provider mapping,
  missing/corrupt outcomes, serialization, and the legacy bridge-id read plus its
  compatibility marker/cleanup;
- is consumed only by one `TokenRepository` instance per command/run. That
  repository maps missing/corrupt/persisted state into typed domain results and
  is injected into `BridgeRuntimeAuthService`, `TokenService`,
  `BridgeIdMigrationService`, and `BridgeLogoutRunner`;
- existing `BridgeIdStorage` is likewise consumed only by
  `BridgeIdRepository`, which is injected into bridge registration, migration,
  and logout collaborators;
- removes `loadTokens`/`saveTokens`/`clearTokens`/legacy-reader callbacks from
  touched constructors and tests. Tests fake/implement the concrete Dart class
  repository directly rather than introducing a one-to-one interface.
- `LogoutCommand` constructs `TokenStorage -> TokenRepository` and
  `BridgeIdStorage -> BridgeIdRepository`, then performs one typed
  `TokenRepository.read()` solely to select the constructible dependency graph:
  `TokenReadAvailable` supplies `TokenService.initialToken` and permits a
  command-owned `BridgeRegistrationService`; missing/corrupt/failure leaves that
  injected dependency null because no safe token authority exists. Missing is
  silent; corrupt/failure emits the existing one best-effort unregister warning
  without exposing token contents. The command does not read storage APIs,
  interpret JSON, migrate ids, unregister, or clear tokens itself.
- `LogoutCommand` always constructs `BridgeIdMigrationService` from
  `TokenRepository` + `BridgeIdRepository` and injects it, the repository, and
  nullable registration service into `BridgeLogoutRunner`. After any running-
  bridge decision accepts logout, the runner invokes migration and then
  `registrationService?.unregister()` inside one observable best-effort block;
  it then clears tokens through `TokenRepository` and maps a typed clear failure
  to the existing failed result. No unregister or persistence callback remains.
- `LogoutCommand` owns lifecycle only: in `finally` it disposes nullable
  `BridgeRegistrationService`, nullable `TokenService`, `TerminalPromptApi`, and
  then the command-owned HTTP client. `BridgeLogoutRunner` owns none of those
  collaborator lifecycles.

### Terminal ownership

- `TerminalPromptApi` accepts `Stdin`/`Stdout` plus invocation environment,
  exposes only raw terminal attachment/capability/width/environment facts and
  I/O, and contains no mode/rendering decision.
- `TerminalPromptRepository` maps the legacy relaunch marker to
  `legacyPostUpdate`, both attached handles to `interactive`, all other cases to
  `unavailable`, and separately maps ANSI/Unicode/polarity/safe nullable width
  into `TerminalRenderingCapabilities`.
- `BridgeRuntimeRunner` and logout ask the repository for those typed values;
  neither reads/maps raw API facts. Logout disposes `TerminalPromptApi` in
  `finally`.
- `TerminalPromptApi` does not subscribe to stdin in its constructor. The first
  standalone prompt/read starts one lazy process-lifetime decoded-line
  subscription. Every completed line enters an internal FIFO pending-line
  buffer even when no prompt is awaiting, preserving ordinary OS-stdin
  type-ahead across sequential non-secret prompts.
- Sequential prompt methods consume one oldest pending line or await one queued
  arrival from that owner. The onboarding decision read is cancellable; when
  cancellation wins it removes only its own pending waiter and leaves every
  already-queued or later line for the replacement/auth prompt.
- Only one prompt is active by startup sequencing; add guards/tests against
  overlapping consumers. The FIFO is input preservation, not a scheduler for
  competing prompts.
- Password input is the explicit security exception to FIFO type-ahead. Before a
  line can be accepted as a password, the API atomically disables echo and
  discards every line queued before that switch. The repository reports that
  pre-prompt input was discarded and requests a fresh password while echo stays
  off; only a line received after the switch is accepted. Restore the prior echo
  value in `finally` on value, EOF, error, or disposal. Do not claim support for
  pasted email+password batches without a future safe raw/bracketed-paste design.
- EOF closes the line source and maps to existing clear provider/credential
  failures or onboarding fail-open.
- `dispose` cancels the underlying subscription/controller exactly once and is
  registered with `BridgeShutdownCoordinator`.
- Supervised mode reads its off-argv control secret before any terminal prompt
  subscribes; onboarding is gated out. Preserve `ControlSecretApi` and do not
  route the bearer secret through the user-prompt line owner.

### Formatter contract

- One URL constant is passed to QR encoding and plain output; tests compare
  exact bytes so they cannot drift.
- Use the pinned/audited `qr` API with a fixed error-correction level; never
  implement QR encoding manually.
- Add four light modules on every edge.
- Render only when both ANSI and Unicode validators succeed, using compact half
  blocks with explicit black/white foreground/background and final reset.
  Non-ANSI Unicode and ASCII space/block renderers are prohibited because theme
  polarity is unknown and a light quiet zone cannot be guaranteed.
- Use existing glyph/color validators and a safely-read nullable terminal width.
- Compute full width including quiet zone before rendering. Unknown/throwing/
  insufficient width returns no QR string, not a truncated code.
- Formatting failure is isolated to URL-only output and one warning; it never
  skips the registration wait or crashes startup.

### Onboarding service state machine

This repeated server-held long poll is an explicit user-approved exception to
the push-based default, alongside the existing authentication request/response
flow. Keep the exception local to `AppClientOnboardingService` and
`AppClientPresenceRepository`: each request remains server-held and wakes from
durable registration; normal false expiry immediately opens the next request
without a client timer. Do not extract a generic polling service or move retry,
terminal, or output policy into the repository.

1. Create one `AuthRequestCancellationController`; pass its signal to every
   token/status operation. Do not arm or consume onboarding input during the
   initial silent request: no onboarding/retry guidance exists yet, and every
   typed line must remain queued for a later real prompt if registration is
   already current.
2. Immediate check:
   - service obtains
     `TokenRefresher.getAccessToken(forceRefresh: false, cancelled: controller.signal)` and passes the
     value/same signal to the repository;
   - `TokenAccessFailureKind.transient` follows the same one-warning/
     fixed-60-second policy; `unavailable` fails open because interactive auth
     already completed; `cancelled` is expected skip/EOF with no error warning;
   - first unauthorized -> service calls
     `getAccessToken(forceRefresh: true, cancelled: controller.signal)` and
     retries once immediately;
   - unauthorized after that retry -> warn once and fail open;
   - registered -> finish silently;
   - absent -> print full onboarding once, arm the onboarding decision reader,
     and enter long poll;
   - unavailable -> warn once and fail open;
   - transient -> print warning plus skip guidance, arm the onboarding decision
     reader, race skip with fixed 60-second delay, then repeat immediate check
     without falsely showing QR;
   - skip/EOF -> cancel and continue according to locked output policy.
3. Long poll:
   - acquire the current token for the attempt; retain the same one-refresh cap
     within that attempt and reset the cap after any non-401 response;
   - registered -> print success and finish;
   - absent -> immediately repeat long poll with no warning/delay;
   - unavailable -> warn once and fail open;
   - transient -> warn once, fixed cancellable 60-second delay, then long poll;
   - skip/EOF -> abort and continue.
4. A single completion gate cancels the controller and retry timer/input
   subscription, awaits any active token/status operation to settle its abort,
   and prints at most one terminal outcome before startup orchestration proceeds.

Warnings are emitted by this service only. API/repository throw or return typed
outcomes without logging. Essential aliases remain visible when a failure first
makes the checkpoint wait even before absence was confirmed.

### Startup orchestration and runner handoff

```text
legacy bridge-id migration
-> BridgeRuntimeRunner composes shared SesoriAuthApi + repositories from its owned http.Client
-> supervised control bootstrap OR standalone auth through migrated repositories
-> compose one access-token provider/refresher (standalone TokenService or control service)
-> authenticated-user output
-> resolve descriptor + quick checkAvailability
-> read typed TerminalInteractionMode/rendering capabilities from TerminalPromptRepository
-> if standalone and mode == interactive: onboarding service
-> startup mutex / single-live-bridge decision / provision / plugin start
-> reuse same token provider/refresher for registration, relay, runtime
-> existing BridgeRuntime.create / session Orchestrator handoff
-> runner executes runtime and owns final shutdown/disposal
```

No network onboarding runs when `options.isSupervised` or terminal is not
interactive. A plugin-unavailable result exits before onboarding. The
checkpoint does not construct/hold a plugin, backend runtime, startup lock,
bridge registration, or relay connection.

### Error, cancellation, concurrency, lifecycle

- Skip aborts a live HTTP request and a retry timer; `RequestAbortedException`
  caused by skip is expected and silent.
- Skip during forced refresh propagates the same signal through `TokenService`,
  `AuthRepository`, and `SesoriAuthApi`, actively closes the refresh request, and
  is awaited before continuation.
- The active client deadline aborts the request, then follows transient policy.
- A normal server false response is not a timeout exception.
- Refresh remains single-flight through `TokenService`; startup ordering gives
  onboarding exclusive use before bridge registration/runtime consumers exist.
- Invalid input leaves request and waiter active and reprints aliases.
- Detection/skip/EOF/failure races resolve once; late futures cannot print,
  retry, or consume later terminal lines.
- Shutdown disposes terminal and shared clients through existing coordinator;
  no timer/subscription/request survives.
- The service retries indefinitely only while its one invocation remains active.

## 6. Backward Compatibility

### Old/custom auth server

Place this marker immediately above the repository's 404/405 fallback, with the
actual implementation date and currently declared version:

```dart
// COMPATIBILITY <implementation-date> (v1.5.1): Auth servers predating app-client status return 404/405, so onboarding must fail open for older/custom deployments. Remove this fallback and its endpoint-omission tests after every supported auth server exposes GET /auth/app-clients/status.
```

Fallback behavior: return typed unavailable, let the service warn once that app
status could not be checked, then continue. Do not treat endpoint absence as
`registered: false`, which would incorrectly display an indefinite prompt.

Affected pairs:

- new bridge `v1.5.1+` -> auth server before S01-W01-P01: fail open;
- new bridge -> new server: full checkpoint;
- old bridge -> new server: endpoint unused, no change.

Cleanup is mechanical: delete the 404/405 special mapping and omission fixture,
then let endpoint absence use the current unsupported-contract policy selected
when all supported deployments expose it. Do not remove general permanent
failure handling with the legacy branch.

### Existing CLI behavior

- Provider menu wording/choices and EOF guidance remain unchanged.
- Email and password prompt text, password no-echo, and login errors remain
  unchanged.
- Replacement/startup-contention yes/no defaults remain unchanged.
- Logout decisions/results remain unchanged.
- Supervised control-secret input remains isolated and off argv.
- New onboarding output exists only for confirmed absence or a transient status
  failure requiring user-visible skip guidance.

### Persistence/wire compatibility

No bridge database, settings, token-file, shared relay model, CLI/config shape,
or plugin contract changes. The additive shared `EmailLoginRequest` and
`RefreshTokenRequest` classes model already-shipped auth request bodies and do
not change their wire bytes. Skip and waiter state is memory-only.

`SesoriAuthApi` consolidation is source-internal. Existing email, OAuth,
profile/validation, refresh, bridge registration/deletion HTTP request shapes,
status handling, DTOs, timeouts, and user-visible errors remain regression
contracts. The PR deletes old APIs/helpers only after all callers and tests use
the consolidated API through repositories; no deprecated forwarding alias is
shipped. The required auth cancellation parameter is internal bridge source
compatibility, and every production/test implementation and caller lands in the
same PR.

The existing `v1.3.0` legacy bridge-id compatibility marker moves immediately
with `readLegacyBridgeId` JSON mapping from `token.dart` to `TokenRepository`;
preserve its original date/version/rationale and update only the exact mechanical
cleanup to name `TokenRepository` and `BridgeIdMigrationService`. Raw access
still delegates to `TokenStorage`. Do not duplicate the marker or leave a
forwarding top-level reader.

## 7. Generated-Code and Dependency Work

1. Add sealed Freezed `EmailLoginRequest(email, password)` and
   `RefreshTokenRequest(refreshToken)` under shared auth models with generated
   `fromJson`/`toJson`, export both from `sesori_shared.dart`, and add exact-map
   tests.
2. Run `dart pub get` and
   `dart run build_runner build --delete-conflicting-outputs` from
   `shared/sesori_shared`; review only the two models' generated files and any
   expected lock change.
3. Add the audited pure-Dart `qr` constraint to `bridge/app/pubspec.yaml`.
4. Run `dart pub get` from `bridge/`; inspect `bridge/pubspec.lock` for only
   expected dependency resolution.
5. Define required non-null `AppClientPresenceResponse.registered` in source and
   make `SesoriAuthApi` serialize the shared request DTOs rather than inline maps.
6. Run `make codegen` from `bridge/`.
7. Review all generated files; never hand-edit `*.freezed.dart` or `*.g.dart`.
8. No Drift table, schema version, migration, snapshot, or migration test.

## 8. Verification

### Automated tests

#### API

- One `SesoriAuthApi` owns base URL/client and every migrated method; no
  `LoginEmailApi`, `LoginOAuthApi`, `BridgeRegistrationApi`, profile/validate
  HTTP function, or token-manager inline HTTP remains.
- Preserve email login, OAuth init/status/ACK, `/auth/me`, refresh, bridge
  register/delete request/response/status fixtures byte-for-byte.
- Shared `EmailLoginRequest` and `RefreshTokenRequest` serialize exact legacy
  key/value maps; consolidated email/refresh operations contain no inline JSON
  request maps.
- Because `sesori_shared` is consumed across products, unchanged bridge, mobile,
  module-core/auth, desktop-core, and desktop-shell dependency graphs all resolve
  and analyze; relevant package tests pass. No `module_app_ui` package exists at
  the pinned baseline, so there is no shared-app-UI command to run.
- Base URL with/without trailing slash; immediate and `wait=true` app-status URI.
- Bearer header and no token in URI/body/logs.
- Strict true/false response parsing.
- 4xx/5xx typed status failures without raw body exposure.
- Malformed/missing/non-boolean `registered` fails as protocol error.
- Pre-cancel prevents app-status/refresh allocation; later skip abort closes each
  in-flight request promptly.
- 35-second status and 15-second refresh deadlines actively abort, report typed
  timeout, and clean timers.

#### Repository

- `AuthRepository` maps `/auth/me` and refresh DTO/status/network/cancel outcomes
  without persistence or message parsing; `BridgeRuntimeAuthService` preserves
  existing validate/refresh/login decisions.
- `LoginOAuthRepository`, `LoginEmailRepository`, and
  `BridgeRegistrationRepository` preserve existing mapping over the shared API
  and remain independent peers.
- Current token success/absence mapping.
- Caller-supplied token is forwarded exactly; repository has no `TokenRefresher`
  dependency and performs no refresh/retry.
- 401 maps to typed unauthorized without becoming transient/permanent locally.
- 404/405 compatibility fallback and exact cleanup-marker fixture.
- 400/403/other permanent 4xx and malformed response become unavailable.
- 408/429/5xx, socket/client exception, and active deadline become transient.
- User skip remains cancellation, not transient warning/retry.
- Repository emits no logs/output.

#### Token contract and implementations

- `TokenStorage` preserves raw read/write/clear, path, and permissions while
  `TokenRepository` maps JSON/provider validation, missing/corrupt state, and
  legacy bridge-id compatibility behavior. Auth service, token service,
  migration, and logout tests inject the repository with no storage dependency
  or load/save/clear callback getters.
- `BridgeIdRepository` is the only `BridgeIdStorage` consumer; registration,
  migration, revocation, and logout tests prove services never import storage.
- `AuthRequestCancellationSignal.never` never cancels; controller cancel is synchronous,
  idempotent, emits one cancellation, and closes once.
- Successful/error/timeout app-status and refresh requests cancel their
  request-scoped cancellation subscription and timer; repeated healthy long
  polls and successful `never` refreshes leave zero retained abort callbacks.
- Every production `TokenRefresher` caller passes required `forceRefresh` and
  cancellation values; ordinary existing flows pass `false`/`never` and retain
  behavior. Every fake compiles with the signature.
- `TokenService` refresh success retains storage re-read, persistence,
  publication, and single-flight behavior over `AuthRepository` and
  `TokenRepository`.
- A cancellable near-expiry call awaits refresh and can abort it with no detached
  work; an `AuthRequestCancellationSignal.never` near-expiry call preserves shipped
  background-refresh/return-current behavior.
- Token refresh HTTP 408/429/5xx, socket/client/deadline map to typed transient;
  initial local missing/corrupt/revoked/4xx/malformed and post-response cleared
  state map unavailable; caller abort maps cancelled, all without parsing
  messages. A post-response `FormatException` alone repairs from the valid
  pre-refresh `lastProvider` plus new response tokens.
- Cancellation before/during refresh prevents or actively aborts transport,
  leaves no active refresh future/request, does not persist/publish a token, and
  allows a later uncancelled refresh.
- `ControlChannelTokenService` pre/during cancellation removes its pending id,
  throws typed cancelled failure, and ignores late replies; disconnected/timeout
  assertions require transient, null-token/signed-out/disposed assertions require
  unavailable, and existing push/newest-issued ordering remains unchanged.
- Supervised bootstrap still returns `authRequired` for either transient or
  unavailable token access, preserving current GUI behavior after removing
  `ControlTokenUnavailableException`.

#### Service

- Access token is obtained per attempt; first unauthorized forces exactly one
  refresh and immediate repository retry, second unauthorized warns/fails open,
  and a later normal long-poll round starts with a fresh one-refresh allowance.
- Token-refresher network/timeout errors use the fixed transient timer;
  explicit missing/revoked/initially corrupt token-authority failures fail open
  once; post-response corruption repair remains a successful refresh.
- Initial registered: no onboarding, warning, or success output.
- Initial registered leaves every pre-typed non-onboarding line queued for the
  next replacement/auth prompt.
- Initial absent: instructions/QR-or-fallback/URL output exactly once in order.
- Exact URL is both QR payload and plain line.
- Registration after prompt: one success and continuation.
- `s`, `S`, `skip`, surrounding whitespace accepted; other lines reprint help.
- Skip during a guided immediate retry, long poll, and 60-second delay aborts
  promptly; the first silent request consumes no terminal line.
- Skip input is armed only after confirmed absence or the first transient warning
  exposes skip guidance; before that point all lines remain queued. Once armed,
  invalid lines retain the existing onboarding help/retry behavior.
- Skip during forced token refresh aborts transport and the service waits for
  cancellation settlement before continuing startup.
- Skip is not persisted; a second service invocation prompts again.
- Normal false long-poll repeats immediately with zero warnings and zero delay.
- Each transient attempt emits one warning, arms exactly one internal 60-second
  cancellable timer, and retries only after `fake_async` elapses it; repeated
  failures prove indefinite policy without a delay callback.
- Permanent/unavailable warns once and fails open.
- EOF/terminal loss aborts and fails open once.
- QR formatter exception falls back to URL and continues waiting.
- Simultaneous registration/skip completes once with no late output/request.

#### Terminal and existing auth prompts

- Lazy single subscription, FIFO pending-line buffering, and deterministic dispose.
- Sequential async reads preserve ordinary lines typed before the next prompt;
  onboarding cancellation removes its waiter without dropping queued/later lines.
- Raw API terminal/environment facts contain no product policy;
  `TerminalPromptRepository` maps typed interaction mode and rendering
  capabilities, preserving interactivity and legacy post-update behavior.
- Provider choices 1-4, invalid retry, and EOF guidance unchanged.
- Email/password values and password echo restoration on success/EOF/error.
  A line queued before echo-off is never accepted as the password: it is
  discarded, a clear re-entry message is emitted while echo remains off, and a
  fresh post-switch line is required.
- Replacement yes/yes alias/default decline/noninteractive unchanged.
- Logout prompt/result behavior unchanged.
- Supervised `ControlSecretApi` still reads the first off-argv line without a
  competing prompt subscriber.

#### Formatter

- QR module orientation/payload for exact URL and chosen correction level.
- Four-module quiet zone on all edges.
- ANSI+Unicode output uses explicit black/white cells and final reset.
- Missing ANSI, missing Unicode, unknown polarity/width, and insufficient width
  omit QR and retain exact URL; no non-ANSI Unicode/ASCII QR is emitted.
- Exact-fit width renders; one-column-too-narrow and unknown/throwing width omit.
- URL-only output remains exact and scan instructions mention same account.
- Deterministic snapshots contain no terminal-dependent global reads.

#### Startup composition and regression

- Standalone interactive runs after plugin availability and before plugin start.
- Initial registered path is silent.
- Supervised and noninteractive paths never call status API or formatter.
- Plugin unavailable exits before status check.
- Startup mutex/provision/plugin starter are not entered until onboarding settles.
- One early standalone `TokenService` is reused for onboarding, registration,
  relay/runtime and disposed once.
- `BridgeRuntimeRunner` constructs one `SesoriAuthApi` over its shared client,
  injects all auth repositories/services, and leaves no superseded use-case API
  constructor.
- `_buildRegistrationService` receives the composed `SesoriAuthApi` instead of
  auth URL/client pass-through parameters and is owned by startup orchestration.
- Logout tests cover every typed token-read outcome. Available constructs
  command-owned `TokenService` + `BridgeRegistrationService`; missing constructs
  neither; corrupt/failure warns once and constructs neither. Every path injects
  `BridgeIdMigrationService` and `TokenRepository` into the runner. Accepted
  logout orders migration -> optional best-effort unregister -> repository clear;
  cancelled logout performs none. `finally` disposes optional registration,
  optional token service, terminal API, and command-owned HTTP client exactly
  once in that order, including exceptions.
- `BridgeRuntimeAuthService` lives in root services, receives no
  `BridgeCliOptions`, and imports no runtime/server higher-layer type.
- Existing session `Orchestrator` is created only after plugin start through the
  existing `BridgeRuntime.create` handoff; that factory gains no onboarding,
  auth, terminal, or startup policy.
- `runBridgeApp` remains in runner source and runner preserves process startup,
  session/exit/failure, desktop-supervised, and future parallel-plugin ownership.
- No `BridgeStartupOrchestrator` or third composition owner exists. Tests assert
  the user-approved two-phase boundary: runner before plugin/session handoff,
  existing `Orchestrator` afterward.
- Runner retains shutdown/finally ownership and cleans partially prepared phases.
- Success, skip, and fail-open continue normal plugin/registration startup.
- Existing provider/email/OAuth, replacement, logout, plugin startup, bridge
  registration, and shutdown tests pass.

### Manual verification

Execute S01-W02-M01 after an auth deployment and bridge build are available.
Automated tests are authoritative for exact 60-second timing and rare races;
manual work focuses on real terminal/camera behavior and user-visible flow.

### Exact commands

```text
# workdir: shared/sesori_shared
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze
dart test

# workdir: bridge
dart pub get
make codegen
make analyze
make test

# workdir: bridge/app
dart analyze --fatal-infos
make build-host

# workdir: client
dart pub get

# workdir: client/module_auth
dart analyze
dart test

# workdir: client/module_core
dart analyze
dart test

# workdir: client/app
dart analyze
flutter test

# workdir: client/module_desktop_core
dart analyze
dart test

# workdir: client/desktop
dart analyze
flutter test
```

If `dart pub get` or code generation changes unrelated modules, stop and explain
the resolution conflict rather than committing broad generated/lock churn.

### Regression guide

- Start with valid stored OAuth and email credentials; profile output and later
  registration still use the same refreshed token.
- Exercise replacement and logout after onboarding has completed to prove later
  prompts receive lines and password/terminal modes are normal.
- Type/paste a second credential line before the password no-echo phase and
  confirm it is discarded rather than accepted; enter a fresh password after
  the re-entry message and confirm echo is restored afterward.
- Start supervised bridge with control secret to prove no terminal subscription
  steals the secret and no onboarding request occurs.
- Start noninteractive/legacy post-update to prove no hang/output/request.
- Run with old-server 404 fake to prove startup continues once, not an indefinite
  missing-app prompt.
- Verify no plugin process/provisioning/startup lock exists during a deliberately
  held onboarding wait.

## 9. Risks

- A `Future.any` without cancellation could leave stdin/HTTP alive; use owned
  subscriptions and active abort, then assert no late effects.
- Starting the stdin subscription in the constructor could steal supervised secret;
  require lazy first-prompt subscription and mode tests.
- FIFO type-ahead could accept a password that arrived while echo was enabled;
  atomically disable echo and discard all pre-switch queued lines before
  accepting secret input, then regression-test re-entry and restoration.
- Moving/renaming the legacy token owner could create duplicate refresh
  authorities; compose one `TokenService` instance early and reuse current later
  variables.
- Consolidating existing auth HTTP could create a broad behavior regression;
  preserve every old request fixture/status mapping and delete wrappers only
  after repositories/services and logout composition are migrated.
- A cancellable refresh shared with another consumer could cancel unrelated
  work; startup sequencing gives onboarding exclusive `TokenService` use until it
  settles, and existing later callers pass `forceRefresh: false` plus
  `AuthRequestCancellationSignal.never`.
- Treating initial network failure as absence could falsely prompt existing
  users; show only minimal retry/skip guidance until a real false response.
- Treating 404 as absence would hang old servers; map to compatibility-unavailable.
- Using terminal foreground colors alone can invert by theme; prefer explicit
  black/white ANSI cells and retain URL/manual scans.
- QR truncation destroys scans; precompute width and omit rather than clip.
- A formatter/service god class could mix transport, token, terminal, and QR
  policy; keep API/repository/formatter/service ownership explicit.
- Broad terminal migration could alter auth behavior; signatures/tests preserve
  visible contracts and remove only undefined mixed input.
- Startup composition could drift away from desktop/parallel-plugin ownership;
  retain runner as the process composer, existing `Orchestrator` as the live
  session composer, and add no third composer or policy to `BridgeRuntime.create`.
- Shared auth DTO generation could create unrelated churn; inspect generated and
  lock diffs and stop rather than committing changes outside the two request
  models, barrel, tests, and declared bridge response/dependency output.

## 10. Acceptance Criteria

- Mode, ordering, and silent-current behavior match the locked product flow.
- Confirmed absence prints bounded QR when safe and always exact URL.
- Same-user registration wakes and resumes with one success message.
- Both skip aliases cancel request/delay and affect only current run.
- Skip also actively aborts an in-flight token refresh; the service awaits it and
  leaves no refresh/status/control request behind.
- Normal expiry is silent/immediate; transient failure is one warning + exact
  fixed 60 seconds; permanent failure is one warning + fail open.
- One 401 refresh and old-server compatibility behavior are tested and marked.
- `SesoriAuthApi` is the only Sesori-auth `Api`; all migrated existing operations
  retain tests and no forwarding use-case API/top-level HTTP remains.
- `TokenRefresher` cancellation and typed failure contracts cover both production
  implementations, all callers, and all fakes without message parsing.
- `TokenRepository` is injected into `TokenService`, runtime auth, migration,
  and logout; only it accesses `TokenStorage`. `BridgeIdRepository` is the sole
  `BridgeIdStorage` consumer. Touched constructors have no persistence callbacks,
  and the forbidden `TokenManager` name/file is gone.
- `BridgeLogoutRunner` receives `BridgeIdMigrationService`, `TokenRepository`,
  and nullable `BridgeRegistrationService` directly; typed composition-time token
  selection, migration -> optional unregister -> clear ordering, and command-
  owned disposal are exhaustive in tests with no callback forwarding boundary.
- Terminal API/repository/Foundation files live at root layer paths, and the root
  onboarding service has no dependency on `server/`.
- Root `BridgeRuntimeAuthService` has no runtime-options dependency;
  `BridgeRuntimeRunner` remains the user-approved process-startup composer and
  existing `Orchestrator` the post-start composer, with no third owner.
- Existing prompts and supervised secret remain correct under one async stdin
  owner.
- No plugin/startup lock is held while waiting; no lifecycle resource leaks.
- Generated/lock output is tool-produced and scoped; all commands pass.
- Shared email-login/refresh DTOs are additive and exact-body compatible; no
  analytics, config, persisted schema, browser, plugin, relay, mobile, or desktop
  behavior changes are included.

## 11. Definition of Done

- Scope, tests, generated output, dependency lock, manual guide, compatibility
  marker, and regression evidence are complete on the pinned `main` baseline.
- Architecture-bearing implementation receives the worker's configured
  implementation review before PR opening.
- Only intended monorepo files are committed; branch is pushed and PR targets
  `main`.
- `TRACKER.md` records S01/W02 baseline, branch, PR URL, checked state, and any
  findings while retaining imported W01 state. Its merge returns authoritative
  tracker state to `main`; the tracking branch becomes cleanup-only. The
  advisory manual row remains independently checkable.
- Auth endpoint is deployed before the bridge release is initiated.
