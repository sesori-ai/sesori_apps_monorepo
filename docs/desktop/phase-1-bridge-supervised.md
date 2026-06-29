# Phase 1 — Bridge Supervised Mode

> Goal: teach the existing `sesori-bridge` a **supervised mode** (gated by
> `--control-url` + an off-argv secret) where the GUI is its token authority and
> lifecycle owner. **Every PR is additive and gated** so the standalone CLI is
> provably unchanged and the relay protocol is untouched (release-safety
> invariant #1). All PRs target the bridge workspace and can proceed in parallel
> with Phase 0/2 prep.

**Per-PR template:** Goal · Scope · Risk · Review-size · Acceptance · DoD ·
Aristotle verdicts · Findings log · Plan-deltas.

**Standing acceptance (all Phase 1 PRs):** standalone behaviour byte-identical
(asserted by test) · relay protocol untouched · `--control-url` absent ⇒ exact
current behaviour.

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
- **Aristotle:** plan ☑ · impl ☐. **Findings:** Live re-auth subscription lives
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
- **Acceptance:** phone-triggered restart → exit 86 in supervised mode; standalone
  successor handoff unchanged; **supervised mode never calls `spawnSuccessor()`**
  (closes the PR-1.1 `--control-url`-replay gap — asserted by test).
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.8 — Disable self-update + reconcile when supervised
- **Goal:** Pass `SESORI_NO_UPDATE`/skip policy; assert reconcile is skipped so a
  bundled bridge never rewrites itself.
- **Risk:** Low. **Size:** S.
- **Acceptance:** no update/reconcile attempt in supervised mode; standalone
  self-update intact.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.9 — Re-home prompts/Console → control events
- **Goal:** Replace-bridge prompt + login-needed + essential `Console` output
  become structured control events in supervised mode.
- **Risk:** Med. **Size:** M.
- **Acceptance:** standalone Console output **byte-identical**; supervised emits
  structured events.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.10 — Status push (incl. registered `bridgeId`)
- **Goal:** Bridge pushes `status` (relay connection state, plugin health,
  active-session summary) over the channel, **and emits the `registered` event
  with its `bridgeId` as soon as registration succeeds** — so the GUI persists a
  readable copy *before* any crash/stop and can run the offline-unregister
  fallback (ADR A13, pairs with PR 2.13).
- **Risk:** Low. **Size:** S-M.
- **Acceptance:** status events received by a fake server; the `registered`
  event carries `bridgeId` and is emitted right after registration; reflects
  live changes (reactive, no polling).
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.11 — `unregister-and-exit` control command
- **Goal:** Handle a control command that unregisters the `bridgeId` (current
  token) then exits 0, for GUI logout ordering.
- **Risk:** Low. **Size:** S-M.
- **Acceptance:** command unregisters then exits 0; routed via
  `BridgeControlMessageDispatcher`.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.12 — Single-live precedence under supervised `--hidden`
- **Goal:** Define/implement contention behaviour when no stdin: a supervised
  bridge surfaces replace-prompt via the control channel; define precedence vs a
  standalone terminal bridge on the same machine (avoid `nonInteractive` abort
  surprises). `ensureRuntime` already runs under the mutex.
- **Risk:** Med. **Size:** M.
- **Acceptance:** documented + tested precedence; no silent abort.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.13 — Tee `RuntimeProvisionProgress` → control channel
- **Goal:** In supervised mode, tee the typed `RuntimeProvisionProgress` stream
  from `_ensurePluginRuntime` onto the control channel (mapped to the PR-1.2
  DTOs) so the GUI can render first-run progress; keep stderr rendering for
  standalone.
- **Risk:** Low. **Size:** S-M.
- **Acceptance:** provision events reach a fake server; `ProvisionReady`/`Failed`
  terminal events conveyed; standalone formatter output unchanged.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —
