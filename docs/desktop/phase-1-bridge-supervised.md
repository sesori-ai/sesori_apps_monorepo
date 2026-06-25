# Phase 1 — Bridge Supervised Mode

> Goal: teach the existing `sesori-bridge` a **supervised mode** (gated by
> `--control-url`/`--control-secret`) where the GUI is its token authority and
> lifecycle owner. **Every PR is additive and gated** so the standalone CLI is
> provably unchanged and the relay protocol is untouched (release-safety
> invariant #1). All PRs target the bridge workspace and can proceed in parallel
> with Phase 0/2 prep.

**Per-PR template:** Goal · Scope · Risk · Review-size · Acceptance · DoD ·
Aristotle verdicts · Findings log · Plan-deltas.

**Standing acceptance (all Phase 1 PRs):** standalone behaviour byte-identical
(asserted by test) · relay protocol untouched · `--control-url` absent ⇒ exact
current behaviour.

**Rebase note:** main #322 added `_ensurePluginRuntime` + foundation imports to
`bridge_runtime_runner.dart`; supervised wiring layers on top. `ensureRuntime`
runs **under the startup mutex**, which reinforces PR 1.12.

---

## PR 1.1 — `--control-url`/`--control-secret` + `ControlChannelClient` skeleton
- **Goal:** Parse the new flags in `RunCommand`; add `ControlChannelClient`
  (Layer 0 `bridge/foundation/`, `web_socket_channel`) that connects/reconnects
  to the GUI; no message semantics yet.
- **Risk:** Low. **Size:** M.
- **Acceptance:** standalone unchanged; with flags, client connects to a fake
  server in tests; reconnect on drop.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.2 — Control-protocol Freezed DTOs (incl. provision-progress mirror)
- **Goal:** Define wire DTOs in `shared/sesori_shared`: `token_request`,
  `token_response`, `token_update`, `status`, `prompt_request`/`prompt_response`,
  `restart`, `unregister_and_exit`, and **provision-progress** variants mirroring
  `RuntimeProvisionProgress` (resolving/downloading{received,total}/extracting/
  verifying/notice/ready/failed). Pure data + (de)serialization + tests.
- **Risk:** Low. **Size:** S-M.
- **Acceptance:** round-trip serialization tests; no logic in shared.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.3 — Supervised auth bootstrap
- **Goal:** In supervised mode, short-circuit
  `BridgeRuntimeAuthService.ensureAuthenticated`/`promptForProvider` (no stdin);
  obtain the initial token from the control channel; keep an equivalent
  `logAuthenticatedUser` after the token arrives.
- **Risk:** Med (auth path). **Size:** M.
- **Acceptance:** supervised start never reads stdin; standalone interactive flow
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

## PR 1.5 — Token-stream **push** → relay client
- **Goal:** Bridge `tokenStream` so GUI-pushed `token_update`s emit on the
  `ValueStream<String>` the `RelayClient` consumes; relay never uses a stale
  token after a GUI refresh.
- **Risk:** Med (silent-auth-failure if wrong). **Size:** S-M.
- **Acceptance:** a pushed update propagates to the relay client in tests.
- **Aristotle:** plan ☐ · impl ☐. **Findings:** — **Deltas:** —

## PR 1.6 — Supervised registration + `bridgeId` out of `token.json`
- **Goal:** Persist `bridgeId` via `BridgeIdentityFileApi` (L1) +
  `BridgeIdentityRepository` (L2), separate from `token.json`; supervised
  registration uses the supplied token; preserve carry-over semantics.
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

## PR 1.10 — Status push
- **Goal:** Bridge pushes `status` (relay connection state, plugin health,
  active-session summary) over the channel.
- **Risk:** Low. **Size:** S-M.
- **Acceptance:** status events received by a fake server; reflects live changes
  (reactive, no polling).
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
