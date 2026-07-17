# S01-W02-P01: Add Interactive Bridge App Onboarding

## 0. Metadata

- **ID:** S01-W02-P01
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Worktree:** one dedicated monorepo worker worktree for this PR
- **Base branch:** `main`
- **Branch:** `plan/bridge-app-onboarding/s01-w02-p01-interactive-app-onboarding`
- **Wave baseline:** pin the assessed current `main` tip in `TRACKER.md` before branch creation
- **Audited reference:** `5a76c0c420cd7db445f7fe2c8a2570265b4c84e0`
- **Audited reference date:** 2026-07-17T06:57:01Z
- **Contract-affecting:** Yes — auth HTTP consumption, CLI prompt behavior, and shipped old-server compatibility

## 1. Goal and Cohesion

Add the complete standalone interactive bridge checkpoint over the merged auth
contract: safe asynchronous terminal ownership, initial current-registration
check, bounded QR/URL guidance, instant server wake, explicit current-run skip,
fixed one-minute transient retry, and permanent fail-open compatibility.

The PR is independently cohesive because all bridge-side API, repository,
service, terminal, composition, generated model, tests, and dependency work land
together. No intermediate build can start an uncancellable prompt or consume a
contract without typed fallback behavior.

The existing auth HTTP consolidation is required, not opportunistic cleanup:
the scoped architecture permits one API owner per external provider, so adding
app status cannot create another use-case API. Moving the existing operations
and cancellable refresh into `SesoriAuthApi` in this same PR is the smallest
release-safe boundary; splitting it would either leave duplicate provider APIs
or make onboarding depend on an unmerged internal stack.

## 2. Dependencies and Baseline

- S01-W01-P01 is merged to auth-server `master`; its exact endpoint contract is
  re-read rather than inferred from this plan.
- Auth deployment is available before bridge release. Local tests may use a fake
  server and do not require production credentials.
- Fetch monorepo `main`, assess drift from
  `5a76c0c420cd7db445f7fe2c8a2570265b4c84e0` in every expected auth/runtime/
  terminal/pubspec/test path, and pin the exact tip before branching.
- Re-read existing root `AGENTS.md`, `bridge/AGENTS.md`, and
  `bridge/app/AGENTS.md`, plus `docs/VISION.md`, `docs/ROADMAP.md`, and current
  active plans. No scoped plugin-interface instruction file exists or is needed
  because this PR does not modify that package.
- Re-read `bridge/app/pubspec.yaml` and `lib/src/version.dart` immediately before
  writing the compatibility marker; audited version is `1.5.1`.
- Same-wave sibling baseline reuse is not applicable; this wave has one PR. The
  manual checkpoint consumes the merged/deployed result rather than a branch.

## 3. Scope

### In Scope

- Add pure-Dart `qr` as a direct `bridge/app` dependency and update workspace
  resolution/lockfile through normal tooling.
- Add bridge-local Freezed `AppClientPresenceResponse` and generated JSON code.
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
- Extend `TokenRefresher.getAccessToken` with a required auth-local
  `AuthRequestCancellationSignal`;
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
  owner with deterministic disposal, output/capability access, EOF, and password
  echo restoration; remove environment/startup-mode policy from this API.
- Add typed `TerminalInteractionMode`, resolved by startup-orchestrator/logout composition
  roots from raw terminal facts and the legacy relaunch marker, then injected
  into `TerminalPromptRepository`.
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
- Add root Layer-5 `BridgeStartupOrchestrator` as sole constructor/owner of the
  auth, terminal, token, onboarding and existing startup graph. It owns pre-plugin
  sequencing/disposal, starts the plugin, creates the existing session
  `Orchestrator` only afterward, injects that completed session into plain
  `BridgeRuntime`, then directly injects the completed runtime and typed
  failure/restart/supervised collaborators into `BridgeRuntimeRunner`.
- Delete static `BridgeRuntime.create`; the existing generative `BridgeRuntime`
  constructor receives already-built collaborators and session.
- Reduce `BridgeRuntimeRunner` to a consumer of four direct already-built
  runtime/outcome collaborators; it must
  not construct an API, repository, service, token/terminal owner, plugin
  collaborator, or session orchestrator.
- Add focused API/repository/service/formatter/terminal/auth/runner tests and
  compile the host native bridge.

