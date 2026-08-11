# Mobile Codex Login

## Status

- **Plan slug:** `codex-mobile-login`
- **Status:** Step 1/8 - plan ready for review
- **Plan date:** 2026-08-11
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `origin/main` at `3708d348`
- **Delivery:** one plan PR, six sequential implementation PRs, and one
  plan-retirement PR

## Goal

Allow a user to sign an unauthenticated Codex harness on their connected bridge
machine into ChatGPT from the Sesori mobile app. Codex performs the OAuth device
authorization, token exchange, and credential persistence locally; Sesori
transports only the short-lived verification URL, user code, and sanitized
operation state.

Codex is the only implementation in this series. Future harnesses may implement
the same narrow optional capability with entirely different backend-specific
logic. This plan does not create a generic OAuth engine or expose Codex concepts
outside the Codex plugin.

## Success Criteria

1. A mobile user connected to a bridge with an unauthenticated supported Codex
   runtime can initiate ChatGPT device login without terminal access to the
   bridge machine.
2. The mobile app displays the user code and opens the Codex-provided HTTPS
   verification URL only after explicit user action.
3. Codex exchanges and stores credentials on the bridge machine. Tokens,
   credential files, account identifiers, and PKCE/device-auth internals never
   cross the Sesori relay.
4. Successful login is accepted only after a fresh Codex setup inspection
   reports `PluginSetupReady`.
5. An enabled Codex plugin becomes start-allowed under its existing activation
   policy after successful login; a disabled plugin remains disabled.
6. A lost response, app background/resume, reconnect, or second connected
   surface can safely retrieve the same active challenge without starting a
   competing Codex login.
7. Explicit cancellation and bridge shutdown cancel the Codex login and settle
   the owned child process.
8. Old/new app and bridge combinations continue to work through additive
   capability detection and honest defaults.
9. PATH, desktop-app, explicit, and Sesori-managed Codex installations all use
   the same executable resolution and environment as normal Codex sessions.

## Locked Product Decisions

- V1 supports login only when setup reports authentication required.
- Logout, account switching, re-authentication while ready, API-key entry, and
  enterprise access-token entry are excluded.
- The mobile app uses ChatGPT device authorization, not normal browser login.
- The user sees the code and anti-phishing warning before opening the browser.
- The external system browser is used; no embedded WebView or mobile callback
  is added.
- Dismissing the mobile sheet does not cancel login. Cancellation is an
  explicit action.
- One active operation exists per plugin. Repeated start requests join it.
- Authentication operation state is ephemeral and is not written to a database
  or settings file.
- Analytics are deferred until a concrete reporting decision exists.

## Explicitly Excluded

- Codex logout or account replacement.
- Mobile handling or transfer of OAuth authorization codes, access tokens,
  refresh tokens, API keys, Codex access tokens, or `auth.json`.
- Direct calls from Sesori to OpenAI's internal device-authorization endpoints.
- Parsing human output from `codex login --device-auth`.
- A raw Codex App Server proxy.
- Mobile deep links or a callback relay.
- OpenCode, Cursor, Claude Code, Pi, or other harness authentication
  implementations.
- A generic prompt/form protocol for hypothetical future authentication modes.
- Persisted login attempts, background jobs, PID registries, or cross-plugin
  authentication coordinators.

## Research And Current Behavior

### Why device authorization

Normal `codex login` starts an OAuth authorization-code flow whose redirect URI
targets loopback on the machine running Codex. Opening that authorization URL on
a phone sends the callback to the phone, not the bridge machine. Forwarding the
callback would require a new security-sensitive relay and is unnecessary.

Codex device authorization is designed for this cross-device case. The bridge
machine starts the operation, the phone displays a verification URL and user
code, and Codex continues polling and completes token exchange locally.

### Supported Codex protocol

Codex App Server provides structured JSON-RPC-style account methods over stdio
JSONL:

```text
account/login/start { type: chatgptDeviceCode }
account/login/cancel { loginId }
account/login/completed
account/read
```

Device-code App Server support shipped in Codex `0.118.0`. Sesori currently
accepts PATH/desktop Codex `>=0.139.0` and manages `0.146.0`; both preserve the
required request, challenge, cancel, and completion shapes. No minimum-version
or managed-runtime bump is required.

