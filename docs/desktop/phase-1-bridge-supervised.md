# Phase 1 — Bridge Supervised Mode

> Goal: teach the existing `sesori-bridge` a **supervised mode** (gated by
> `--control-url` + an off-argv secret) where the GUI is its token authority and
> lifecycle owner. **Every PR is additive and gated** so the standalone CLI is
> provably unchanged and the relay protocol is untouched (release-safety
> invariant #1). All PRs target the bridge workspace and can proceed in parallel
> with Phase 0/2 prep.

**Per-PR template:** Goal · Scope · Risk · Review-size · **Regression guide** ·
Acceptance · DoD (incl. PLAN.md §9 row + pointer advanced) · Aristotle verdicts ·
Findings log · Plan-deltas.

> **Regression guide** = the blast radius of the PR: which existing behaviours
> could break, and the quick checks that prove they didn't. Required on every
> not-yet-merged PR; re-verify it before opening the PR and extend it when the
> implementation touches more than planned. (Merged PRs 1.1–1.6 are not
> retrofitted; their Findings logs already record what was verified.)

**Standing acceptance (all Phase 1 PRs):** standalone behaviour byte-identical
(asserted by test) · relay protocol untouched · `--control-url` absent ⇒ exact
current behaviour.

> **Exception — PR 1.14** deliberately changes standalone behaviour for the
> relay replaced-close (today's behaviour is an unbounded reconnect war — ADR
> A22), and adds one **additive** shared constant (`RelayCloseCodes.bridgeReplaced
> = 4007`, deployed relay-side first) — so like PR 1.2 it also requires shared
> tests + a `client/app` compatibility check. Everything else stays
> byte-identical.

> **Exception — PR 1.2** writes shared wire DTOs into `sesori_shared`, which is
> consumed by **both** the bridge and the mobile/client. That PR additionally
> requires shared codegen/tests to pass **and** a `client/app` (mobile product)
> compatibility check — the bridge-only gate is not sufficient for it.

**Rebase note:** main #322 added `_ensurePluginRuntime` + foundation imports to
`bridge_runtime_runner.dart`; supervised wiring layers on top. `ensureRuntime`
runs **under the startup mutex**, which reinforces PR 1.12.

---

## PR 1.1 — `--control-url` + control-secret bootstrap + `ControlChannelClient` skeleton
- **Goal:** Add supervised-mode detection via `--control-url`; receive the
  per-spawn **secret off-argv** (inherited FD/pipe or stdin handshake — NOT a
  `--control-secret` flag, per ADR A8). Add `ControlChannelClient` (Layer 0
  target `foundation/` layer — NOT the legacy nested `bridge/foundation/` tree;
  `web_socket_channel`) that connects/reconnects to the GUI; no message
  semantics yet.
- **Scope notes (implementation):**
  - Do **not** enforce strict parse-time validation on the supervised-only
    option; validate/trim only when supervised mode is active (avoids false
    fails in standalone).
  - **Completer hygiene:** don't leave temporary `Completer`s armed after a
    handshake completes/parks; null them out so a later `completeError` can't
    raise an uncaught zone error.
  - **Parent-loss policy (ADR A9):** if the control channel is lost (GUI crash/
    force-quit), the helper exits after a short grace period rather than
    lingering with a live token.
- **Risk:** Low-Med. **Size:** M.
- **Acceptance:** standalone unchanged; with supervised bootstrap the client
  connects to a fake server in tests; reconnect on drop; the secret never
  appears in `ps`/argv; control-channel loss triggers grace-period exit.
- **Aristotle:** plan ☑ · impl ☑ (merged #334).
- **Findings:** Shipped as three gated units + the `--control-url` option.
  `ControlChannelClient` (Layer 0 `foundation/`) owns connect + its own
  exp-backoff auto-reconnect (the GUI may come/go while the bridge stays up, so
  unlike `RelayClient` the reconnect loop lives in the client, not a consumer),
  a raw `inbound` text stream, `send`, and a `connectionState` stream. The
  per-spawn secret is read as the first stdin line (`ControlSecretApi`) and
  presented to the GUI as an `Authorization: Bearer` header on the WS **upgrade
  request** — transport-level auth, off-argv, and independent of the PR-1.2 wire
  DTOs. Parent-loss exit (ADR A9) is a separate `ControlChannelLossListener`
  with an injected `exitProcess` (root passes `io.exit`), grace 5s, exit code
  `1`. A real drop emits `disconnected` (arms grace); a clean `dispose` closes
  the state stream `done` (no grace) so shutdown never self-exits. Standalone is
  byte-identical (everything behind `isSupervised`). `make analyze` clean;
  `make test` 1504 pass.
- **Review round 2:** addressed reviewer feedback — enforce loopback ws/wss on
  `--control-url` before dialing (fail closed, don't leak the bearer secret);
  subscribe the loss listener *before* `connect()` (don't miss the first
  `disconnected`); post-handshake liveness guard in `_openChannel`; isolate
  teardown steps + handle `cancel()` errors. **Control-loss exit is graceful:**
  it routes through `shutdownCoordinator.shutdown()` (ordered plugin stop) before
  `io.exit`, so a hard exit from the loss timer can't orphan an owned runtime.
  The supervised `spawnSuccessor()` flag-replay gap is tracked to **PR 1.7**.
- **Deltas:** §6 placed only `ControlChannelClient` (foundation, kept). Two
  components plan-review pinned to specific layers were NOT pre-specified in §6
  and are now added there: the off-argv secret reader is a **Layer-1
   `ControlSecretApi`** in `api/` (mirrors `TerminalPromptApi`; a stdin reader is
   data access, not a foundation primitive — `Reader` is not a sanctioned
   suffix), and the ADR-A9 grace-exit is a **`ControlChannelLossListener` in a
   new Layer-4 `control/` dir** (a decision-making `Listener` cannot live in
   Layer-0 `foundation/`, and `control/` is part of the core layered bridge app,
   not a self-contained subsystem). Parent-loss exit code is provisionally `1`
  (`controlChannelLostExitCode`); the GUI-side exit-code state machine (PR
  2.7 / 1.7) may refine it.

## PR 1.2 — Control-protocol Freezed DTOs (incl. provision-progress mirror)
- **Goal:** Define wire DTOs in `shared/sesori_shared`: `token_request`,
  `token_response`, `token_update`, `status`, `prompt_request`/`prompt_response`,
  `restart`, `unregister_and_exit`, a **`registered` event carrying the
  `bridgeId`** (so the GUI can persist a readable copy for the offline-unregister
  fallback, ADR A13), and **provision-progress** variants mirroring
  `RuntimeProvisionProgress` (resolving/downloading{received,total}/extracting/
  verifying/notice/ready/failed). Pure data + (de)serialization + tests.
  Optional/new fields use Freezed `@Default` (not throw/catch) for forward/back
  compatibility across protocol versions.
- **Risk:** Low. **Size:** S-M.
- **Acceptance (note — `sesori_shared` is consumed by mobile too, so this PR is
  the exception to the "Phase 1 = bridge only" standing text):** round-trip
  serialization tests; no logic in shared; **`sesori_shared` codegen + tests
  pass AND `client/app` (mobile product) still builds** (no consumer break).
- **Aristotle:** plan ☑ · impl ☑ (merged #335).
- **Findings:** Shipped as two pure-data Freezed sealed unions in
  `shared/sesori_shared/lib/src/protocol/` (alongside `messages.dart`/`RelayMessage`,
  the precedent), not under `models/` — these are protocol wire types.
  `ControlMessage` is a single bidirectional union keyed by `type`
  (`unionValueCase: snake`) with 10 variants: `token_request`/`token_response`
  (id-correlated; null `accessToken` ⇒ GUI couldn't supply), `token_update`
  (push), `status`, `prompt_request`/`prompt_response` (id-correlated),
  `restart` (intentional-restart heads-up), `unregister_and_exit`, `registered`
  (carries `bridgeId`, ADR A13), and `provision_progress` (wraps the nested
  union). `ControlProvisionProgress` is a separate union mirroring
  `RuntimeProvisionProgress` 1:1 (resolving/downloading/extracting/verifying/
  notice/ready/failed) — the source lives in `sesori_plugin_interface` and MUST
  NOT be imported (dependency direction), so it is mirrored; the derived
  `fraction` getter is intentionally dropped (pure data). Forward-compat: three
  enums (`ControlRelayConnectionState`/`ControlPluginHealthState`/
  `ControlPromptKind`) each carry an `unknown` `@JsonValue` fallback +
  `@JsonKey(unknownEnumValue:)`; optional fields use `@Default`; null keys auto-
  drop (build.yaml `include_if_null:false`). No catch-all message-type variant
  (matches `RelayMessage`; GUI+helper are same-commit, ADR/§2). 25 round-trip/
  discriminator/fallback tests; `sesori_shared` 265 tests + analyze clean;
  `client/app` (mobile) `flutter analyze` clean (additive, no consumer break).
- **Deltas:** §6 listed only "Control-protocol Freezed DTOs | `shared/sesori_shared`".
  Concretely realized as two unions in `lib/src/protocol/` (not `models/`),
  matching `RelayMessage`'s home. Status/prompt field shapes (the three enums +
  `activeSessionCount`) are introduced here; their senders (PRs 1.9/1.10/1.12)
  may extend them **additively** via `@Default` fields / new enum values.

## PR 1.3 — Supervised auth bootstrap
- **Goal:** In supervised mode, short-circuit
  `BridgeRuntimeAuthService.ensureAuthenticated`/`promptForProvider` (no
  interactive **auth/prompt** input); obtain the initial token from the control
  channel; keep an equivalent `logAuthenticatedUser` after the token arrives.
- **Risk:** Med (auth path). **Size:** M.
- **Acceptance:** supervised start performs **no interactive auth/prompt stdin
  reads** (this is distinct from PR 1.1's optional one-shot secret-bootstrap
  stdin handshake, which is not an auth prompt); standalone interactive flow
  untouched.
- **Aristotle:** plan ☑ · impl ☑ (merged #341).
- **Findings:** Shipped `ControlChannelTokenService` in `control/` (beside
  `ControlChannelLossListener`), NOT `auth/`: the service depends on the Layer-0
  `ControlChannelClient`, and `auth/` is a self-contained subsystem that must not
  depend on core `foundation/`. It owns the token request/response round-trip —
  sends an id-correlated `ControlMessage.tokenRequest` (monotonic id), subscribes
  to `ControlChannelClient.inbound`, decodes each frame to `ControlMessage`, and
  completes the matching pending request on `tokenResponse`. A null `accessToken`
  (GUI signed-out/mid-login) or a request timeout yields a typed
  `ControlTokenUnavailableException` — not logged at the throw (the `run()` catch
  surfaces it once, no double-log); undecodable/forward-compat frames are warned
  and skipped, other variants ignored. `dispose()` cancels the inbound
  subscription and fails any in-flight request so shutdown can't hang on the
  timeout. Composition: `_startSupervisedControlChannel` is renamed
  `_connectSupervisedControlChannel` and now returns the connected client; the
  runner builds the token service from that same client (shared with the loss
  listener) and registers its dispose. The auth bootstrap branches — supervised ⇒
  `requestToken()`, standalone ⇒ unchanged `ensureAuthenticated()` — and
  `logAuthenticatedUser` runs identically on both paths. `BridgeRuntimeAuthService`
  is unchanged, so standalone is byte-identical (its existing tests stay green);
  `dart analyze --fatal-infos` clean; 1517 app tests pass (7 new for the service).
- **Deltas:** §6 / the PR-1.4 line place this class in `auth/` (Layer 3); plan
  review re-homed it to `control/` for this PR because `auth/` cannot depend on
  the Layer-0 `ControlChannelClient`. When PR 1.4 makes the class implement the
  `auth/` interfaces (`AccessTokenProvider`/`TokenRefresher`), it must resolve the
  resulting `control/`→`auth/` direction (an auth-side adapter, or an auth-local
  transport abstraction). PR 1.3 handles only the token request/response
  correlation; `token_update` push, the provider/refresher interfaces,
  force-refresh policy, and richer GUI-down/mid-login wait semantics remain PR
  1.4 (the initial pull is a one-shot request with a 30s timeout). Downstream
  `TokenManager` still seeds from the resolved access token on both paths;
  supervised registration/refresh rework is deferred to PRs 1.4/1.5/1.6 and isn't
  reached pre-GUI (Phase 2).

## PR 1.4 — Token provider **pull** over channel
- **Goal:** `ControlChannelTokenService` (Layer 3 `services/`) implements
  `AccessTokenProvider`/`TokenRefresher`; `getAccessToken({forceRefresh})`
  requests a token over the channel and blocks with a timeout; define behaviour
  when the GUI is mid-login/down. Client injected from composition root (no
  internal `new`). It implements interfaces from `auth/` but does not live inside
  the self-contained `auth/` subsystem, so `auth/` does not import core
  `foundation/` transport.
- **Risk:** Med. **Size:** M.
- **Acceptance:** force-refresh requests a fresh token; timeout + GUI-down paths
  yield a typed failure (logged once at the surfacing point, not double-logged).
- **Aristotle:** plan ☑ · impl ☑ (merged #345).
- **Findings:** Promoted `ControlChannelTokenService` from `control/` (Layer 4) to
  `services/` (Layer 3) — the placement the PR-1.4 goal specifies. It now
  `implements AccessTokenProvider, TokenRefresher` while living in `services/`, so
  `auth/` gains no dependency on core `foundation/` transport (resolving the
  PR-1.3 `control/`→`auth/` delta). The Layer-3 service's direct dependency on the
  Layer-0 `ControlChannelClient` is the AGENTS.md-blessed "control-channel token
  service over `ControlChannelClient`" seam. PR-1.3's `requestToken` became the
  interface's `getAccessToken({forceRefresh})`: it forwards `forceRefresh` to the
  GUI, blocks on the id-correlated reply with a constructor-configurable timeout
  (default 30s), and caches each pulled token in a `BehaviorSubject` so the
  synchronous `accessToken` getter and `tokenStream` stay current. Null token
  (signed out / mid-login) and timeout still throw the typed
  `ControlTokenUnavailableException` (not logged at the throw; the caller logs
  once); `accessToken` throws `StateError` before the first successful pull (the
  composition root awaits the bootstrap pull before exposing the provider);
  `dispose` now also closes the subject. Composition: in supervised mode the
  runner selects the control-channel service as the `accessTokenProvider` +
  `tokenRefresher` (and the registration refresher) and skips constructing
  `TokenManager` — the GUI is the sole token authority; standalone constructs and
  uses `TokenManager` exactly as before (byte-identical, existing auth/runtime
  tests stay green). Two implementors of the auth interfaces now coexist by design
  (`TokenManager` in `auth/` for the standalone refresh-token flow,
  `ControlChannelTokenService` in `services/` for the supervised GUI pull); the
  composition root picks by `options.isSupervised` — a strategy seam.
  `dart analyze --fatal-infos` clean; `make analyze` clean; 1522 app tests pass
  (13 in the moved service test).
- **Deltas:** Earlier text placed this class in `auth/` (Layer 3); the merged plan
  now specifies `services/`, which this PR implements — so `auth/` never imports
  `foundation/` transport. PR 1.4 wires the supervised provider/refresher but adds
  **no** `token_update` push handling and **no** `RelayClient` `tokenStream`
  consumption, so the supervised provider path is exercised only by unit tests
  pre-GUI (Phase 2); pushed `token_update` → live relay re-auth remains PR 1.5 and
  supervised registration + `bridgeId`-out-of-`token.json` remains PR 1.6. "Richer
  mid-login wait" is bounded by the one-reply `token_response` DTO: a mid-login GUI
  replies with a null token (typed failure); genuine wait-for-login-completion
  arrives with the `token_update` push in PR 1.5. Two review-driven edges are
  deferred to and now enumerated in **PR 1.5's scope**: (a) the `token_update`
  push must become the authoritative cache source, retiring this PR's interim
  pull-ordering heuristic so a forced refresh isn't masked by a later non-forced
  pull; and (b) a relay reconnect after a null `token_response` (sign-out) must
  not reuse the stale cached token.

## PR 1.5 — Token-stream **push** → relay re-auth
- **Goal:** Make a GUI-pushed `token_update` actually re-authenticate the live
  relay connection. Today `RelayClient` reads `accessToken` only once in
  `connect()` and `tokenStream` is otherwise unused, so merely emitting on a
  stream leaves an **open** WebSocket on the old JWT until reconnect. This PR
  wires the `RelayClient` subscription → re-auth/reconnect path so a refresh
  while connected takes effect (ADR A12).
- **Scope (carried from PR 1.4 review — MUST be addressed here):**
  - **Handle the `token_update` push.** `ControlChannelTokenService` must consume
    inbound `ControlMessage.tokenUpdate` and adopt the pushed token into its
    cached `accessToken`/`tokenStream`. This makes the GUI push the authoritative
    cache source and **retires PR 1.4's interim pull-ordering freshness heuristic**
    (`_latestCachedSeq`): once the GUI pushes, overlapping force/non-force pull
    ordering no longer decides what is cached, so a forced-refresh result can no
    longer be masked by a later non-forced pull (the deferred PR-1.4 review edge).
  - **No stale token on reconnect after sign-out.** A null `token_response`
    (signed out / mid-login) leaves PR 1.4's cache holding the previous token, and
    `RelayClient.connect` reads that snapshot on reconnect. Subscribing to
    `tokenStream` is **not** sufficient for this case: it is a `BehaviorSubject`
    that replays the last (stale) value, and `token_update` is non-null only, so it
    can never push a "no token" / sign-out signal. The reconnect path must
    therefore obtain a **fresh** token by pulling on reconnect, **and/or** the
    cache must be invalidated on a null `token_response` — these are required, not
    interchangeable with a stream subscription — so the relay never
    re-authenticates as a signed-out user. (`tokenStream` subscription remains the
    mechanism for the *live* re-auth case — adopting a `token_update` while
    connected — which is separate. A hard logout is the `unregister_and_exit` path
    in PR 1.11.)
- **Risk:** Med (silent-auth-failure if wrong). **Size:** M.
- **Acceptance:** with a **live** relay connection (not just stream
  propagation), a pushed token update re-authenticates without losing the
  session; covered by a connection-level test. A `token_update` push updates the
  shared cache regardless of any in-flight pull ordering. After a null
  `token_response` (signed out / mid-login), a relay reconnect does **not**
  re-authenticate from the stale cached token.
- **Aristotle:** plan ☑ · impl ☑ (merged #347). **Findings:** Live re-auth subscription lives
  in the Orchestrator (it already owns the relay reconnect/backoff loop and the
  `CompositeSubscription`); `RelayClient` stays a dumb transport. The
  `token_update→re-auth` path funnels into the **same** reconnect block the
  relay-drop path uses (drop the relay → existing reconnect block force-pulls the
  new token and reconnects) — symmetric triggers, no Dispatcher needed.
  Sign-out handling is split by ownership: `ControlChannelTokenService`
  invalidates its own cache on a null `token_response` (the sync `accessToken`
  getter throws again, since a `BehaviorSubject` cannot un-emit), and the
  Orchestrator gates reconnect on a successful force-pull (a signed-out pull
  defers reconnect on backoff instead of re-authing from the stale token). The
  `_latestCachedSeq` pull-ordering heuristic is retired: the GUI `token_update`
  push is the authoritative cache writer (last-write-wins); a pull only seeds the
  cache for bootstrap, so the deferred PR-1.4 force/non-force masking edge is
  gone. **Deltas:** post-merge fix — the original trigger re-authed on any token
  *string* change, which dropped the relay (and every phone) on each routine
  same-user rotation: standalone `TokenManager` emits every refresh, so a
  near-expiry pull (e.g. session-metadata generation) flapped the connection and
  spammed SSE send failures. The relay validates the JWT once at connect and
  never re-checks it, so the gate is now **identity-based**: re-auth only when
  the `userId` claim differs from the token the socket authed with (or the
  identity can't be parsed — conservative fallback). Manual check 4's "relay
  session survives; no reconnect loop" on a same-user push is the authoritative
  expectation; a cross-user push still drops and re-authenticates.

## PR 1.6 — Supervised registration + `bridgeId` out of `token.json`
- **Goal:** Persist `bridgeId` separately from `token.json` in a small
  file-backed storage that lives **inside the `auth/` subsystem** (NOT new
  top-level `api/`+`repositories/` classes — that would make `auth/` depend back
  on the core repository layer; see ADR A6). Supervised registration uses the
  supplied token. Use **synchronous** filesystem checks (`existsSync`) for the
  `avoid_slow_async_io` lint.
- **Risk:** Med (touches `TokenData` persistence). **Size:** M.
- **Acceptance:** supervised registers + persists bridgeId; standalone token.json
  path unchanged (only the `bridgeId` field is removed).
- **Aristotle:** plan ☑ · impl ☑ (merged #352). **Findings:** impl-review (3 rounds): (1)
  `readLegacyBridgeId()` initially swallowed `FileSystemException`/`FormatException`
  silently — now logs via `Log.w(message, error)` and treats `PathNotFoundException`
  as the expected no-legacy path; (2) `BridgeIdStorage.write` used a positional
  arg — made named `required`; (3) `FakeBridgeIdStorage` test fake used a
  positional constructor param — made named. **Deltas:** since `bridgeId` now
  owns its own file, the cross-writer races between token refresh and
  registration disappear, so the carry-over re-read gymnastics in
  `TokenManager._doRefresh`, `BridgeRuntimeAuthService._loginAndPersist`, and
  `BridgeRegistrationService._persistBridgeId` were **deleted** rather than
  ported. Legacy standalone users keep their id via one-time adoption from
  `token.json` (read once when the new file is absent), implemented as an
  injected `readLegacyBridgeId` seam so `auth/` never learns about `token.json`
  internals from the service side.

## PR 1.7 — Exit-code restart (`86`) + bypass successor-spawn
- **Goal:** In supervised mode `handleRestartHandoff()` flushes the
  `{restarting:true}` response then `exit(86)` instead of
  `BridgeRestartService.spawnSuccessor()`. Name the exact bypass call site.
  **Closes the PR-1.1 interim gap:** until this lands, a supervised
  `spawnSuccessor()` replays `--control-url` into the detached successor with no
  off-argv secret on stdin, so the successor fails in `ControlSecretApi` instead
  of reconnecting. Not reachable by any shipping path pre-GUI (Phase 2), but
  this PR must ensure supervised restart never calls `spawnSuccessor()`.
- **Risk:** Med. **Size:** S-M.
- **Regression guide:** touches the shared restart path (`handleRestartHandoff`
  in the orchestrator + the runner seam), which standalone relies on. Check: (1)
  standalone `POST /global/restart` still spawns a successor, the phone gets
  `{restarting:true}`, and the successor takes over (existing tests +
  `orchestrator` restart tests green); (2) the response flush still happens
  BEFORE exit in supervised mode (phone must not see a dropped socket without
  the reply); (3) the single-flight `_restartHandoffStarted` guard still resets
  on failure; (4) post-update restart env handling (`sesoriPostUpdateRestartEnvVar`)
  unaffected; (5) `DebugServer` restart route drives the same path in both modes.
- **Acceptance:** phone-triggered restart → exit 86 in supervised mode; standalone
  successor handoff unchanged; **supervised mode never calls `spawnSuccessor()`**
  (closes the PR-1.1 `--control-url`-replay gap — asserted by test).
- **Aristotle:** plan ☑ · impl ☑. **Findings:** The run-mode restart strategy is
  owned by `BridgeRestartService` (which already "owns the process side of an
  explicit restart"), chosen once at the composition root via a new
  `required bool isSupervised`. New `performRestartHandoff()` branches:
  standalone → `spawnSuccessor()` (unchanged); supervised → sets a
  `supervisedRestartRequested` flag and returns true **without spawning** (a
  supervised successor would replay `--control-url` with no off-argv secret and
  fail closed). `OrchestratorSession.handleRestartHandoff()` swaps its single
  `spawnSuccessor()` call for `performRestartHandoff()`; the single-flight guard,
  `Console.error`-on-false, and graceful `cancel()` (which flushes the queued
  `{restarting:true}` reply) are unchanged and shared by both modes. The
  composition root (`bridge_runtime_runner.dart`) reads
  `restartService.supervisedRestartRequested` **after `run()` returns** — exactly
  mirroring the existing `failureLatch.failure` terminal-state read — and returns
  the new top-level `const supervisedRestartExitCode = 86`; the existing
  `finally { shutdownCoordinator.shutdown() }` still performs the ordered plugin
  stop first, so a supervised restart exits gracefully (no orphaned OpenCode
  runtime) rather than via a hard `io.exit`. The coordinator backstop also reads
  the restart code (`requestedSupervisedRestartExitCode ?? supervisedLossExitCode
  ?? …`) so a hung restart-shutdown still reports 86. No `Orchestrator` /
  `BridgeRuntime.create` signature changes (the service is pre-built in the
  runner). Tests: 4 new `BridgeRestartService` unit tests (supervised handoff
  sets the flag + never calls `startDetached`; standalone spawns + leaves the
  flag false + returns false on spawn failure); 4 existing construction sites
  updated with `isSupervised: false`; standalone debug-server restart tests stay
  green. `make analyze` clean; `make test` 1558 pass.
  **Plan-review note:** the first design used an injected `void Function()?`
  callback for the supervised signal; `aristotle-plan-review` rejected it under
  the bridge "Streams Over Callbacks" rule, so it was replaced with the
  synchronous `supervisedRestartRequested` state getter (the `failureLatch`
  precedent) before implementation. **Review round 2** (Codex, 2 P2s): (a) the
  runner only read the flag after a clean `run()` return, so a teardown throw
  after the handoff would fall to the error path and return `1` (crash) not `86` —
  now `run()` is wrapped in an inner `try/finally` that resolves the sentinel into
  the outer-scoped local even on throw, and the outer `catch` honors it; (b) the
  restart handler's `canSpawnSuccessor()` preflight checked the managed CLI path,
  which a bundled desktop helper need not have, so a supervised `/global/restart`
  would 503 and never reach the exit-86 handoff — added a mode-aware
  `BridgeRestartService.canRestart()` (supervised ⇒ always restartable, GUI
  respawns; standalone ⇒ `canSpawnSuccessor()`) and the handler now calls it.
  **Review round 3** (cubic, 1 P2): the outer `finally { shutdownCoordinator
  .shutdown() }` rethrows a failed ordered/parallel step (by design — a failed
  plugin stop must exit non-zero), which thrown from a `finally` would override
  the `86` return and re-crash an intentional restart. Now shutdown errors are
  swallowed-with-`Log.w` **only** when a supervised restart sentinel is set (the
  restart must still exit 86 so the GUI respawns); every other exit still
  rethrows to preserve the loud-failure behaviour. **Deltas:** —

## PR 1.8 — Disable self-update + reconcile when supervised
- **Goal:** Pass `SESORI_NO_UPDATE`/skip policy; assert reconcile is skipped so a
  bundled bridge never rewrites itself.
- **Risk:** Low. **Size:** S.
- **Regression guide:** touches `shouldSkipUpdates` / runner update wiring used
  by every standalone install. Check: (1) standalone managed installs still
  reconcile at startup and re-reconcile after predecessor exit; (2) the
  background update cadence still runs standalone (`updateLifecycle.start()`);
  (3) explicit `sesori-bridge update` (ManualUpdateService) still overrides the
  background suppressors; (4) npm/CI/non-managed suppression (`isNpmInstall`,
  `isCiEnvironment`, `!isManagedInstall`) unchanged.
- **Acceptance:** no update/reconcile attempt in supervised mode; standalone
  self-update intact.
- **Aristotle:** plan ☑ · impl ☑. **Findings:** Implemented as a new
  `required bool isSupervised` input to the single policy choke point
  `shouldSkipUpdates` (`updater/foundation/update_policy.dart`) — supervised
  joins the existing suppressor list (`SESORI_NO_UPDATE`, CI, npm,
  non-managed) rather than adding a separate gate, so it automatically covers
  BOTH surfaces the policy already gates: the runner's
  `updatesEnabledForThisInstall` local (which guards the startup reconcile AND
  the re-reconcile after restart-predecessor exit — one gate, both call
  sites) and `UpdateService.start()`'s background 4h cadence (constructor
  gains `required bool isSupervised`, stored and read by its
  `_shouldSkipUpdates()`). The composition root passes
  `options.isSupervised` at both wiring points
  (`_buildUpdateLifecycleService` + the reconcile gate);
  `updateLifecycle.start()` stays unconditional because the service
  self-suppresses via the shared policy, exactly like the other suppressors
  (symmetric handling). `ManualUpdateService` (explicit `sesori-bridge
  update`) is untouched by design — it never runs with `--control-url` and
  deliberately overrides background-only suppressors. No env-var plumbing was
  needed: the bridge knows `isSupervised` from `--control-url` directly, which
  is more robust than requiring the GUI to remember to set `SESORI_NO_UPDATE`
  when spawning (the GUI may still set it as belt-and-suspenders). Tests:
  policy matrix gains "supervised ⇒ skip even on a managed install";
  `update_service_test` gating group gains "supervised disables the pipeline"
  (checkCount stays 0 across an 8h fake-async window); all existing cases pass
  `isSupervised: false` unchanged (standalone matrix asserted intact).
  `make analyze` clean; `dart analyze --fatal-infos` clean; `make test`
  1611 pass. **Deltas:** —

## PR 1.9 — `BridgeControlMessageDispatcher` + prompts/Console → control events + auth-required exit `87`
- **Goal:** Three tightly-coupled pieces of the inbound/prompt seam:
  1. **Create `BridgeControlMessageDispatcher`** (Layer 4 `control/`, per §6): the
     **single** inbound subscriber/decoder for GUI→helper control messages.
     `ControlChannelTokenService` stops subscribing to `ControlChannelClient.inbound`
     directly — the dispatcher decodes each frame once and calls typed delegate
     methods on the token service (`token_response`/`token_update`); the service
     keeps its request-correlation state and its `token_request` send path. This
     resolves the otherwise-asymmetric "token service subscribes itself, other
     variants routed elsewhere" split before PR 1.11 adds more inbound handling.
     (GUI-side `ControlMessageDispatcher` already uses this exact shape — ADR A14.)
  2. **Re-home prompts/Console:** replace-bridge prompt + login-needed + essential
     `Console` output become structured control events (`prompt_request`/
     `prompt_response` correlation via the dispatcher) in supervised mode.
  3. **Auth-required exit sentinel (ADR A23):** when the bootstrap token pull
     fails because the GUI is signed out / cannot supply a token
     (`ControlTokenUnavailableException`), the supervised bridge emits a
     best-effort `loginNeeded` prompt and exits **`87`** instead of the generic
     exit `1` — so PR 2.7's state machine can distinguish "needs login" from a
     crash and not backoff-respawn-thrash. `restart` remains helper→GUI outbound
     only; the dispatcher must NOT treat it as an inbound command.
- **Risk:** Med. **Size:** M (split the dispatcher refactor into a precursor PR if
  it grows past the cap).
- **Regression guide:** re-plumbs the PR 1.3–1.5 token paths — the highest-value
  re-checks in this phase. Check: (1) token pull round-trip, force-refresh, push
  adoption, null-response cache invalidation, and dispose-fails-in-flight all
  stay green (existing `control_channel_token_service` + orchestrator re-auth
  tests must pass **unmodified in behaviour**, only re-wired); (2)
  `ControlChannelLossListener` still sees `connectionState` (its subscription is
  separate from `inbound` — don't disturb it); (3) undecodable-frame warn+skip
  behaviour preserved at the single decode point; (4) standalone `Console`
  output **byte-identical** (login URL/code, prompts — asserted by test); (5)
  supervised exit codes: token-unavailable at bootstrap = 87, control-loss = 1
  (unchanged), normal shutdown = 0.
- **Acceptance:** standalone Console output **byte-identical**; supervised emits
  structured prompt/login events; the dispatcher is the only `inbound` subscriber
  (asserted by test); bootstrap token-unavailable exits `87` after a best-effort
  `loginNeeded` prompt; PR 2.7's mapping consumes `87`.
- **Aristotle:** plan ☑ · impl ☑ (PR raised on branch `next-desktop-implementation`).
- **Findings:** Shipped as four units. (1) `BridgeControlMessageDispatcher`
  (Layer 4 `control/`): the single `inbound` subscriber; decodes each frame once
  (warn+skip on undecodable, preserved from the token service's old decode
  point) and routes via an exhaustive switch — `token_response`/`token_update` →
  token-service typed delegates, `prompt_response` → prompt-service delegate;
  every other variant (incl. `restart` and, until its route lands,
  `unregister_and_exit`) is `Log.d`-ignored, never a command. Single-subscriber
  property asserted by a listen-counting fake client. (2)
  `ControlChannelTokenService` no longer subscribes/decodes: it gained
  `handleTokenResponse`/`handleTokenUpdate` delegates; correlation map, seq
  ordering, `token_request` send path, timeout and dispose semantics unchanged —
  all 19 existing behaviour tests kept their expectations, re-wired through a
  dispatcher over the same fake client. (3) Prompts: new `ControlPromptService`
  (Layer 3 `services/`, same blessed `ControlChannelClient` seam) owns
  prompt-class correlation + sends and implements the new
  `BridgeReplacePrompt` interface (`server/foundation/`, two production impls —
  `TerminalPromptRepository` gained `implements`); `BridgeInstanceService` now
  takes `BridgeReplacePrompt replacePrompt`, so supervised replace-bridge
  questions go to the GUI (accepted→replace, rejected→decline; channel-down /
  2-min timeout / teardown → `nonInteractive`, logged — mirroring the
  terminal's "couldn't ask"). The logout CLI keeps the terminal impl (never
  supervised). (4) ADR A23: `supervisedAuthRequiredExitCode = 87` beside 86;
  the supervised bootstrap pull catches `ControlTokenUnavailableException`,
  logs once, sends a best-effort `announceLoginNeeded()` (fire-and-forget,
  swallow+log when the channel is down) and returns 87; the sentinel is wired
  into the shutdown backstop chain and the outer-finally shutdown-error guard,
  so a hung or throwing shutdown still reports 87 (same robustness 86 has).
  Composition: prompt service + dispatcher are built with the token service in
  the supervised block, dispatcher started **before** the bootstrap pull;
  `BridgeInstanceService` construction moved after that block to receive
  `controlPromptService ?? terminalPromptRepository`. Standalone byte-identical
  (no Console call-site changes; nothing supervised is constructed). `make
  analyze` + `dart analyze --fatal-infos` clean; `make test` all pass (app
  1627; +16 new dispatcher/prompt tests).
- **Deltas:** §6 gained two rows that PR planning had not pre-specified as
  components: `ControlPromptService` (Layer 3 `services/`) as the owner of the
  prompt correlation the PR text placed only vaguely "via the dispatcher", and
  the `BridgeReplacePrompt` interface (`server/foundation/`) that lets
  `BridgeInstanceService` stay inside the self-contained `server/` subsystem
  (PR-1.4 auth-interface precedent). "Essential `Console` output" re-homing was
  realized as the prompt-class events only: the PR-1.2 DTO surface deliberately
  has no generic console/log variant (status is health/counts only), and the
  GUI captures stdout/stderr as logs (PR 2.6) — so non-prompt Console output
  intentionally stays on stdio in supervised mode.

## PR 1.10 — Status push (incl. registered `bridgeId`) via `ControlStatusNotifier`
- **Goal:** Bridge pushes `status` (relay connection state, plugin health,
  active-session summary) over the channel, **and emits the `registered` event
  with its `bridgeId` as soon as registration succeeds** — so the GUI persists a
  readable copy *before* any crash/stop and can run the offline-unregister
  fallback (ADR A13, pairs with PR 2.13). Owner: a new **`ControlStatusNotifier`**
  (Layer 4 `control/`, per §6) that observes the Layer-0/state streams (relay
  connection state, plugin health, active-session summary, registration success
  exposed as a stream from the auth-subsystem seam) and owns **all** outbound
  status-class sends over the injected `ControlChannelClient`. The Orchestrator
  never calls `ControlChannelClient.send` directly.
- **Risk:** Low. **Size:** S-M.
- **Regression guide:** touches the orchestrator's registration/reconnect path
  (`ensureRegistered` runs at startup, on every reconnect, and after a 4006
  revocation). Check: (1) registration remains memoized (no duplicate POSTs per
  process); (2) the 4006 → `handleBridgeRevoked` → fresh-id re-registration flow
  still works and emits an updated `registered` event; (3) status emission is
  driven by existing streams (plugin health, relay state) — no new timers
  (reactive-vs-polling rule); (4) standalone: zero control sends attempted.
- **Acceptance:** status events received by a fake server; the `registered`
  event carries `bridgeId` and is emitted right after registration; reflects
  live changes (reactive, no polling).
- **Aristotle:** plan ☑ · impl ☑ (PR raised on branch `desktop-implementation-stage`).
- **Findings:** Shipped as four units, no shared-package changes (the PR-1.2
  DTOs already carried the status/registered shapes). (1) `RelayClient`
  (Layer 0) gained a broadcast `Stream<RelayConnectionState>` — a new sealed
  type (`RelayConnecting`/`RelayConnected`/`RelayDisconnected{closeCode}`) —
  the stream PLAN §6 and PR 1.14 already assumed exists. Emissions:
  `connect()` → connecting, then connected on success / disconnected(null) on
  failure; a remote drop emits disconnected with the socket's close code via a
  `sink.done` watcher armed per installed channel; a deliberate `close()`
  emits nothing (clean shutdown ≠ outage — the `ControlChannelClient`
  contract). Note: `dart:io` only processes the close handshake while the
  inbound stream is consumed — always true on a live connection (the relay
  loop drains `read()`); documented on the getter. (2)
  `BridgeRegistrationService` gained a broadcast `Stream<String> registrations`
  emitting the assigned id once per real registration round-trip (fresh + post-
  4006 re-registration; memoized reconnect calls do NOT emit) plus a `dispose()`
  registered with the shutdown coordinator. (3) `ControlStatusNotifier`
  (Layer 4 `control/`): subscribes (one `CompositeSubscription`) to plugin
  status, relay state, registrations, and the control channel's own
  `connectionState` — on control reconnect it re-sends `registered` + the
  current status snapshot (bypassing dedupe), since sends throw while the
  channel is down and status is edge-triggered. Consecutive identical statuses
  are deduped (no spam); sends are best-effort (`Log.d` on
  not-connected, `Log.w` catch-all — never throws into a stream callback).
  Health mapping: Starting→unknown, Ready→healthy, Degraded/Restarting→degraded,
  Failed/Stopping/Stopped→unavailable. (4) Composition: `RelayClient`
  construction lifted from `BridgeRuntime.create` into the runner (so the
  notifier can observe its state stream before the runtime composes);
  `BridgeRuntime.create` gains `required RelayClient relayClient` and
  `required ControlStatusNotifier? statusNotifier` (null in standalone);
  the notifier is constructed+started only inside the supervised gate, after
  `startPlugin` and the registration service, before `session.run()` — so the
  first registration/connect are never missed and standalone constructs zero
  control senders. Tests: 15 new notifier tests, 5 relay connectionState
  tests, 5 registrations-stream tests, 1 orchestrator end-to-end feed test
  (startup + live summary through a real notifier). `make analyze` +
  `dart analyze --fatal-infos` clean; `make test` all pass (app 1692).
- **Deltas:** the active-session summary is NOT an observed stream: it reaches
  the notifier as a typed delegate feed (`handleProjectsSummary`) from the
  Orchestrator's existing SSE pipeline — the count lives only in the plugin
  (Layer 1), and the summary event is already built there for phones, so the
  delegate reuses it instead of adding a Layer-4→Layer-1 access or a duplicate
  derivation (the `CompletionPushListener.handleSseEvent` precedent; §6
  amended). `Orchestrator`/`OrchestratorSession` carry a
  `required ControlStatusNotifier?` (nullable = standalone), mirroring how the
  runner gates every other supervised component.

## PR 1.11 — `unregister-and-exit` control command
- **Goal:** Handle a control command that unregisters the `bridgeId` (current
  token) then exits 0, for GUI logout ordering. Routed via the PR-1.9
  `BridgeControlMessageDispatcher`.
- **Risk:** Low. **Size:** S-M.
- **Regression guide:** exercises `BridgeRegistrationService.unregister()` and
  the ordered shutdown. Check: (1) unregister's 404-is-success semantics
  preserved (an already-revoked bridge still exits 0); (2) the `bridge_id` file
  is cleared exactly once and shutdown goes through `shutdownCoordinator` (plugin
  stopped, no orphaned managed runtime); (3) an unregister network failure still
  exits (logged, non-zero or per plan-review decision) rather than hanging the
  GUI's logout; (4) standalone logout (`bridge logout` CLI path) untouched.
- **Acceptance:** command unregisters then exits 0; routed via
  `BridgeControlMessageDispatcher`.
- **Aristotle:** plan ☑ · impl ☑ (PR raised on branch `next-desktop-plan-step`).
- **Findings:** Shipped as a new Layer-3 `ControlUnregisterService`
  (`services/control_unregister_service.dart`), the supervised counterpart of the
  token/prompt services the dispatcher already routes to. It takes the
  `auth/`-subsystem `BridgeRegistrationService` and an injected
  `Future<void> Function() terminate`, and owns the logout ordering boundary:
  `handleUnregisterAndExit()` calls `registrationService.unregister()` then
  `terminate()`, and **still terminates when unregister throws** (`Log.w`-logged,
  swallowed) so a bridge that can't reach the auth server can never hang the GUI's
  logout — the leaked registration is cleaned up by the GUI's offline-unregister
  fallback (ADR A13). The dispatcher gained a third `required` delegate; the
  existing `case ControlUnregisterAndExit()` flipped from `Log.d`-ignore to
  `unawaited(_unregisterService.handleUnregisterAndExit())`, keeping all three
  routes symmetric typed-delegate calls (`restart` stays the only inbound
  helper→GUI variant that is ignored). `terminate` is wired at the composition
  root to the existing `_shutdownThenExit(shutdownCoordinator, code: 0)` — the
  same graceful-shutdown-then-`io.exit` path the ADR-A9 loss policy uses, so the
  ordered plugin stop runs before exit (no orphaned runtime). Exit `0` on both
  success and unregister failure: a GUI-ordered logout is a clean stop, and a
  non-zero would risk PR-2.7's exit-code state machine backoff-respawning during
  logout; the shutdown backstop already defaults to 0 when no sentinel is set, so
  a hung logout-shutdown exits 0 too. `unregister()`'s 404-is-success and
  clear-bridge-id-once semantics are unchanged (reused, not reimplemented).
  Standalone byte-identical: every new object is built inside the
  `if (options.isSupervised)` gate. `make analyze` + `dart analyze --fatal-infos`
  clean; `make test` all pass (app 1695; +3 unregister-service/dispatcher tests).
- **Review round** (codex/cubic/gemini, 3 P2s + 1 P1 + hardening): closed four
  early-startup teardown gaps the new command exposes. (1) The dispatcher starts
  before `startPlugin()` registers its ordered stop, so a logout mid-start could
  exit without stopping the backend → the ordered `stopPlugin` is now registered
  **before** `startPlugin()` (`stopPlugin` safely awaits an in-flight start),
  which also hardens the pre-existing ADR-A9 loss path. (2) The dispatcher starts
  before `BridgeIdMigrationService.migrate()`, so a logout on a legacy
  `token.json`-only install could read an empty store and leak the registration →
  `migrate()` now runs first, before the control channel/dispatcher. (3) A hung
  logout-shutdown backstop reported the `failureLatch`-derived `1` when a plugin
  had already failed → added a `requestedSupervisedLogoutExitCode = 0` sentinel to
  the backstop chain. (4) A blackholed network could hang logout forever →
  `ControlUnregisterService` bounds `unregister()` with a configurable timeout
  (default 10s) and still terminates on timeout. Also switched the extracted
  registration builder to the safe `_localHostname()` helper. Declined gemini's
  auth-generation counter: the process exits immediately after unregister, so
  there are no surviving in-flight operations to invalidate. `make test` app 1696.
- **Deltas:** To route the command, the supervised `BridgeRegistrationService`
  had to exist when the dispatcher is built (before the bootstrap token pull, so
  `token_response` is never missed). Its construction was extracted into a static
  `_buildRegistrationService(...)` helper and built **early** in the supervised
  gate (its refresher is the already-present control token service); the original
  site now reuses that instance or builds the standalone one (whose refresher is
  the interactive-auth `TokenManager`, only available late). `bridgeIdStorage`
  construction moved a few lines earlier (pure, no I/O) so both build sites share
  it; the legacy-id migration still runs at its original point before auth. §6
  gains one row: `ControlUnregisterService` (Layer 3 `services/`).

## PR 1.12 — Single-live precedence under supervised `--hidden`
- **Goal:** Define/implement contention behaviour when no stdin: a supervised
  bridge surfaces replace-prompt via the control channel; define precedence vs a
  standalone terminal bridge on the same machine (avoid `nonInteractive` abort
  surprises). `ensureRuntime` already runs under the mutex. Note this is
  **same-machine** contention only; cross-machine contention is PR 1.14.
- **Risk:** Med. **Size:** M.
- **Regression guide:** touches the startup mutex / single-live enforcement that
  every standalone bridge runs through. Check: (1) two standalone terminal
  bridges on one machine still behave exactly as today (interactive replace
  prompt; `nonInteractive` abort path unchanged); (2) the startup mutex still
  serializes `ensureRuntime` (no concurrent managed-runtime installs); (3) a
  supervised bridge contending with a standalone one resolves per the documented
  precedence without either silently exiting; (4) replace-prompt timeout
  behaviour doesn't hang GUI boot.
- **Acceptance:** documented + tested precedence; no silent abort.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.13 — Tee `RuntimeProvisionProgress` → control channel
- **Goal:** In supervised mode, tee the typed `RuntimeProvisionProgress` stream
  from `_ensurePluginRuntime` onto the control channel (mapped to the PR-1.2
  DTOs) so the GUI can render first-run progress; keep stderr rendering for
  standalone.
- **Risk:** Low. **Size:** S-M.
- **Regression guide:** the provisioning stream is single-subscription and its
  error/terminal semantics are load-bearing. Check: (1) teeing does not break the
  runner's own consumption — `ProvisionReady.binaryPath` still lands on
  `PluginHost.provisionedRuntimePath` and `ProvisionFailed` still degrades (never
  exits); (2) a cooperative abort (`PluginStartAbortedException`) still surfaces
  as "aborted as requested"; (3) standalone `RuntimeProvisionFormatter` stderr
  output byte-identical; (4) a slow/blocked control channel must not stall
  provisioning (send is fire-and-forget/buffered).
- **Acceptance:** provision events reach a fake server; `ProvisionReady`/`Failed`
  terminal events conveyed; standalone formatter output unchanged.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.14 — Relay replaced-close (`4007`) → takeover state, no reconnect war (ADR A22)
- **Goal:** The relay keeps a single bridge slot per account and closes a
  displaced bridge with **1000 + reason `"replaced"`** (`handler.go`
  new-bridge-connect path). Today the bridge treats that as a generic drop and
  reconnects on a backoff that **resets to 1s on success** — so two always-on
  bridges (two desktops; desktop + forgotten systemd bridge) kick each other
  forever while phones see `bridge_connected` flapping. This PR makes losing the
  slot graceful:
  - **Primary detection = a dedicated relay close code `4007 bridgeReplaced`**
    (small `sesori_relay_server` change, deployed before/with the bridge
    change, plus the constant in `RelayCloseCodes` — it is NOT added to
    `noReconnectCodes`; the policy is long-backoff, not never-reconnect). Close
    **reason strings are fragile** — intermediaries/proxies may strip or rewrite
    them — and the codebase already keys every close semantic on codes
    (`bridgeRevoked = 4006` precedent). Keep `1000 + reason "replaced"` only as
    a **fallback match** for the relay-deploy window; the code is authoritative.
  - Expose `closeReason` alongside `closeCode` on the bridge `RelayClient`
    (Layer-0 dumb accessor, needed for the fallback match), and surface the
    replaced-close condition on the relay connection-state stream the
    `ControlStatusNotifier` (PR 1.10) already observes.
  - In the orchestrator reconnect loop, detect the replaced-close (4007, or the
    rollout fallback; the bridge's own clean close is guarded by `_cancelled`):
    **standalone** → loud `Console.warning` ("another bridge for this account
    took over") + retry only on a **long capped backoff** (order minutes, with
    jitter — exact numbers at plan review; long-backoff rather than stop keeps
    headless/VM failover semantics without a tight war). The Orchestrator owns
    ONLY this backoff policy change.
  - **Supervised push ownership:** the takeover state reaches the GUI through
    the PR-1.10 `ControlStatusNotifier` (Layer 4 `control/`), which maps the
    replaced-close condition from the relay state stream into a `status`/prompt
    per PR-1.2 DTO shapes (additive `@Default` field if needed). The
    Orchestrator never calls `ControlChannelClient` directly (no Layer-5→Layer-0
    send). The GUI's "Take over" action is a plain helper respawn (kill+spawn),
    NOT a new inbound control command.
- **Prerequisite (tracked — relay deploy gate):** the `sesori_relay_server`
  change (close the displaced bridge with `4007` instead of `1000/"replaced"`)
  is a separate small PR in that repo and must be **merged AND deployed to the
  production relay before this bridge PR merges**. Record the relay PR link and
  deploy confirmation in this entry's Findings log. The bridge half keeps the
  `1000/"replaced"` fallback so the ordering can never strand an old relay —
  but the fallback is a safety net, not a licence to skip the relay deploy.
  This is the single tracked exception to release-safety invariant #1 (see §4).
- **Standing-acceptance exception (explicit):** this PR intentionally changes
  standalone behaviour for the replaced-close case only. All other close codes
  (incl. 4006 revoked → re-register) keep today's behaviour, asserted by test.
- **Risk:** Med (touches every bridge's reconnect loop). **Size:** S-M.
- **Regression guide:** the reconnect loop is shared by all drop causes — the
  key risk is over-matching. Check: (1) a plain network drop / relay restart
  (abnormal close, no code) still reconnects on the existing 1s-reset backoff;
  (2) 4006 `bridgeRevoked` still re-registers with a fresh id and reconnects;
  (3) the bridge's own `cancel()`/dispose still never triggers a reconnect;
  (4) token-refresh-deferral reconnect gating (PR 1.5) unchanged; (5) SSE orphan
  handling (`orphanAll`) still runs on every drop; (6) a same-machine restart
  (exit 86 → respawn, successor handoff) is not misclassified as takeover.
- **Acceptance:** with two bridges alternately connecting for one account
  (fake relay), the displaced bridge does not reconnect within the war window
  and surfaces the takeover state (Console standalone / control channel
  supervised); detection works on close code `4007` alone (no reason string)
  AND on the `1000/"replaced"` rollout fallback; normal drop reconnection
  unchanged; covered by connection-level tests.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.15 — Dev control-host harness for manual supervised testing
- **Goal:** A small dev-only tool (`bridge/app/tool/dev_control_host.dart`,
  ~100 lines, never shipped) that lets a human drive supervised mode without the
  GUI (which doesn't exist until Phase 2): hosts a loopback WS control server,
  spawns the bridge with `--control-url`, writes a random per-spawn secret to the
  child's stdin, answers `token_request` with a token read from the developer's
  own `token.json` (or a `--token` flag), prints every inbound control message
  (status, registered, prompts, provision progress) to stdout, and offers
  keyboard commands to push a `token_update`, send `unregister_and_exit`, reply
  to prompts, and kill itself (to observe the helper's grace-period exit).
  Enables MT-1. Tool-only: no production wiring, no new deps in `lib/`.
- **Risk:** Low. **Size:** S.
- **Regression guide:** none to production code (tool/ only). Check the tool is
  excluded from the shipped binary and `make analyze`/`make test` stay green.
- **Acceptance:** a developer can run the harness + a locally-built bridge and
  observe: secret handshake, token pull/push, status/registered/provision
  events, prompt round-trip, unregister-and-exit, and grace-period exit on
  harness kill.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

---

## MT-1 — Manual checkpoint: bridge supervised mode end-to-end (user-run)

> Run after PR 1.15 (harness) — items are marked with the PR that enables them,
> so the already-enabled subset can be run any time. Goal: a human confirms the
> whole Phase-1 surface actually works on a real machine before any GUI exists.
> Check the §9 box only when every item passes.

**Setup:** build the bridge locally — from `bridge/app/` run
`dart build cli -o build/cli` and use `build/cli/bundle/bin/bridge` (don't use
`make build-host`: it resolves Dart via an asdf path from `bridge/.tool-versions`,
which is not in the repo, so it fails on a fresh checkout); have a logged-in
`token.json` (run the standalone bridge once); run the PR-1.15 harness.

| # | Check (enabled by) | How | Pass looks like |
|---|---|---|---|
| 1 | Standalone regression (all PRs) | run `sesori-bridge` in a terminal; connect the phone | login/startup output unchanged; phone browses sessions; `bridge_id` file exists; `token.json` has no `bridgeId` field |
| 2 | Secret handshake (1.1) | start via harness; then try `ps aux \| grep bridge` | helper connects; secret NOT visible in argv; `Authorization` only on the WS upgrade |
| 3 | Token pull (1.3/1.4) | harness answers `token_request` | helper authenticates to the relay with the harness-supplied token; phone connects through it |
| 4 | Token push + live re-auth (1.5) | push `token_update` with a fresh token while connected | relay session survives; no reconnect loop; helper uses the new token on next reconnect |
| 5 | Signed-out behaviour (1.4/1.5) | harness replies null `token_response` | helper defers relay reconnect (no stale-token re-auth); recovers after a valid push |
| 6 | Grace-period exit (1.1) | kill the harness process | helper exits (~5s grace), exit code 1, managed runtime shut down (no orphaned `opencode serve`) |
| 7 | Restart sentinel (1.7) | trigger restart from the phone | helper flushes `{restarting:true}`, exits **86**, does NOT spawn a successor |
| 8 | Auth-required sentinel (1.9) | harness replies null at bootstrap | helper emits `loginNeeded` prompt, exits **87** |
| 9 | Prompts (1.9) | start a second bridge to trigger replace-prompt | prompt arrives as a control event in the harness; reply drives the helper |
| 10 | Status + registered (1.10) | watch harness output | `registered{bridgeId}` right after registration; status reflects relay/plugin changes live (no periodic spam) |
| 11 | Unregister-and-exit (1.11) | send the command from the harness | helper unregisters (check the account's bridge list), clears `bridge_id`, exits 0 |
| 12 | Provision tee (1.13) | wipe the managed runtime dir; start via harness | download/extract/ready progress events stream to the harness; standalone run still renders stderr progress |
| 13 | No takeover war (1.14) | run a second bridge for the same account on another machine/VM (same-machine is blocked by the single-live mutex) | displaced bridge logs takeover + goes quiet (long backoff); no 1s flip-flop; phone stays usable on the winner |
| 14 | Self-update suppressed (1.8) | run supervised from a managed install | no reconcile/update attempt in logs; standalone still reconciles |

- **Aristotle:** n/a (no code). **Findings:** — (record surprises here; file
  §8 risks or plan-deltas for anything that fails) **Deltas:** —