### Non-Goals

- Changing shared models, plugins, relay, mobile, desktop, auth server, or app UI.
- Migrating `PushNotificationClient`: it is an existing transport `Client`, not
  another `Api` class, and its notification-send ownership remains unchanged.
- Running onboarding in `--control-url` supervised mode or any noninteractive
  path.
- A new CLI option, config field, persisted skip, browser launch, store API, or
  platform-specific deep link.
- Raw one-key input, terminal raw mode, clearing partially typed terminal input,
  shelling out to detect width/color, or adding a terminal-size dependency.
- Retrying normal long-poll expiry with a timer.
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
- `TerminalGlyphValidator` and `TerminalColorValidator` are existing Layer-0
  policy; `Stdout.terminalColumns` may throw and must be treated as unknown.
- `http ^1.6.0` supports active request abort. A plain `Future.timeout` that
  leaves a request alive is insufficient.
- No `qr` dependency or terminal QR implementation exists at the audited tip.
- The exact app URL is a product constant, not the configurable auth/relay URL.

## 5. Design and Ownership

### Expected source/dependency files

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
- `bridge/app/lib/src/auth/token_storage.dart` (new concrete token-file boundary)
- `bridge/app/lib/src/auth/token.dart` retains `TokenData`/path values but moves
  load/save/clear/legacy-read I/O into `TokenStorage`
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
- `bridge/app/lib/src/foundation/terminal_interaction_mode.dart` (new typed
  composition policy)
- move existing terminal-only `server/foundation/terminal_prompt_decision.dart`
  and `bridge_replace_prompt.dart` to root `lib/src/foundation/`; place the small
  typed onboarding outcome there as well, so the root repository has no outbound
  dependency on the minimal `server/` subsystem
- move `bridge/app/lib/src/bridge/runtime/bridge_runtime_auth.dart` to
  `bridge/app/lib/src/services/bridge_runtime_auth_service.dart`
- `bridge/app/lib/src/bridge_startup_orchestrator.dart` (new root Layer-5 startup
  and session composer/lifecycle owner)
- `bridge/app/lib/src/bridge/runtime/bridge_runtime.dart` to delete the static
  composition factory and retain only lifecycle over injected session/
  collaborators
- `bridge/app/lib/src/bridge/runtime/bridge_runtime_runner.dart`
  removes top-level `runBridgeApp` and every lower-layer constructor/helper;
  retains only ready-runtime execution and typed exit mapping
- `bridge/app/bin/bridge.dart` for logout-command interaction-mode composition
  and terminal API disposal
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

AppOnboardingFormatter
  <- AppClientOnboardingService

all startup APIs/repositories/services
  <- BridgeStartupOrchestrator (Layer 5 constructor + phase owner)
     -> existing session Orchestrator after plugin start
     -> BridgeRuntimeRunner with direct already-built collaborators (consumer only)
```

- `SesoriAuthApi` is the single per-provider HTTP/JSON/abort boundary. No
  use-case API forwards to it.
- Repository accepts a caller-supplied access token and owns only
  transport-to-domain normalization.
- Service owns access-token acquisition, exactly-one forced refresh/retry,
  timer/retry/output/race policy.
- `BridgeStartupOrchestrator` composes and sequences; runner contains no inline
  construction, HTTP, QR, input parser, or service factory.
- Existing terminal repository remains the sole prompt normalization boundary;
  no auth repository depends on it as a peer.
- `LoginEmailRepository.performEmailLogin` receives already-normalized required
  email/password from `BridgeRuntimeAuthService`; the repository no longer owns
  prompt acquisition.
- `LoginOAuthService` depends on `LoginOAuthRepository`, not the API.
- `TokenService` depends on `AuthRepository` plus concrete `TokenStorage`, not
  callbacks or the API, and implements the
  cancellable token contract. `BridgeRuntimeAuthService` uses `AuthRepository`
  for current `/auth/me`/refresh mapping and the same `TokenStorage` for local
  reads/writes/clear instead of callbacks or top-level HTTP helpers.
- `BridgeIdMigrationService` and touched logout paths also receive
  `TokenStorage` directly; load/save/clear/legacy-read callbacks are removed.

### Exact constructors and lifecycle owners

```dart
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

TokenService({
  required String initialToken,
  required AuthRepository authRepository,
  required TokenStorage tokenStorage,
})