Upstream evidence:

- <https://developers.openai.com/codex/auth/>
- <https://developers.openai.com/codex/app-server/>
- <https://github.com/openai/codex/commit/47a9e2e084e21542821ab65aae91f2bd6bf17c07>
- <https://github.com/openai/codex/blob/rust-v0.139.0/codex-rs/app-server-protocol/src/protocol/v2/account.rs>
- <https://github.com/openai/codex/blob/rust-v0.146.0/codex-rs/app-server-protocol/src/protocol/v2/account.rs>

### Current Sesori seams

- `CodexPluginDescriptor.inspectSetup()` resolves a Codex binary and runs
  `codex login status`. It returns `PluginSetupAuthenticationRequired` for a
  logged-out runtime.
- Authentication-required setup blocks the ordinary Codex generation. Login
  therefore cannot depend on acquiring `BridgePluginApi`.
- `CodexAppServerClient` currently speaks WebSocket to the normal long-lived
  Codex generation. It does not expose account operations.
- Codex account notifications are intentionally ignored by the normal session
  event mapper because they have no backend-neutral session-event analog.
- `PluginLifecycleService` already owns setup, eligibility, management-command
  exclusion, install progress, activation, and management snapshot changes.
- Mobile plugin management already follows `PluginApi -> PluginRepository ->
  PluginManagementService -> PluginManagementCubit ->
  HarnessesSettingsScreen`.
- Relay HTTP requests time out after 30 seconds, so the login-start request must
  return the challenge quickly while completion continues on the bridge.

## Architecture

### 1. Optional plugin capability

Add `InteractivePluginAuthenticationDescriptor` to
`sesori_plugin_interface`. `CodexPluginDescriptor` implements it; descriptors
without an interactive flow do not.

The contract receives controlled host facts:

```text
PluginConfig
HostProcessService
bridge environment
descriptor-selected state directory
cooperative abort signal
```

It returns a stream whose first actionable event is a device-code challenge and
whose terminal event is completed or failed. Cancellation is delivered through
the bridge-owned abort signal. The stream contract requires plugin-owned process
cleanup before settlement.

Use sealed plugin-interface events so variant-specific data remains non-null:

```text
PluginAuthenticationDeviceCodeChallenge
  verificationUri
  userCode

PluginAuthenticationCompleted

PluginAuthenticationFailed
  message
```

Capability support is derived from interface presence during registration.
Do not add a second independently declared internal support flag or a default
unsupported authentication method to every descriptor.

### 2. Codex runtime resolution

Extract the current repeated resolution decision into one plugin-local
`CodexRuntimeSelectionService`. Setup inspection, `ensureRuntime`, and authentication
must all preserve this order:

```text
explicit --codex-bin
PATH codex >= 0.139.0
Codex desktop-app CLI >= 0.139.0
exact installed managed runtime
```

The service uses existing `RuntimeVersionValidator`,
`HostProcessCommandExecutor`, `CodexRuntimeManifest`, and home-directory
resolution. It does not install, download, sweep, or read credentials.

Authentication receives the same bridge environment as normal Codex startup so
`CODEX_HOME`, custom CA configuration, managed policy, and credential-store
selection remain authoritative.

### 3. Codex authentication layers

Keep the backend flow inside `sesori_plugin_codex` and follow the mandatory
layer sequence:

```text
CodexStdioAppServerClient
  -> CodexAppServerApi
  -> CodexAuthenticationRepository
  -> CodexAuthenticationService
  -> CodexPluginDescriptor
```

`CodexStdioAppServerClient` is the Layer-0 transport owner. It spawns
`codex app-server --listen stdio://` through `HostProcessService`, drains stderr,
frames newline-delimited JSON, correlates request IDs, publishes typed server
notifications, detects child exit, and performs bounded graceful/force cleanup.
It sends the protocol-required `initialized` notification after a successful
`initialize` response.

`CodexAppServerApi` remains the typed boundary for the external Codex App Server
tool. Add typed account request/response methods rather than manual map parsing
inside orchestration.

