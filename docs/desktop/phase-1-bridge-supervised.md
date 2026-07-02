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
- **Aristotle:** plan ☑ · impl ☑.
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
- **Aristotle:** plan ☑ · impl ☑.
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
- **Aristotle:** plan ☑ · impl ☑.
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
- **Aristotle:** plan ☑ · impl ☑.
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
- **Aristotle:** plan ☑ · impl ☑. **Findings:** Live re-auth subscription lives
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
  gone. **Deltas:** —

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
- **Aristotle:** plan ☑ · impl ☑. **Findings:** impl-review (3 rounds): (1)
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
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

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
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

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
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

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
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

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
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

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

**Setup:** build the bridge locally (`cd bridge/app && make build-host`); have a
logged-in `token.json` (run the standalone bridge once); run the PR-1.15 harness.

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