BridgeRuntimeAuthService({
  required LoginEmailRepository loginEmailRepository,
  required LoginOAuthService loginOAuthService,
  required AuthRepository authRepository,
  required TokenStorage tokenStorage,
  required TerminalPromptRepository terminalPromptRepository,
})

BridgeRuntimeAuthService.ensureAuthenticated()
BridgeRuntimeAuthService.logAuthenticatedUser({required String accessToken})

BridgeIdMigrationService({
  required BridgeIdStorage bridgeIdStorage,
  required TokenStorage tokenStorage,
})

BridgeLogoutRunner({
  required BridgeInstanceRepository bridgeInstanceRepository,
  required BridgeInstanceService bridgeInstanceService,
  required TerminalPromptRepository terminalPromptRepository,
  required TokenStorage tokenStorage,
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
  bool forceRefresh = false,
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
  required bool supportsAnsi,
  required bool supportsUnicode,
  required int? terminalColumns,
})

TerminalPromptApi({required Stdin stdin, required Stdout stdout})

TerminalPromptRepository({
  required TerminalPromptApi api,
  required TerminalInteractionMode interactionMode,
})

BridgeStartupOrchestrator.compose({
  required BridgeCliOptions options,
  required PluginConfig pluginConfig,
  required String pluginId,
})