`CodexAuthenticationRepository` consumes the typed API, maps device-code
responses, retains the upstream `loginId`, and correlates only the matching
completion notification. Raw JSON, account records, and the private login ID do
not leave this layer.

`CodexAuthenticationService` owns the operation state machine: initialize,
start device login, emit the safe challenge, await matching completion, cancel
on abort, translate failures to privacy-safe plugin events, and settle transport
cleanup. It preserves original errors and stack traces in local diagnostics
without relaying raw error text.

`CodexPluginDescriptor` composes these concrete layers and delegates the
authentication stream. It does not directly consume transport frames or own the
authentication state machine.

### 4. Bridge operation ownership

Extend `PluginRuntime` and `PluginLifecycleRepository` with an authentication
operation seam that resolves the registered descriptor, constructs controlled
host inputs, owns the abort controller, and invokes only descriptors that
implement the optional contract.

Extend the existing `PluginLifecycleService` rather than introducing an
independent coordinator. It owns:

- one active authentication operation per plugin;
- the safe challenge retained for start-or-join requests;
- transient idle/in-progress management state;
- command exclusion against install, refresh, enable, disable, and restart;
- explicit cancellation;
- setup reinspection after terminal completion, failure, or cancellation;
- management snapshot invalidation; and
- shutdown abort and awaited settlement.

For a new operation, setup must currently be
`PluginSetupAuthenticationRequired`. An already-active operation is returned
before that check so retries and second surfaces join the same operation.

After a completion event, `inspectSetup()` remains authoritative. Only
`PluginSetupReady` enters the existing start-allowed set. Existing eligibility
and activation rules then decide whether to start Codex; authentication never
enables a disabled plugin.

### 5. Shared wire contract

Add these backend-neutral models to `sesori_shared`:

```text
PluginManagementCapability.authentication

PluginAuthenticationState
  idle
  inProgress
  unknown

PluginAuthenticationChallengeResponse
  deviceCode
    verificationUrl
    userCode

PluginAuthenticationProgress
  completed
  failed
    message
  cancelled
```

Progress is sealed; only the failed variant carries its required sanitized
message. Do not flatten progress into an enum plus nullable message.

Add `authenticationState` to `PluginManagementMetadata`. Omission by a released
old bridge defaults honestly to `idle` with the required dated compatibility
comment. Unknown enum values map to `unknown`.

The challenge is request-scoped and held only in bridge/client memory. It is not
included in management snapshots, SSE replay, analytics, diagnostics, or
persistence.

### 6. Bridge routes and SSE

Register explicit plugin-neutral handlers:

```text
POST   /plugin/:id/authentication
DELETE /plugin/:id/authentication
```

POST starts a new operation or joins the current one and returns the typed
challenge before the relay timeout. DELETE requests cancellation; the terminal
progress event remains authoritative.

Reject unknown plugins with 404. Reject unsupported capability, setup that does
not require authentication, or conflicts with another management command with
a typed 409 response and current management metadata. Do not add a fallback
route for unpublished contracts.

`PluginLifecycleService` exposes typed progress. `Orchestrator` alone maps it to
the new Sesori SSE event. The existing `plugin.management.changed` SSE remains
the refresh trigger for setup and transient operation state.

No relay message variant, framing-version bump, relay-server route, or relay
trust-posture change is required.

### 7. Client orchestration

Extend the existing client layers:

```text
PluginApi
  -> PluginRepository
  -> PluginManagementService
  -> PluginManagementCubit
  -> HarnessesSettingsScreen
```

`PluginApi` owns typed start/cancel HTTP calls. `PluginRepository` maps success,
typed conflicts, unsupported old peers, definite failures, and potentially
dispatched response loss. `PluginManagementService` fences the challenge and
progress by connection epoch and bridge identity, tracks an operation started
by this app, and refreshes authoritative snapshots on terminal progress.

`PluginManagementCubit` receives the existing `UrlLauncher` platform
capability. It owns start, challenge presentation, explicit browser launch,
cancel intent, launch failure, and ephemeral presentation state. It does not
infer support from plugin ID or setup text.

Validate and parse the verification URI before presentation. Bridge and client
both require HTTPS. Neither layer logs the URL or code.

### 8. Mobile presentation

