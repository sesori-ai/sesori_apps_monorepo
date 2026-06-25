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
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

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
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

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
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.4 — Token provider **pull** over channel
- **Goal:** `ControlChannelTokenService` (Layer 3 `auth/`) implements
  `AccessTokenProvider`/`TokenRefresher`; `getAccessToken({forceRefresh})`
  requests a token over the channel and blocks with a timeout; define behaviour
  when the GUI is mid-login/down. Client injected from composition root (no
  internal `new`).
- **Risk:** Med. **Size:** M.
- **Acceptance:** force-refresh requests a fresh token; timeout + GUI-down paths
  yield a typed failure (logged once at the surfacing point, not double-logged).
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.5 — Token-stream **push** → relay re-auth
- **Goal:** Make a GUI-pushed `token_update` actually re-authenticate the live
  relay connection. Today `RelayClient` reads `accessToken` only once in
  `connect()` and `tokenStream` is otherwise unused, so merely emitting on a
  stream leaves an **open** WebSocket on the old JWT until reconnect. This PR
  wires the `RelayClient` subscription → re-auth/reconnect path so a refresh
  while connected takes effect (ADR A12).
- **Risk:** Med (silent-auth-failure if wrong). **Size:** M.
- **Acceptance:** with a **live** relay connection (not just stream
  propagation), a pushed token update re-authenticates without losing the
  session; covered by a connection-level test.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.6 — Supervised registration + `bridgeId` out of `token.json`
- **Goal:** Persist `bridgeId` separately from `token.json` in a small
  file-backed store that lives **inside the `auth/` subsystem** (NOT new
  top-level `api/`+`repositories/` classes — that would make `auth/` depend back
  on the core repository layer; see ADR A6). Supervised registration uses the
  supplied token; preserve carry-over semantics. Use **synchronous** filesystem
  checks (`existsSync`/`statSync`) for the `avoid_slow_async_io` lint.
- **Risk:** Med (touches `TokenData` persistence). **Size:** M.
- **Acceptance:** supervised registers + persists bridgeId; standalone token.json
  path unchanged.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.7 — Exit-code restart (`86`) + bypass successor-spawn
- **Goal:** In supervised mode `handleRestartHandoff()` flushes the
  `{restarting:true}` response then `exit(86)` instead of
  `BridgeRestartService.spawnSuccessor()`. Name the exact bypass call site.
- **Risk:** Med. **Size:** S-M.
- **Acceptance:** phone-triggered restart → exit 86 in supervised mode; standalone
  successor handoff unchanged.
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