BridgeRuntimeRunner({
  required BridgeRuntime runtime,
  required PluginFailureLatch failureLatch,
  required BridgeRestartService restartService,
  required bool isSupervised,
})
```

Production composition passes 35 seconds and 60 seconds explicitly. The API
stores the startup orchestrator's shared `http.Client` and never closes it; the
startup orchestrator's shutdown coordinator remains its owner. `TerminalPromptApi` owns and
disposes its lazy stdin subscription. `AppClientOnboardingService` owns one
`AuthRequestCancellationController`, the onboarding input subscription, and one internal
cancellable `Timer` for each retry wait. It cancels that timer on
skip/success/fail-open/EOF; tests use existing `fake_async` rather than injecting
a delay callback or constructing a timer collaborator.

`AuthRepository` receives an explicit 15-second refresh request timeout and
passes the caller's `AuthRequestCancellationSignal` to `SesoriAuthApi.refreshTokens`.
`AppClientPresenceRepository` receives the 35-second status timeout and passes
the same signal to the API. `AuthRequestCancellationSignal.never` is the explicit
value for existing uncancellable callers; onboarding owns an
`AuthRequestCancellationController` and
passes its signal through token acquisition and app status. No nullable/default
cancellation or message parsing is allowed.

`AuthRequestCancellationSignal` is an auth-local read side with
`AuthRequestCancellationSignal.never`, synchronous
`canCancel`/`isCancelled`, and `Future<void> get whenCancelled`;
`AuthRequestCancellationController` is the idempotent write side owned by
onboarding. Keeping it in `auth/` preserves that subsystem's autonomy; the plan
does not reuse/modify plugin `StartAbortSignal` or import root core Foundation
into auth. API/token code checks `isCancelled` before allocating a request and
races only `whenCancelled` after allocation.

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

Immediately before composing onboarding, `BridgeStartupOrchestrator` resolves immutable
formatter facts with existing `TerminalColorValidator`,
`TerminalGlyphValidator`, and `TerminalPromptApi`'s safe nullable width read.
The formatter stores only those scalar facts and owns no stream, environment,
stdout handle, or lifecycle.

### Layer-5 startup ownership

- Move `runBridgeApp` from `bridge_runtime_runner.dart` into root
  `bridge_startup_orchestrator.dart`. `bin/bridge.dart` imports the root
  entrypoint; runner never imports startup orchestrator, so no cycle exists.
  `runBridgeApp` only calls `BridgeStartupOrchestrator.compose` with parsed
  CLI/plugin inputs and awaits `run`; it constructs no lower-layer graph.
- The startup orchestrator absorbs current runner composition for every API,
  repository, service, process/terminal/token owner touched by startup. It owns
  the shared clients, shutdown coordinator, control channel, auth, plugin
  availability, onboarding, startup mutex/provision/start sequencing,
  registration/relay/runtime construction, debug/update/signal setup, and all
  pre-run failure/exit cleanup.
- It starts no plugin before onboarding settles and holds no startup mutex while
  waiting. After plugin start, it directly constructs the existing session
  `Orchestrator`, then injects that completed `OrchestratorSession` and already-
  built lifecycle collaborators into plain `BridgeRuntime`.
- The startup orchestrator constructs `BridgeRuntimeRunner` with the four direct
  already-built constructor arguments, invokes it, and retains surrounding
  shutdown/finally ownership. Runner executes the session and maps typed
  plugin/restart/supervised outcomes only; no wrapper/context is introduced.
- No Layer-5 peer is injected as a child of another. Startup orchestration ends
  at handoff/teardown; the existing `Orchestrator` remains the single
  relay/plugin/session-control surface during the live session.

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
  cancels deadline timers in every path;
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
- `TokenService` keeps the legacy class's token file re-read/save/publish and
  single-flight behavior, but sends actual refresh transport through this
  repository with the caller signal. For `canCancel == true`, a token in the
  existing background-refresh TTL band is refreshed synchronously instead of
  spawning detached work; `AuthRequestCancellationSignal.never` preserves current
  background behavior for existing callers;
- `TokenService`, as token-state owner, maps missing/empty/cleared/corrupt local
  token state and unsafe persistence failure to typed unavailable without moving
  file decisions into `AuthRepository`;
- onboarding's freshly constructed token service has no other consumers before the
  checkpoint. Its cancellable refresh therefore exclusively owns the active
  request; skip cancels it and service completion waits for the abort to settle
  before plugin/registration consumers are composed;
- `ControlChannelTokenService` checks pre-cancellation, races its correlated
  response with `whenCancelled`, and removes the pending id. Caller cancellation
  throws `TokenAccessFailureKind.cancelled`; control transport disconnection and
  request timeout throw `transient`; signed-out/null-token responses and calls
  after disposal throw `unavailable`. Late GUI replies remain ignored.
  `ControlTokenUnavailableException` is removed, and supervised bootstrap maps
  both typed transient/unavailable failures to its existing `authRequired` exit
  behavior. Supervised onboarding remains gated out.

`TokenStorage` ownership:

- absorbs existing `loadTokens`, `saveTokens`, `clearTokens`, and
  `readLegacyBridgeId` file/process logic from `token.dart` behind required
  `read`, `write`, `clear`, and `readLegacyBridgeId` methods;
- preserves token path, JSON, `lastProvider`, missing/corrupt behavior, Unix
  directory/file permissions, Windows behavior, and the existing legacy
  compatibility marker/cleanup;
- is one concrete instance per command/run, injected directly into
  `BridgeRuntimeAuthService`, `TokenService`, `BridgeIdMigrationService`, and
  `BridgeLogoutRunner`/logout registration composition;
- removes `loadTokens`/`saveTokens`/`clearTokens`/legacy-reader callbacks from
  touched constructors and tests. Tests fake/implement the concrete Dart class
  directly rather than introducing a one-to-one interface.
- `LogoutCommand` performs local migration/token/id reads during composition,
  creates a command-owned nullable `BridgeRegistrationService` only when usable
  credentials/registration exist, and injects that collaborator directly into
  `BridgeLogoutRunner`. The runner calls `unregister()` best-effort before
  clearing storage; no `unregisterBridge` callback remains. Command-owned token/
  registration services and HTTP client are disposed in `finally`.

### Terminal ownership

- `TerminalPromptApi` accepts only `Stdin`/`Stdout`, exposes their raw terminal
  facts, capabilities, width, and I/O, and has no environment or legacy-relaunch
  branch.
- `BridgeStartupOrchestrator` resolves `TerminalInteractionMode.legacyPostUpdate` from
  the existing environment marker; otherwise it resolves `interactive` only
  when both raw terminal handles are attached, else `unavailable`. It injects
  that mode into `TerminalPromptRepository` and uses the same local mode to gate
  onboarding.
- `LogoutCommand` independently resolves `interactive`/`unavailable` from raw
  terminal handles, injects it, and disposes `TerminalPromptApi` in `finally`.
- `TerminalPromptApi` does not subscribe to stdin in its constructor. The first
  standalone prompt/read starts one lazy decoded-line subscription and fans
  completed lines through a process-lifetime internal broadcast source.
- Sequential prompt methods await the next line from that owner. The onboarding
  decision method uses a cancellable stream subscription so detection can stop
  consuming before later prompts.
- Only one prompt is active by runner sequencing; add guards/tests against
  overlapping consumers rather than a speculative queue of competing prompts.
- Password reads set echo off immediately before awaiting and restore the prior
  value in `finally` on value, EOF, error, or disposal.
- EOF closes the line source and maps to existing clear provider/credential
  failures or onboarding fail-open.
- `dispose` cancels the underlying subscription/controller exactly once and is
  registered with `BridgeShutdownCoordinator`.
- Supervised mode reads its off-argv control secret before any terminal prompt
  subscribes; onboarding is gated out. Preserve `ControlSecretApi` and do not
  route the bearer secret through a user-prompt broadcast.

### Formatter contract

- One URL constant is passed to QR encoding and plain output; tests compare
  exact bytes so they cannot drift.
- Use the pinned/audited `qr` API with a fixed error-correction level; never
  implement QR encoding manually.
- Add four light modules on every edge.
- Prefer ANSI+Unicode compact half blocks with explicit black/white foreground/
  background and final reset; then non-ANSI Unicode; then ASCII `##`/spaces.