Extend the existing harness control card:

- Show `Log in` only with the authentication capability and
  `authenticationRequired` setup.
- Show `Continue login` while authentication is in progress.
- Present a device-code sheet with the code, copy action, external-browser
  action, explicit cancel action, waiting state, and accessible labels.
- Explain that the user is signing the connected computer into ChatGPT for
  Codex.
- Preserve the Codex anti-phishing meaning: continue only when the user started
  this request.
- Keep the sheet/code available while the app is foregrounded; a later tap can
  retrieve the active challenge again after dismissal or reconnect.
- On completion, let the refreshed management snapshot remove the login action
  and expose normal Codex controls.

The browser opens only after an explicit tap. Closing or backgrounding the app
does not imply cancellation.

## Compatibility Matrix

| App | Bridge | Result |
|---|---|---|
| Old | Old | Existing local-login guidance and setup state. |
| Old | New | New capability decodes as unknown and no new route is called. Existing setup remains usable. |
| New | Old | No authentication capability is advertised, so the mobile login control is hidden. |
| New | New | Capability-gated device login, progress, cancellation, and setup refresh are available. |

Compatibility details:

- The relay framing version remains unchanged.
- The new route is called only after capability advertisement.
- Omitted authentication state defaults to idle for released old bridges.
- Unknown capability/state values fail closed.
- Missing terminal SSE during app background is self-healing through the
  existing management refresh; a still-active operation remains visible and
  joinable.
- Bridge restart cancels the ephemeral process and normal setup inspection
  recovers the persisted Codex credential truth.

## Failure And Recovery Contract

| Failure | User outcome | Local observability |
|---|---|---|
| Device login is disabled by account/workspace policy | Login remains required and a sanitized actionable failure is shown. | Codex error, stack, and operation context remain in local bridge logs. |
| App loses the POST response after dispatch | UI reports an uncertain start; retry joins the existing bridge operation. | Typed relay response-loss result. |
| App backgrounds while browser is open | Bridge login continues; resume refreshes management state. | Existing connection lifecycle diagnostics. |
| Codex App Server exits before completion | Login fails, operation returns idle, setup is re-inspected. | Child exit and operation context remain local. |
| User explicitly cancels | All surfaces observe cancelled progress and authentication remains required. | Cancel request and upstream settlement remain local. |
| Bridge shuts down | Abort is signaled and the child is settled before service disposal completes. | Shutdown failure retains original error/stack locally. |
| Codex reports completion but setup remains blocked/unknown | Mobile does not claim success; refreshed setup guidance is shown. | Setup probe result and local diagnostics remain authoritative. |
| Returned verification URL is not HTTPS | Challenge is rejected and never presented. | Privacy-safe protocol failure remotely; original response context stays local. |

## Security And Privacy

- The authenticated E2E Sesori control channel remains the only remote entry
  point. Codex App Server is local stdio and is never internet-exposed.
- Only the verification URL and user code cross the relay. They are ephemeral
  login ceremony data and must not be logged, persisted, included in errors, or
  sent through analytics.
- Never read, copy, parse, upload, or synchronize `$CODEX_HOME/auth.json`.
- Never expose access tokens, refresh tokens, API keys, PKCE verifiers,
  authorization codes, device-auth IDs, upstream login IDs, email, workspace,
  plan type, or account identifiers.
- The private upstream login ID is matched inside the Codex repository/service
  and does not enter shared contracts.
- The user remains responsible for explicit browser authorization. Sesori does
  not silently approve or pre-enter the code.
- Use the URL returned by Codex rather than hardcoding an OpenAI path, while
  requiring HTTPS at both boundaries.
- A user-selected Codex binary is already trusted executable code. Sesori does
  not add broader host allowlists or attempt to sandbox it in this feature.
- Remote failures are sanitized. Local logs retain diagnostically useful
  errors, stacks, executable/process context, and policy failures without
  credential material.

## Analytics

No analytics event is added in this series. A button tap is not an authoritative
outcome, and there is not yet a concrete product/reporting decision that
justifies client attribution and warehouse work for a bridge-owned operation.