- Use existing glyph/color validators and a safely-read nullable terminal width.
- Compute full width including quiet zone before rendering. Unknown/throwing/
  insufficient width returns no QR string, not a truncated code.
- Formatting failure is isolated to URL-only output and one warning; it never
  skips the registration wait or crashes startup.

### Onboarding service state machine

1. Subscribe to typed terminal outcomes before the immediate request so skip is
   available during initial network failure. Create one
   `AuthRequestCancellationController`; pass its signal to every token/status operation.
2. Immediate check:
   - service obtains
     `TokenRefresher.getAccessToken(cancelled: controller.signal)` and passes the
     value/same signal to the repository;
   - `TokenAccessFailureKind.transient` follows the same one-warning/
     fixed-60-second policy; `unavailable` fails open because interactive auth
     already completed; `cancelled` is expected skip/EOF with no error warning;
   - first unauthorized -> service calls
     `getAccessToken(forceRefresh: true, cancelled: controller.signal)` and
     retries once immediately;
   - unauthorized after that retry -> warn once and fail open;
   - registered -> finish silently;
   - absent -> print full onboarding once and enter long poll;
   - unavailable -> warn once and fail open;
   - transient -> warn once, race skip with fixed 60-second delay, then repeat
     immediate check without falsely showing QR;
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
-> BridgeStartupOrchestrator composes shared SesoriAuthApi + repositories from its owned http.Client
-> supervised control bootstrap OR standalone auth through migrated repositories
-> compose one access-token provider/refresher (standalone TokenService or control service)
-> authenticated-user output
-> resolve descriptor + quick checkAvailability
-> resolve TerminalInteractionMode at composition from raw handles + legacy marker
-> if standalone and mode == interactive: onboarding service
-> startup mutex / single-live-bridge decision / provision / plugin start
-> reuse same token provider/refresher for registration, relay, runtime
-> create existing session Orchestrator + BridgeRuntime
-> directly inject BridgeRuntime + failure latch + restart service + supervised flag
-> run BridgeRuntimeRunner (no construction)
-> BridgeStartupOrchestrator owns final shutdown/disposal
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
or plugin contract changes. Skip and waiter state is memory-only.

`SesoriAuthApi` consolidation is source-internal. Existing email, OAuth,
profile/validation, refresh, bridge registration/deletion HTTP request shapes,
status handling, DTOs, timeouts, and user-visible errors remain regression
contracts. The PR deletes old APIs/helpers only after all callers and tests use
the consolidated API through repositories; no deprecated forwarding alias is
shipped. The required auth cancellation parameter is internal bridge source
compatibility, and every production/test implementation and caller lands in the
same PR.

The existing `v1.3.0` legacy bridge-id compatibility marker moves immediately
with `readLegacyBridgeId` from `token.dart` to `TokenStorage`; preserve its
original date/version/rationale and update only the exact mechanical cleanup to
name `TokenStorage` plus `BridgeIdMigrationService`. Do not duplicate the marker
or leave a forwarding top-level reader.

## 7. Generated-Code and Dependency Work

1. Add the audited pure-Dart `qr` constraint to `bridge/app/pubspec.yaml`.
2. Run `dart pub get` from `bridge/`; inspect `bridge/pubspec.lock` for only
   expected dependency resolution.