If a future decision requires measurement, add only a bounded account-linked
terminal outcome for attempts initiated by that app. Never include harness or
provider identity, bridge/plugin IDs, codes, URLs, account data, or raw errors.

## Cleanup Assessment

Small directly caused cleanup is included:

- consolidate duplicated Codex executable resolution used by setup and startup;
- replace the Codex setup hint that requires running `codex login` locally with
  neutral sign-in guidance when mobile authentication is available; and
- send the protocol-required `initialized` notification on the new stdio
  connection.

Compatibility and setup authority require retaining:

- `codex login status` setup inspection;
- `PluginSetupAuthenticationRequired` as the start gate;
- local manual-login guidance for peers without the new capability; and
- ignored account notifications on the ordinary session-event mapper.

No database table, column, persisted setting, cache, job, listener, or released
route becomes obsolete.

## Proportionality And Accepted Risk

| Decision | Evidence level | If omitted | Chosen response |
|---|---|---|---|
| Device-code flow | Ordinary cross-device login; normal OAuth callback targets localhost. | Mobile browser cannot complete login on the bridge machine. | Implement through Codex App Server stdio. |
| One active operation per plugin | Relay response loss, reconnect, and multiple surfaces are normal supported flows. | Competing starts replace/cancel upstream login and confuse users. | Retain one ephemeral challenge and make POST start-or-join. |
| Setup reinspection after completion | App Server completion proves the ceremony, not Sesori routability. | Mobile could claim success while Codex setup remains blocked. | Keep `inspectSetup()` authoritative. |
| Shared optional capability | Bridge app and clients must remain backend-neutral. | Core code imports Codex or infers behavior from plugin ID. | One narrow optional descriptor interface; plugin-specific implementation. |
| Persist auth operation | No recovery need: Codex credentials are durable and setup inspection recovers truth. | A bridge restart loses only the short-lived challenge. | Accept; abort operation and require a new login if still unauthenticated. |
| Separate GET challenge route | POST can safely join and replay the same active challenge. | None beyond REST stylistic preference. | Omit GET and keep the route set small. |
| Generic prompt/form framework | No current second flow or shared prompt requirements. | Future harness adds its own variant when evidence exists. | Defer. |
| Independent bridge timeout beyond Codex's 15-minute device timeout | Upstream already owns a verified timeout and child exit is observed. | A future upstream bug could leave a process until cancel/shutdown. | Accept; do not duplicate speculative timeout coordination. |

## Delivery Rules

- The series has exactly eight PRs. Every title below is fixed and uses the
  `codex-mobile-login` slug.
- Step 1 raises this plan and tracker.
- Step 8 records final evidence and moves this directory from `.plan/active/`
  to `.plan/completed/`.
- Merge in numeric order. A successor may be developed locally while its
  predecessor is open but is not raised until the predecessor merges.
- Target no more than 1,500 changed lines per PR, including generated output and
  tests. Update the plan before opening a step that cannot fit coherently.
- Generated Freezed/JSON/DI/localization files change only through generators.
- Keep backend-specific request names, login modes, output handling, timeout,
  credential behavior, and errors inside `sesori_plugin_codex`.
- Run architecture implementation review for Steps 2, 3, 5, and 6. Step 4 is
  shared wire architecture and also receives implementation review if generated
  scope or compatibility handling materially changes the planned contract.
- Step 7 is UI implementation over established layers and does not need
  architecture review unless its ownership changes.

## Delivery Sequence

| Step | Exact PR title | Estimate | Boundary |
|---|---|---:|---|
| 1/8 | `🌱 [codex-mobile-login] docs: plan mobile Codex login [step 1/8]` | 450-850 | Active plan and tracker only. |
| 2/8 | `⚙️ [codex-mobile-login] refactor(codex): prepare authentication primitives [step 2/8]` | 850-1,400 | Shared Codex runtime selection service, stdio JSONL client, typed account API, protocol tests; no bridge/client capability. |
| 3/8 | `🚧 [codex-mobile-login] feat(codex): implement device authentication [step 3/8]` | 850-1,450 | Optional plugin contract plus Codex authentication repository/service/descriptor delegation and process lifecycle tests; no remote route. |
| 4/8 | `⚙️ [codex-mobile-login] feat(protocol): describe harness authentication [step 4/8]` | 650-1,200 | Shared capability, operation state, sealed challenge/progress, compatibility defaults, generated code, contract tests. |
| 5/8 | `🚧 [codex-mobile-login] feat(bridge): expose harness authentication [step 5/8]` | 950-1,500 | Runtime/repository/service ownership, start-or-join and cancel routes, Orchestrator SSE mapping, reinspection/activation/disposal tests. |
| 6/8 | `🚧 [codex-mobile-login] feat(client): orchestrate harness authentication [step 6/8]` | 900-1,500 | Client API/repository/service/cubit, connection fencing, response-loss/progress/browser-launch behavior, pure-Dart tests. |
| 7/8 | `⚙️ [codex-mobile-login] feat(app): add mobile Codex login [step 7/8]` | 750-1,350 | Capability-gated harness card, code sheet, copy/open/cancel, localization/accessibility, widget and real-Codex smoke tests. |
| 8/8 | `🌱 [codex-mobile-login] docs: retire mobile Codex login plan [step 8/8]` | 50-200 | Final evidence and plan move to completed. |

## Step Details And Verification

### Step 1/8 - Plan

- Add this `PLAN.md` and `TRACKER.md`.
- Record the architecture plan review and applied findings.
- Run `git diff --check`. No Dart or Flutter suites are needed.

Expected result: no user-visible, wire, database, persisted-data, or runtime
behavior change.

### Step 2/8 - Codex authentication primitives

- Extract `CodexRuntimeSelectionService` and preserve explicit/PATH/desktop/managed
  precedence in setup and startup.
- Add the stdio JSONL client over `HostProcessService` with request correlation,
  notification delivery, stderr draining, child-exit handling, initialization,
  `initialized`, and bounded cleanup.
- Extend `CodexAppServerApi` with typed device-login start/cancel and completion
  DTOs without exposing raw maps downstream.
- Cover fragmented/coalesced lines, malformed JSON, unknown messages, request
  errors, initialization failure, child exit, cancel, disposal, and no-secret
  diagnostics.
- Run Codex plugin tests, fatal-info analysis, and architecture implementation
  review.

Expected result: no user-visible behavior; Codex has tested local primitives for
a structured authentication flow.

### Step 3/8 - Plugin-owned Codex authentication

- Add the optional descriptor contract and sealed plugin authentication events.
- Derive capability presence from descriptor implementation.
- Add `CodexAuthenticationRepository` and `CodexAuthenticationService` with
  private login-ID correlation, abort-driven cancellation, sanitized failure,
  and process cleanup.
- Compose and delegate from `CodexPluginDescriptor` using the same resolved
  executable/environment as setup/startup.
- Cover successful challenge/completion, wrong/stale completion IDs, workspace
  policy failure, child exit, explicit abort, shutdown, and credential-free
  outputs/logs.
- Run interface and Codex tests/analysis plus architecture implementation
  review.

Expected result: no route or mobile behavior; the Codex descriptor can perform
device authentication through the optional plugin seam.

### Step 4/8 - Shared contracts

- Add the authentication management capability and operation state with old-
  bridge omission defaults and unknown-enum handling.
- Add sealed device challenge and completed/failed/cancelled progress models.
- Add typed request/response/conflict models needed by handlers and clients.
- Add the Sesori SSE authentication progress event and exports.
- Regenerate shared code and cover old/new payloads, unknown values, strict
  required fields, and sealed variant round-trips.
- Run shared tests/analysis and affected bridge/client compile checks.

Expected result: no peer advertises or invokes authentication yet; compatible
wire vocabulary is available.

### Step 5/8 - Bridge orchestration

- Extend `PluginRuntime` and `PluginLifecycleRepository` with controlled
  authentication start/cancel/disposal.
- Extend `PluginLifecycleService` with operation ownership, command exclusion,
  start-or-join challenge retention, transient state, reinspection, existing
  activation policy, and management invalidation.
- Add explicit POST/DELETE handlers and register them in `Orchestrator`.
- Map typed service progress to SSE only in `Orchestrator`.
- Cover 404, typed 409 conflicts, duplicate/retry joins, response timing,
  enabled/disabled completion, setup remaining blocked, cancellation, bridge
  shutdown, and sanitized remote errors.