3. Define required non-null `AppClientPresenceResponse.registered` in source.
4. Run `make codegen` from `bridge/`.
5. Review generated response files; never hand-edit `*.freezed.dart` or
   `*.g.dart`.
6. No Drift table, schema version, migration, snapshot, or migration test.

## 8. Verification

### Automated tests

#### API

- One `SesoriAuthApi` owns base URL/client and every migrated method; no
  `LoginEmailApi`, `LoginOAuthApi`, `BridgeRegistrationApi`, profile/validate
  HTTP function, or token-manager inline HTTP remains.
- Preserve email login, OAuth init/status/ACK, `/auth/me`, refresh, bridge
  register/delete request/response/status fixtures byte-for-byte.
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

- `TokenStorage` preserves read/write/clear, JSON/provider validation, missing
  path, permissions, and legacy bridge-id compatibility behavior; auth service,
  token service, migration, and logout tests inject it directly with no
  load/save/clear callback getters.
- `AuthRequestCancellationSignal.never` never cancels; controller cancel is synchronous,
  idempotent, and completes `whenCancelled` once.
- Every production `TokenRefresher` caller passes a required signal; existing
  flows pass `never` and retain behavior. Every fake compiles with the signature.
- `TokenService` refresh success retains storage re-read, persistence,
  publication, and single-flight behavior over `AuthRepository` and direct
  `TokenStorage`.
- A cancellable near-expiry call awaits refresh and can abort it with no detached
  work; an `AuthRequestCancellationSignal.never` near-expiry call preserves shipped
  background-refresh/return-current behavior.
- Token refresh HTTP 408/429/5xx, socket/client/deadline map to typed transient;
  local missing/corrupt/revoked/4xx/malformed map unavailable; caller abort maps
  cancelled, all without parsing messages.
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
  explicit missing/revoked/corrupt token-authority failures fail open once.
- Initial registered: no onboarding, warning, or success output.
- Initial absent: instructions/QR-or-fallback/URL output exactly once in order.
- Exact URL is both QR payload and plain line.
- Registration after prompt: one success and continuation.
- `s`, `S`, `skip`, surrounding whitespace accepted; other lines reprint help.
- Skip during immediate request, long poll, and 60-second delay aborts promptly.
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

- Lazy single subscription and deterministic dispose.
- Sequential async reads hand off after onboarding subscription cancellation.
- Raw API terminal facts contain no product policy; startup orchestrator/repository
  `TerminalInteractionMode` preserves interactivity and legacy post-update
  behavior.
- Provider choices 1-4, invalid retry, and EOF guidance unchanged.
- Email/password values and password echo restoration on success/EOF/error.
- Replacement yes/yes alias/default decline/noninteractive unchanged.
- Logout prompt/result behavior unchanged.
- Supervised `ControlSecretApi` still reads the first off-argv line without a
  competing prompt subscriber.

#### Formatter

- QR module orientation/payload for exact URL and chosen correction level.
- Four-module quiet zone on all edges.
- ANSI+Unicode output and final reset; no ANSI when disallowed.
- Unicode and ASCII fallback dimensions/content.
- Exact-fit width renders; one-column-too-narrow and unknown/throwing width omit.
- URL-only output remains exact and scan instructions mention same account.
- Deterministic snapshots contain no terminal-dependent global reads.

#### Startup orchestrator, direct runner injection, and regression

- Standalone interactive runs after plugin availability and before plugin start.
- Initial registered path is silent.
- Supervised and noninteractive paths never call status API or formatter.
- Plugin unavailable exits before status check.
- Startup mutex/provision/plugin starter are not entered until onboarding settles.
- One early standalone `TokenService` is reused for onboarding, registration,
  relay/runtime and disposed once.
- `BridgeStartupOrchestrator` constructs one `SesoriAuthApi` over its shared
  client, injects all auth repositories/services, and leaves no superseded
  use-case API constructor.
- `_buildRegistrationService` receives the composed `SesoriAuthApi` instead of
  auth URL/client pass-through parameters and is owned by startup orchestration.
  Logout constructs one local
  `http.Client` + `SesoriAuthApi` + `AuthRepository`, injects both registration
  and token services, and closes only that command-owned client in `finally`.