- Run bridge app focused/full tests, fatal analysis, build/codegen as required,
  and architecture implementation review.

Expected result: a capable relay client can start, resume, and cancel Codex
device login; no released app calls the route yet.

### Step 6/8 - Client orchestration

- Extend `PluginApi` and `PluginRepository` with typed start/cancel and mutation
  uncertainty handling.
- Extend `PluginManagementService` with bridge/connection fencing, active state,
  terminal progress handling, and authoritative snapshot refresh.
- Extend `PluginManagementCubit` with challenge presentation, `UrlLauncher`,
  explicit browser open, cancel, launch failure, and disposal-safe async state.
- Never log or report the challenge URL/code.
- Cover old bridge, unsupported capability, malformed/non-HTTPS challenge,
  response loss and retry, bridge switch in flight, duplicate taps, background
  refresh, missed SSE recovery, terminal outcomes, and browser launch failure.
- Run module_core codegen/DI generation, tests, analysis, downstream mobile and
  desktop analysis, and architecture implementation review.

Expected result: no visible control yet; pure-Dart client state can safely drive
the login experience.

### Step 7/8 - Mobile experience

- Add capability/setup-gated `Log in` and in-progress `Continue login` rows.
- Add the device-code sheet with anti-phishing wording, copy, explicit external
  browser open, waiting state, cancel, and accessible semantics.
- Keep dismissal separate from cancellation and allow challenge recovery by
  tapping Continue after reconnect.
- Update Codex setup guidance to no longer require local terminal login when the
  capability is available.
- Cover visibility gating, loading/error states, code presentation/copy, browser
  open, cancel, dismissal, reconnect, completion refresh, localization, and
  accessibility.
- Run focused/full Flutter tests and analysis. Perform a real pinned-Codex smoke
  test from logged out through mobile authorization to successful session
  creation, without recording codes or account data.

Expected result: users can complete the approved Codex login flow from mobile;
old peer combinations retain current behavior.

### Step 8/8 - Retire plan

- Confirm Steps 1-7 merged in order and record final PRs and verification.
- Move `.plan/active/codex-mobile-login/` to
  `.plan/completed/codex-mobile-login/` in one commit.
- Run `git diff --check`. No Dart/Flutter suites or architecture review are
  needed for this documentation-only step.

Expected result: no user-visible, wire, database, persisted-data, or runtime
behavior change.

## Material Risks

| Risk | Mitigation |
|---|---|
| Normal OAuth callback opens on the wrong device. | Use only Codex's ChatGPT device-code App Server mode. |
| A second request replaces the active Codex login. | One operation per plugin; POST joins and replays its safe challenge. |
| Login writes credentials to a different Codex profile. | Reuse executable resolution and the bridge's exact Codex environment. |
| Mobile claims success before Codex is routable. | Reinspect setup and accept only `PluginSetupReady`. |
| Auth operation races install or lifecycle mutation. | Reuse existing per-plugin management-command exclusion. |
| Browser background loses client transport/SSE. | Keep polling bridge-side and recover through management refresh/start-or-join. |
| Challenge or credential material reaches logs/analytics. | No challenge logging, sealed safe DTOs, local-only raw errors, no analytics event. |
| Bridge shutdown leaves a Codex process running. | Runtime-owned abort plus awaited graceful/force settlement before disposal. |
| Device login is disabled by OpenAI account/workspace policy. | Preserve typed local cause and return sanitized actionable failure. |
| User-installed binary returns an unexpected verification URL. | Require HTTPS twice; the explicitly selected executable remains a trusted local dependency. |

## Plan Review Record

Architecture plan review rejected the initial draft on 2026-08-11 with two
actionable findings. The Codex flow now explicitly follows
`CodexStdioAppServerClient -> CodexAppServerApi ->
CodexAuthenticationRepository -> CodexAuthenticationService`, with the
descriptor limited to composition/delegation. Shared terminal progress is now a
sealed hierarchy whose failed variant alone carries its required sanitized
message. Per repository process, these direct corrections were not re-reviewed
merely to obtain an approval verdict.