- `BridgeRuntimeAuthService` lives in root services, receives no
  `BridgeCliOptions`, and imports no runtime/server higher-layer type.
- Existing session `Orchestrator` is created only after plugin start.
- Delete static `BridgeRuntime.create`; tests prove the existing generative
  `BridgeRuntime` constructor receives the exact already-built session/
  repositories used by debug/runtime consumers.
- `BridgeRuntimeRunner` receives exactly the four direct declared constructor
  arguments, constructs no lower-layer class, and preserves session/exit/failure
  behavior.
- `runBridgeApp` lives only in root startup-orchestrator source; import tests
  prove runner has no startup-orchestrator import/cycle.
- `BridgeStartupOrchestrator` retains shutdown/finally ownership around runner
  execution and cleans partially prepared phases.
- Success, skip, and fail-open continue normal plugin/registration startup.
- Existing provider/email/OAuth, replacement, logout, plugin startup, bridge
  registration, and shutdown tests pass.

### Manual verification

Execute S01-W02-M01 after an auth deployment and bridge build are available.
Automated tests are authoritative for exact 60-second timing and rare races;
manual work focuses on real terminal/camera behavior and user-visible flow.

### Exact commands

```text
# workdir: bridge
dart pub get
make codegen
make analyze
make test

# workdir: bridge/app
dart analyze --fatal-infos
make build-host
```

If `dart pub get` or code generation changes unrelated modules, stop and explain
the resolution conflict rather than committing broad generated/lock churn.

### Regression guide

- Start with valid stored OAuth and email credentials; profile output and later
  registration still use the same refreshed token.
- Exercise replacement and logout after onboarding has completed to prove later
  prompts receive lines and password/terminal modes are normal.
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
- Starting the stdin broadcast in the constructor could steal supervised secret;
  require lazy first-prompt subscription and mode tests.
- Moving/renaming the legacy token owner could create duplicate refresh
  authorities; compose one `TokenService` instance early and reuse current later
  variables.
- Consolidating existing auth HTTP could create a broad behavior regression;
  preserve every old request fixture/status mapping and delete wrappers only
  after repositories/services and logout composition are migrated.
- A cancellable refresh shared with another consumer could cancel unrelated
  work; startup sequencing gives onboarding exclusive `TokenService` use until it
  settles, and existing later callers pass `AuthRequestCancellationSignal.never`.
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
- Runner injection could grow into a service locator; keep exactly the four
  direct declared arguments and reject wrapper contexts, maps, generic getters,
  factories, URLs, clients, callbacks, or lower-layer construction parameters.
- Moving startup composition could duplicate Layer-5 ownership; startup
  orchestrator owns only pre-plugin composition/handoff/teardown, while the
  existing `Orchestrator` remains the single live session-control surface.

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
- `TokenStorage` is injected directly into `TokenService`, runtime auth,
  migration, and logout; touched constructors have no token load/save/clear
  callbacks, and the forbidden `TokenManager` name/file is gone.
- `BridgeLogoutRunner` receives nullable `BridgeRegistrationService` directly;
  logout composition/tests contain no unregister callback forwarding boundary.
- Terminal API/repository/Foundation files live at root layer paths, and the root
  onboarding service has no dependency on `server/`.
- Root `BridgeRuntimeAuthService` has no runtime-options dependency;
  `BridgeStartupOrchestrator` is the sole startup composer and runner consumes
  only the four direct already-built collaborators with no lower-layer
  construction.
- Existing prompts and supervised secret remain correct under one async stdin
  owner.
- No plugin/startup lock is held while waiting; no lifecycle resource leaks.
- Generated/lock output is tool-produced and scoped; all commands pass.
- No analytics, config, persistence, browser, shared, plugin, relay, mobile, or
  desktop changes are included.

## 11. Definition of Done

- Scope, tests, generated output, dependency lock, manual guide, compatibility
  marker, and regression evidence are complete on the pinned `main` baseline.
- Architecture-bearing implementation receives the worker's configured
  implementation review before PR opening.
- Only intended monorepo files are committed; branch is pushed and PR targets
  `main`.
- `TRACKER.md` records S01/W02 baseline, branch, PR URL, checked state, and any
  findings. The advisory manual row remains independently checkable.
- Auth endpoint is deployed before the bridge release is initiated.
