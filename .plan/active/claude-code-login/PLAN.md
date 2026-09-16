# Claude Code Login

## Status

- **Plan slug:** `claude-code-login`
- **Created:** 2026-09-16
- **State:** Steps 1–3/6 merged (#1508, #1516, #1517); Step 4/6 in review
- **Series:** six PRs, titles fixed under "Fixed PR Series"

## Goal

Let a Sesori user sign the bridge machine's Claude Code CLI into their
claude.ai account from the phone or desktop app, without touching the bridge
machine. Claude Code is the harness that most often drops its login (observed
after IP or network changes), so today every drop forces the user back to a
terminal on the bridge host to run `claude auth login`.

The bridge drives the official `claude auth login` command. The user opens the
sign-in page from the app, approves access in the browser, copies the code that
Claude shows afterwards, and pastes it into the app. Sesori relays the code to
the CLI, which performs the token exchange and stores the credential exactly as
a local login would. Sesori never sees, stores, refreshes, or exchanges tokens.

## Success Criteria

- A Claude harness whose setup reports `authenticationRequired` shows the
  existing `Log in` control on mobile and desktop.
- Starting login returns, within the existing start timeout, a challenge that
  carries the Claude authorization URL; the sheet shows an explicit
  "open sign-in page" action and a code field.
- Submitting the pasted code completes the login; the refreshed setup reports
  `ready` and a Claude session can start from Sesori without any action on the
  bridge host.
- Cancellation, timeout, a rejected code, a CLI exit, and bridge shutdown all
  end the operation with a terminal progress event and a fresh setup
  inspection. Remote failure text is the bridge's existing generic string;
  plugin-authored detail stays in local logs. No CLI process outlives its
  operation.
- On macOS and Linux bridges the host never opens a browser during a
  Sesori-initiated login; `true` is on `PATH` on every supported system.
  Windows is unverified and recorded as a limitation in the capability
  matrix.
- No authorization URL, pasted code, token, email, or organization value
  appears in bridge logs, client logs, error messages, analytics, SSE replay,
  or persistence for well-formed responses. The one exception, a malformed
  successful challenge body from a defective bridge retained in a local client
  parsing error, is the accepted risk recorded under Security And Privacy.
- Older apps against a new bridge fail closed with the existing
  "update required" guidance; new apps against an older bridge show no Claude
  login control.

## Locked Product Decisions

- Login is offered only while setup reports authentication required, matching
  Codex. Re-login while ready, account switching, and logout are excluded.
- The bridge drives the official `claude auth login --claudeai` command over
  plain piped stdio. Sesori does not implement the OAuth exchange, does not use
  Claude Code's client id, and never reads or writes the credential store.
- Only the claude.ai subscription login is offered. Console (API billing), SSO
  forcing, API-key entry, `claude setup-token`, and `CLAUDE_CODE_OAUTH_TOKEN`
  handling are excluded.
- The flow is the CLI's documented paste-code path on every platform: the app
  opens the authorization URL in the external browser only after an explicit
  tap, and the user pastes the code shown by Claude after approval. No loopback
  capture, no automatic same-host completion, no embedded web view.
- The bridge sets `BROWSER=true` for the login process on every platform.
  The verified CLI special-cases that value as "no browser" and otherwise
  spawns it as a single executable with the URL, so `true` resolves through
  `PATH` on macOS and Linux (coreutils or busybox). Windows is unverified: a
  stray sign-in tab on the bridge host is an accepted limitation recorded in
  the capability matrix.
- One pasted code per operation. A rejected or wrong code ends the operation
  with a sanitized failure; the user starts a new login. No retry loop.
- Two bounded waits: 90 seconds for the authorization URL to appear, and ten
  minutes overall from spawn to exit.
- Dismissing the sheet does not cancel login. Cancellation is explicit.
- One active operation per plugin; repeated start requests join it (existing
  bridge behavior).
- Operation state is ephemeral and never persisted.
- No new analytics event.

## Explicitly Excluded

- Sesori-managed Claude Code runtime installation or updates (separate plan
  when requested).
- Any change to session launch behavior or to setup inspection beyond the
  `actionHint` copy. The process factory's spawn signature generalizes to a
  neutral launch value, but session arguments, environment, and working
  directory stay identical and remain covered by the existing tests.
- A generic form or free-text challenge framework. The new variant carries
  exactly what this flow needs.
- Detecting mid-turn logout from session errors. The current 401/403 turn
  error mapping is unchanged.
- Pseudo-terminal support in the bridge. The CLI's login runs without a TTY.

## Research And Current Behavior

### Claude CLI login behavior (verified 2026-09-16 on Claude Code 2.1.221, 2.1.269, 2.1.272, and 2.1.273)

Verified against the native binaries and Anthropic's authentication docs.
Every version from the plugin minimum `2.1.221` (the release download,
checksum-verified against its manifest) through `2.1.273` was probed with an
isolated `CLAUDE_CONFIG_DIR`, `BROWSER=true`, and a piped malformed line; all
four print the same manual URL, report the same invalid-code line, keep
listening, and open no browser:

- `claude auth login --claudeai` runs without a TTY. With piped stdio it writes
  to stdout, in order: `Opening browser to sign in…`, then
  `If the browser didn't open, visit: <url>`, then the prompt
  `Paste code here if prompted > ` (no trailing newline). The URL is wrapped in
  an OSC 8 terminal hyperlink (`ESC ] 8 ; ; url BEL url ESC ] 8 ; ; BEL`), so
  the visible URL text appears twice on one line.
- The URL is the manual-return variant: `https://claude.com/cai/oauth/authorize`
  with `code=true`, PKCE `code_challenge`, `state`, and
  `redirect_uri=https://platform.claude.com/oauth/code/callback`. After
  approval that page displays a code for the user to paste. Anthropic documents
  this prompt as the supported path when the browser cannot reach the CLI's
  local callback (SSH, containers, WSL2).
- The CLI reads stdin line by line. A line is trimmed and split on `#` into
  `code#state`; a line without both parts prints
  `Invalid code. Please make sure the full code was copied.` on stderr and the
  CLI keeps listening. A well-formed line triggers the token exchange; success
  prints `Login successful.` and the process exits.
- The process does not exit on stdin EOF or after an invalid code. It must be
  killed to abandon a login.
- The CLI honors the `BROWSER` environment variable: with `BROWSER` set to an
  executable, that executable is invoked with the URL and no system browser
  opens. Read from the binary: the opener is spawned directly as one
  executable with the URL as its only argument (no shell, no word splitting),
  a missing opener is reported as a failure without falling back to the system
  browser, and the CLI's own headless check treats the literal value `true`
  as "no browser".
- Credentials are stored by the CLI under the active config directory
  (`CLAUDE_CONFIG_DIR`, else `~/.claude`): macOS Keychain with an automatic
  fallback to `.credentials.json` (mode 0600) when the Keychain rejects the
  write, and the JSON file on Linux and Windows. Sesori sessions already read
  the same store through the same environment.
- `claude auth status` reports `loggedIn` as JSON; the plugin already uses it.
- The `auth` subcommands exist since roughly Claude Code 2.1.40. The plugin's
  existing minimum `2.1.221` is the oldest verified version, so the existing
  runtime version gate already covers the verified range and no login-specific
  floor is added.
- Verified on 2.1.273 during Step 4, without a real account: a well-formed but
  wrong code fails the exchange, prints `Login failed: …` on stderr, and exits
  1 within a second. The overall budget bounds other versions.

### Current Sesori seams

- Plugin contract: `bridge/sesori_plugin_interface/lib/src/lifecycle/plugin_authentication.dart`
  defines `InteractivePluginAuthenticationDescriptor.authenticate(...)` and the
  sealed `PluginAuthenticationOperation` with exactly two variants:
  `deviceCode(events)` (no continuation) and
  `browser(events, submitRedirect)` (URI continuation). Events are the sealed
  device-code and browser challenges plus shared `Completed` and
  `Failed(message)`.
- Bridge core: `PluginRuntime.authenticate` wraps the operation with a
  generation and abort; `submitAuthenticationRedirect` gates continuations
  (stale generation, wrong kind, already submitted). `PluginLifecycleService`
  owns one operation per plugin, completes the challenge from the first event,
  publishes sealed terminal progress, and re-inspects setup.
  `plugin_authentication_handlers.dart` registers
  `POST /plugin/:id/authentication`, `POST /plugin/:id/authentication/redirect`
  and `DELETE /plugin/:id/authentication`. Terminal progress rides the existing
  `plugin.authentication.progress` SSE event.
- Wire: `shared/sesori_shared/lib/src/models/sesori/plugin_management.dart`
  has `PluginAuthenticationChallengeResponse` (`deviceCode`, `browser`,
  `unknown` fallback), `PluginAuthenticationRedirectRequest`, sealed progress,
  and typed conflicts.
- Client: `PluginApi -> PluginRepository -> PluginManagementService ->
  PluginManagementCubit -> harness settings sheet` in `client/module_core` and
  `client/module_app_ui`. The sheet renders device codes with copy and an
  explicit external-browser action; browser challenges are auto-driven. There
  is no free-text input anywhere in the stack.
- Claude plugin: `ClaudePluginDescriptor` (`bridge/sesori_plugin_claude`) does
  not implement the authentication interface. Setup inspection runs
  `--version` and `auth status` and reports `authenticationRequired` with the
  hint to run `claude auth login` on the machine. Processes are spawned only
  through `HostProcessService` with `includeParentEnvironment: true`; `HOME`
  must never be overridden because it breaks Keychain lookup.
- Capability advertisement is explicit: descriptors that implement the
  interface also list `PluginControlCapability.authentication` in
  `managementCapabilities` (Codex, Antigravity).

## Architecture

### 1. Plugin interface: pasted-code operation

Add a third sealed variant to `PluginAuthenticationOperation` in
`sesori_plugin_interface`:

```text
PluginAuthenticationOperation.pastedCode
  events: Stream<PluginAuthenticationPastedCodeEvent>
  submitCode: Future<void> Function({required String code})

PluginAuthenticationPastedCodeChallenge
  authorizationUri: Uri           // absolute https

PluginAuthenticationCompleted / PluginAuthenticationFailed
  also implement PluginAuthenticationPastedCodeEvent
```

Semantics: the user opens `authorizationUri` in a browser, approves, and
relays the code the provider displays. `submitCode` is called at most once per
operation by the bridge and returns normally once the code has been handed to
the plugin. The plugin validates the backend-specific code shape itself; a
shape it rejects ends the plugin's own operation through its event stream
(`PluginAuthenticationFailed`) rather than through a typed rejection result, so
no rejection type crosses the plugin boundary and the bridge's one-shot gate is
consumed either way. The plugin owns its process lifetime; cancellation arrives
through the existing `StartAbortSignal`.

### 2. Shared wire contract

Backend-neutral additions in `sesori_shared`:

```text
PluginAuthenticationChallengeResponse.pastedCode
  type: "pastedCode"
  authorizationUrl: String

PluginAuthenticationCodeRequest
  code: String                     // maxCodeLength = 512
```

Unchanged: `PluginAuthenticationProgress`, `PluginAuthenticationState`,
`PluginManagementCapability.authentication`, conflict reasons (`noActive`,
`wrongKind`, `alreadySubmitted` are reused), SSE events, and relay framing.
Older clients decode the new challenge as the existing `unknown` fallback, so
no compatibility default or dated marker is needed.

### 3. Bridge runtime, service, and routes

- `PluginRuntime.submitAuthenticationCode({pluginId, generation, code})`
  mirrors `submitAuthenticationRedirect`: stale generation, wrong kind, and
  one-shot checks, with the flag set before the plugin call exactly as the
  redirect path does today. Rename the existing `redirectSubmitted` flag to
  `continuationSubmitted` and share the gate between both continuations so the
  one-shot rule lives in one place. A submission the runtime accepts reports
  success to the client even when the plugin afterwards fails the operation;
  the outcome always arrives as terminal progress.
- The lifecycle repository seam and `PluginLifecycleService` gain the matching
  `submitAuthenticationCode`. `_executeAuthentication` maps
  `PluginAuthenticationPastedCodeChallenge` to
  `PluginAuthenticationChallengeResponse.pastedCode`.
- New handler `PostPluginAuthenticationCodeHandler` for
  `POST /plugin/:id/authentication/code`. Backend-neutral validation before
  the runtime is touched: trim, non-empty, at most 512 characters, no
  whitespace or control characters; otherwise 400. Unknown plugin 404; typed
  409 conflicts with current management metadata, as the redirect route does.
  Success is 200 with `SuccessEmptyResponse` exactly like the redirect route,
  never 204, which the relay client reports as an empty-response error.
- No new SSE event. Terminal progress, the existing generic remote failure
  text in `PluginLifecycleService` ("Authentication failed. Check the bridge
  logs for details."), and setup refresh are unchanged for every plugin.

### 4. Claude plugin authentication layers

All Claude-specific behavior stays in `bridge/sesori_plugin_claude`, following
`Foundation -> API -> Repository -> Service -> Consumer`:

```text
ClaudePastedCode (models)
  tryParse(raw) -> value, or null for any other shape; exactly one "#", both
  parts non-empty, no whitespace, at most 512 characters

ClaudeLoginEnvironment (foundation, constant)
  {BROWSER: "true"} on every platform: the value the CLI itself treats as
  "no browser"; no platform branch, no filesystem probe. Descriptor
  composition injects it into the repository; the service never sees launch
  configuration and the API only executes

HostClaudeProcessFactory (api, existing)
  spawn takes a neutral ClaudeProcessLaunch {binaryPath, arguments,
  workingDirectory, environment overrides} that carries the HOME guard;
  ClaudeLaunchSpec exposes it as processLaunch. The session
  ClaudeProcessFactory seam still receives the spec, and the descriptor
  adapts it with processLaunch, so session behavior and tests are unchanged.
  The login spawns `auth login --claudeai` through the same environment
  merge, Windows shell decision, handle, and signaling. No second wrapper.
  The descriptor composes a dedicated factory instance for the login so its
  spawn outcome stays out of the session health stream

ClaudeLoginOutputParser (repositories/parsers)
  strips ANSI CSI and OSC sequences from a stdout line and returns a sealed
  outcome: none (no https token), found(uri), or invalid (an https token that
  is oversized beyond 16384 characters or does not parse to a URL with a
  host)

ClaudeAuthenticationRepository (repositories)
  constructed with the factory, the binary path, and ClaudeLoginEnvironment;
  owns one ClaudeProcessHandle; decodes stdout and stderr as UTF-8 lines
  start(): builds the ClaudeProcessLaunch (`auth login --claudeai` plus the
  environment override), spawns it through the factory, and returns the
  authorization URL future: found resolves it,
  invalid fails it immediately, none keeps reading; process exit before a URL
  fails it; the service bounds the wait
  submitCode(code): writes "<code>\n" and flushes; the runtime already
  enforces one submission per operation, so no second flag here
  waitForExit(): exit code, counted once both pipes close, because the exit
  can be reported before the last stderr lines arrive
  dispose(): kill (graceful, forced after a short grace), await exit, and
  cancel both pipe subscriptions, which a descendant could hold open;
  idempotent

ClaudeAuthenticationService (services)
  authenticate() -> PluginAuthenticationOperation.pastedCode
  event stream: two bounded waits. URL acquisition is raced against exit
  and abort under a 90-second URL budget (well inside the app's start
  timeout of two and a half minutes); the wait after the challenge is raced
  against exit and abort under the rest of the ten-minute overall budget
  measured from spawn. Each budget is a timeout on its own wait, so its
  timer ends with the wait -> Completed on exit 0, otherwise Failed with one
  fixed message; abort disposes and throws PluginStartAbortedException
  (mapped to cancelled by the bridge); finally always disposes, so no wait
  or timer can outlive the operation
  submitCode: runs ClaudePastedCode.tryParse first; a valid code goes to the
  repository; a rejected shape completes a rejection completer that the exit
  wait also races, so Failed comes from the shape check itself rather than
  from how the stopped CLI exits, and the cause is logged locally without the
  code; finally stops the CLI; submitCode itself returns normally

ClaudePluginDescriptor (runtime)
  implements InteractivePluginAuthenticationDescriptor; composes the layers
  from config (binary), processes, environment, stateDirectory, aborted;
  lists PluginControlCapability.authentication unconditionally (login is a
  CLI action, valid with an explicit bin override too)
```

The plugin's failure message is one fixed sentence and stays local:
`PluginLifecycleService` already logs the plugin message and sends the
existing generic remote text to the client, exactly as for Codex and
Antigravity. The plugin's own warning log keeps the cause (exit code, budget,
or rejected shape), the stack, and a scrubbed stderr tail (the last 20 lines,
escapes stripped, `https://` tokens replaced); stdin content is never logged.

Setup inspection is unchanged except the `actionHint`, which becomes
"Log in from Sesori, or run `claude auth login` on this machine." so older
clients still get a working instruction.

### 5. Client orchestration

Extend the existing layers without new owners:

- `PluginApi.startAuthentication` keeps the ordinary relay post, because the
  typed 409 start conflicts (`inFlight`, `setupNotRequired`, `unsupported`
  with management metadata) are decoded from the response body and the relay
  client's sensitive mode drops every non-2xx body. The accepted consequence
  for a malformed successful body is recorded under Security And Privacy.
  `PluginApi.submitAuthenticationCode` posts to
  `/plugin/:id/authentication/code` and expects the same 200
  `SuccessEmptyResponse` as the redirect route.
- `PluginRepository.submitAuthenticationCode` returns the existing
  `PluginAuthenticationContinuationResult`. The repository challenge model
  gains `pastedCode(authorizationUri)`, validated as absolute HTTPS in the
  repository's challenge mapping like the device-code URL; an invalid URL maps
  to the existing request failure (`PluginAuthenticationFailure.request`),
  not to the cubit-level `invalidChallenge`, which stays reserved for a
  missing challenge.
- `PluginManagementService.submitAuthenticationCode` is fenced by connection
  epoch and bridge identity like the redirect submission. Pasted-code
  challenges are retained like device codes and never auto-driven.
- `PluginManagementService.startAuthentication` keeps tracking the plugin
  after an uncertain start so terminal progress still settles it, but its
  local guard rejects a new start only while a start request is in flight or
  a challenge is already retained. A retry after an uncertain start therefore
  reaches the bridge's existing join behavior and re-publishes the same
  challenge. Today the guard blocks every retry until terminal progress,
  which also affects Codex and Antigravity.
- `PluginManagementCubit` gains `submitAuthenticationCode(code)` and handles
  `launchAuthenticationBrowser` for pasted-code challenges through the existing
  `UrlLauncher`. Presentation adds
  `PluginAuthenticationChallengePresentation.pastedCode` and three states:
  `codeSubmitting`, `codeSubmitted` (awaiting terminal progress), and
  `codeRetry` with a closed reason (`invalidCode`, `notConfirmed`) that keeps
  the field editable. `alreadySubmitted` maps to `codeSubmitted`;
  `invalidInput` maps to `codeRetry(invalidCode)`; an uncertain or failed
  request maps to `codeRetry(notConfirmed)`, so a resubmission either lands or
  reports `alreadySubmitted`; on a bridge `noActive` or `wrongKind` the
  service settles the retained login as unknown and marks management stale,
  which the cubit presents as the existing uncertain failure.
- `PluginManagementService.submitAuthenticationCode` applies the same neutral
  rule as the bridge handler (trim, non-empty, no inner whitespace or control
  characters, bounded length) and returns a typed `invalidInput` outcome
  without sending, so the app never issues a request the handler would reject
  with 400. The rule is `PluginAuthenticationCodeRequest.normalizeCode` in
  `sesori_shared`, which the bridge handler reuses. The existing
  `invalidRedirect` continuation outcome is renamed `invalidInput` because
  both continuations share it. The cubit only translates that outcome into
  the editable field with a hint. Nothing in the client knows the
  `code#state` shape; a code the plugin rejects arrives as ordinary terminal
  failure.

### 6. Presentation (mobile and desktop)

The shared harness authentication sheet in `client/module_app_ui` gains a
pasted-code branch:

- Explains, in harness-neutral wording parameterized by the plugin display
  name, that the user is signing the harness on the connected computer into
  their account and must only continue if they started this login. No
  `Claude` or `claude.ai` literal appears in `module_app_ui` or
  `module_core`; backend identity comes from `setup.displayName` as the
  existing sheet strings do.
- "Open sign-in page" opens the external browser on explicit tap only.
- A single-line code field (autocorrect off, paste friendly) with a
  "Submit code" action enabled when the trimmed text is non-empty. The shared
  `PregoInputField` has no text-style override, so the field keeps the
  design-system font instead of monospace.
- A waiting state after submission; terminal progress closes the sheet and the
  refreshed snapshot removes the login control, exactly as for device codes.
- Cancel remains explicit; dismissal keeps the operation and the challenge
  retrievable from the harness row (`Continue login`).
- Strings live in `client/module_app_ui/lib/src/l10n/app_en.arb` and are
  regenerated; both phone and desktop shells consume the shared sheet.

## Compatibility Matrix

| App | Bridge | Result |
|---|---|---|
| Old | Old | Unchanged: Claude shows authentication required with the local instruction. |
| Old | New | Claude advertises login; the challenge decodes as `unknown` and the existing update-required presentation fails closed. |
| New | Old | No authentication capability for Claude, so no login control. |
| New | New | Pasted-code login, cancel, timeout, and setup refresh work end to end. |

Ordering protects users: the wire contract and the apps merge first, so an app
may ship before any bridge produces the pasted-code challenge; that window
shows no login control. A bridge released before the app update fails closed
with guidance. The bridge core merges before the Claude plugin, so no bridge
advertises a login it cannot route.

## Failure And Recovery Contract

| Failure | User outcome | Local observability |
|---|---|---|
| CLI exits before printing a URL (policy block, broken binary) | Sanitized failure; login remains required. | Exit code and scrubbed stderr tail stay in bridge logs. |
| No HTTPS URL in stdout | No challenge; the start fails on process exit or after the 90-second URL budget, the CLI is killed, and the app's start request returns failure before its own timeout. | Exit code or URL budget expiry with scrubbed stderr. |
| HTTPS token oversized or unparsable | Immediate typed failure; nothing is presented. | Typed parser outcome with line length, never the line. |
| Pasted text fails the neutral rule (empty, inner whitespace, oversized) | The app keeps the field editable with a hint; the bridge handler answers 400 only to clients that bypass the app. | Request rejection only. |
| Code passes the neutral rule but the plugin rejects its shape | The plugin kills its CLI; the operation ends with the generic failure text; the user starts a new login. | Local log names the shape rejection without the code. |
| Well-formed but wrong code | CLI exchange fails and the CLI exits 1 (verified on 2.1.273): generic failure; the ten-minute budget bounds other versions. User starts a new login. | Exit code, budget expiry, scrubbed stderr. |
| App loses the start response | The app shows the uncertain state; a retry is allowed once the start request is no longer in flight and rejoins the active bridge operation, which returns the same challenge. Terminal progress still settles the tracked plugin. | Existing relay diagnostics. |
| App loses the code response | Retry reports `alreadySubmitted`, shown as waiting. | Existing conflict logging. |
| App backgrounds or is killed while in the browser | Bridge operation continues for its budget; reopening joins it and accepts the code. | Existing management refresh. |
| User cancels | CLI is killed; cancelled progress; setup re-inspected. | Cancel request and settlement stay local. |
| Bridge shuts down or restarts | Abort kills the child before disposal; after restart the operation is gone and setup truth is re-inspected. | Shutdown context stays local. |
| Login exits 0 but setup still reports authentication required (for example a config-directory mismatch) | App does not claim success; refreshed setup guidance shows. | Exit code plus reinspection result stay local. |
| macOS Keychain locked for the bridge process | CLI stores the credential in its file fallback, which sessions read too. | CLI stderr, scrubbed. |

## Security And Privacy

- The authorization URL (client id, PKCE challenge, state) and the pasted
  code (a one-time authorization code plus state) are the only login data
  crossing the relay, over the existing authenticated end-to-end channel. They
  are never logged, persisted, included in errors, replayed over SSE, or sent
  to analytics.
- Sesori never performs the token exchange, never reads or writes Claude's
  credential store, and never sets `CLAUDE_CODE_OAUTH_TOKEN` or
  `ANTHROPIC_API_KEY`.
- The login process inherits the bridge environment unchanged except
  `BROWSER`; `HOME` is never overridden, so the credential lands where sessions
  already look.
- Both bridge and client require an absolute HTTPS authorization URL. No host
  allowlist is added, matching the Codex decision: the URL originates from the
  user-trusted local CLI binary and Anthropic has already moved domains once.
- The code is bounded, whitespace-free, written to the CLI's stdin as one line,
  and never echoed.
- The sheet keeps the anti-phishing framing: continue only if you started this
  login from Sesori.
- Remote failures carry only the bridge's existing generic text. Local logs
  retain plugin-authored messages, exit codes, operation context, and scrubbed
  diagnostics.
- Accepted: a malformed successful challenge body from a defective bridge is
  retained in the local client parsing error, exactly as for the device-code
  and browser challenges today. The authorization URL carries no credential
  (client id, PKCE challenge, state) and cannot complete a login without the
  user's paste channel, and client logs stay local and user-controlled. The
  relay client's blanket sensitive mode is not used because it also drops the
  typed 409 conflict bodies the start flow decodes; a selective redaction mode
  in shared client infrastructure is not worth building for a bridge defect.

## Analytics

No new event. This matches the Codex and Antigravity login decisions; a
harness-login outcome event can be proposed separately if adoption questions
arise.

## Complexity Budget

### New or changed mutable parts

- Bridge core: the existing per-operation continuation flag, renamed and
  shared by both continuation kinds. No new registry, timer, or queue.
- Claude plugin, per operation and disposed in `finally`: one process handle,
  one composite subscription for its two pipes, completers for the
  authorization URL and the drained exit code, one memoized disposal future, a
  bounded stderr tail, and two budgets that are timeouts on their waits
  (URL, overall). The
  one-shot rule stays with the runtime gate; the repository holds no second
  flag. A rejected code shape completes one rejection completer in the
  service, because inferring the failure from the stopped CLI's exit code
  made the outcome depend on how the CLI handles a graceful stop.
  `ClaudeLoginEnvironment` is a constant; `ClaudePastedCode` is pure.
- Client: three immutable presentation states and one text controller inside
  the sheet.

### Deliberately not added

- Pseudo-terminal support; stderr-driven control flow; a retry loop after a
  rejected code; a per-submission timer beyond the URL and overall budgets.
- Same-host automatic completion through the CLI's localhost callback.
- Console, SSO, API-key, or long-lived token modes; logout; login while ready.
- Persistence of the operation or challenge; reconnect reconciliation beyond
  the existing epoch fencing.
- A generic form challenge framework.

## Cleanup Assessment

- The Claude `actionHint` copy changes with the plugin step (older clients
  still receive a valid instruction).
- `docs/HARNESS_CAPABILITIES.md` Claude login row moves from "Not implemented"
  to implemented with the Windows host-browser limitation, in Step 4.
- No obsolete code, fields, routes, or tests were found.

## Proportionality And Accepted Risk

| Decision | Evidence level | If omitted | Chosen response |
|---|---|---|---|
| Drive the official CLI | Verified CLI behavior without a TTY on every version from the plugin minimum 2.1.221 to 2.1.273 | Sesori would own tokens, Keychain writes, and third-party use of Claude Code's client id | Pipe the CLI; treat exit code as authoritative and setup reinspection as truth |
| Paste-code flow everywhere | Anthropic documents it as the remote path; the phone can never reach the host's localhost callback | Mobile login impossible; desktop would need loopback machinery | One flow, one sheet variant |
| Suppress host browser | Verified: the CLI spawns `BROWSER` as one executable and special-cases the value `true`; Antigravity precedent | Confusing or unattended sign-in tab on the bridge host | `BROWSER=true` everywhere; Windows unverified and documented; no bridge-owned helper because the CLI spawns a single executable without a shell |
| URL budget of 90 seconds plus ten minutes overall | The app's start request times out at two and a half minutes; the CLI prints the URL within seconds; users need minutes to approve and paste; the CLI never exits on its own | A single budget would keep a URL-less CLI alive for ten minutes after the app already reported failure | Two bounded waits; no per-submission timer |
| No cancel before the challenge | Pre-existing shared sheet behavior for every plugin; the URL budget bounds the non-cancellable window to 90 seconds in the abnormal no-URL case | Cancelling an in-flight start needs a cancel/start race in the service | Accept; documented |
| Terminal failure on rejected code | Restarting costs a few taps; the CLI's own shape check is mirrored; the provider page's copy action yields the full code | A typed rejection would need a new interface result, a wire conflict reason, and client state | Plugin fails the operation from its shape check and stops its CLI; no retry loop |
| Generic remote failure text | Existing lifecycle behavior for Codex and Antigravity; plugin detail stays in local logs | Distinguishing timeout from rejection remotely needs a lifecycle change for every plugin | Accept; no lifecycle change |
| Ordinary relay post for the start request | Typed 409 conflicts are decoded from the body; a malformed successful body needs a bridge defect and leaks no credential | The blanket sensitive mode breaks conflict handling; a selective mode adds shared infrastructure for a theoretical case | Accept the local parsing-error residue; no new client mode |
| Login only when authentication required | Parity with Codex | Re-login while ready | Excluded |
| No persistence | Credentials are durable in the CLI; setup inspection recovers truth | Bridge restart loses only the challenge | Accept |
| No stderr parsing | Wording changes across versions; exit code is stable | Slightly less specific messages | Accept |

## Regression Coverage

Affected feature documents:

- New `docs/regression/claude-code-authentication.md` (this capability).
- `docs/regression/plugin-setup-and-lifecycle.md` (shared sheet gains the
  pasted-code variant; unknown challenges still fail closed).
- `docs/HARNESS_CAPABILITIES.md` login row for Claude.

Coverage levels for the new document:

| Level | Coverage added |
|---|---|
| L1 | Automated: Claude descriptor advertises authentication; contract and mapper unit tests. |
| L2 | Automated: fake CLI through `PluginLifecycleService` and route handlers (challenge, code, exit paths); sheet widget tests on phone and desktop. |
| L3 | Real login from the iOS app and from the macOS desktop app against a macOS arm64 bridge running the real `claude` CLI with a real claude.ai account; `claude auth status` reports logged in afterwards and a Claude session starts from Sesori; explicit cancel mid-flow. |
| L4 | Linux headless bridge (credentials-file path); wrong code; timeout; older app against new bridge (update required); bridge restart mid-login; explicit `bin` override; supervised desktop bridge Keychain write. |
| L5 | Windows bridge (accepted host-browser tab) and Android app. |

**Highest required level before retirement:** L3 with the matrix
{iOS app, macOS desktop app} x {macOS arm64 bridge, real claude.ai account}.
Evidence stays privacy safe (no URLs, codes, emails, or tokens). Any reduction
requires explicit user acceptance recorded here.

## Delivery Rules

- Six PRs, titles fixed below under slug `claude-code-login`; merge in order.
- Step 1 raises this plan and tracker. Step 4 lands the capability-matrix row
  and the new regression document together with the behavior, so `main` is
  never knowingly stale. Step 5 reconciles the shared regression documents and
  completes coverage. Step 6 runs the recorded level and matrix, records
  evidence in the tracker, and moves this directory to
  `.plan/completed/claude-code-login/`.
- Sealed challenge and presentation types force every exhaustive
  in-repository consumer to change with its contract. The wire variant
  therefore ships with all client consumers in Step 2, and the
  plugin-interface variant with all bridge-core consumers in Step 3. No
  temporary mapping bridges a split.
- Soft cap 1,500 changed lines per PR including generated output and tests;
  split before opening a step that cannot fit.
- Generated Freezed, JSON, and localization output changes only through the
  generators.
- Claude-specific commands, output parsing, code shape, budget, environment,
  and error wording stay inside `sesori_plugin_claude`.
- Architecture implementation review for Steps 2, 3, and 4. Steps 5 and 6 are
  documentation and verification only.
- Later phases: none. Managed Claude runtime installation is out of scope and
  gets its own plan if requested.

## Fixed PR Series

| Step | Title |
|---|---|
| 1/6 | `🌱 [claude-code-login] Publish the plan [step 1/6]` |
| 2/6 | `🚧 [claude-code-login] Add pasted-code login to the wire contract and apps [step 2/6]` |
| 3/6 | `🚧 [claude-code-login] Route pasted-code login through the bridge [step 3/6]` |
| 4/6 | `🚧 [claude-code-login] Drive Claude CLI login from the bridge [step 4/6]` |
| 5/6 | `🌱 [claude-code-login] Reconcile Claude login documentation [step 5/6]` |
| 6/6 | `🌱 [claude-code-login] Verify and retire the plan [step 6/6]` |

## Step 1/6 — Publish The Plan

### Scope

`PLAN.md` and `TRACKER.md` under `.plan/active/claude-code-login/`.

### Verification

Architecture plan review through a sub-agent; findings applied directly.

## Step 2/6 — Add Pasted-Code Login To The Wire Contract And Apps

Complexity 🚧: a sealed wire variant plus every client layer that switches on
it, a new sheet variant, and localization.

### Scope

- `shared/sesori_shared/lib/src/models/sesori/plugin_management.dart`:
  `pastedCode` challenge variant and `PluginAuthenticationCodeRequest` with
  regenerated output.
- `client/module_core`: `plugin_api.dart` (code submission),
  `plugin_repository.dart`,
  `repositories/models/plugin_management_result.dart`,
  `services/plugin_management_service.dart`,
  `cubits/plugin_management/plugin_management_cubit.dart` and state.
- `client/module_app_ui`: `features/settings/harness_settings_sheets.dart`
  pasted-code branch, `l10n/app_en.arb` harness-neutral strings parameterized
  by display name, and regenerated localizations.
- Tests: shared wire JSON contract including the `unknown` fallback for the
  new type; API contract including that start conflicts still decode their
  409 bodies; service orchestration (fencing, neutral input rule returns
  `invalidInput` without a request, continuation results, a retry after an
  uncertain start rejoins the active operation and re-publishes the same
  challenge); cubit transitions
  (launch, invalid input keeps the field editable, submit, conflicts,
  terminal); phone and desktop settings widget tests (open
  on explicit tap only, submit enabled by valid text, waiting state, cancel,
  update-required unchanged).

The sealed challenge and presentation types make every exhaustive consumer
change with the contract, so no smaller compiling split exists without a
temporary mapping. Expect the diff near the soft cap; report generated
(Freezed, JSON, localization) versus authored churn in the PR body.

### Verification

`dart analyze` and `dart test` in `sesori_shared`; `flutter analyze` and
targeted tests in `module_core`, `module_app_ui`, `client/app`, and
`client/desktop`; codegen clean. No user-visible change until a bridge
produces the variant; older bridges remain unaffected.

## Step 3/6 — Route Pasted-Code Login Through The Bridge

Complexity 🚧: plugin-interface variant, continuation gating, and a new route
across runtime, service, and routing layers.

### Scope

- `bridge/sesori_plugin_interface/lib/src/lifecycle/plugin_authentication.dart`:
  `pastedCode` operation, event interface, challenge event.
- `bridge/app/lib/src/runtime/plugin_runtime.dart`, the lifecycle repository
  seam, `bridge/app/lib/src/services/plugin_lifecycle_service.dart`,
  `bridge/app/lib/src/routing/plugin_authentication_handlers.dart` and route
  registration: `submitAuthenticationCode`, shared one-shot gate, challenge
  mapping, new POST handler with neutral validation and the 200
  `SuccessEmptyResponse` success body.
- Tests: interface contract, runtime gate matrix (stale, wrong kind, already
  submitted, aborted), lifecycle service mapping and terminal progress with a
  fake pasted-code descriptor, handler status matrix (200, 400, 404, 409).

### Verification

`dart analyze` and targeted `dart test` in `sesori_plugin_interface` and
`bridge/app`. No user-visible change until a plugin produces the variant.

## Step 4/6 — Drive Claude CLI Login From The Bridge

Complexity 🚧: process lifecycle, security-sensitive output handling, and
cancellation.

### Scope

- `bridge/sesori_plugin_claude`: `ClaudePastedCode`,
  `ClaudeLoginEnvironment`, `ClaudeLoginOutputParser`, the neutral
  `ClaudeProcessLaunch` consumed by the existing `HostClaudeProcessFactory`
  (with `ClaudeLaunchSpec` exposing its launch and session behavior
  unchanged), `ClaudeAuthenticationRepository`, `ClaudeAuthenticationService`,
  descriptor composition, capability, and the `actionHint` copy.
- Tests with the existing fake `HostProcessService` and scripted
  `SpawnedProcess` pattern: OSC 8 and fragmented URL lines; exit before URL;
  parser outcomes none, found, and invalid (oversized or unparsable https
  token fails immediately); session launch arguments unchanged through the
  generalized factory; exit 0 after code; non-zero exit; URL budget expiry
  before a challenge and overall budget expiry after it; abort during wait
  and during submit; code shape rejection kills the process,
  returns normally, and the stream emits `Failed`;
  `BROWSER=true` present in the spawned environment; `HOME` untouched; stdin
  receives exactly `code\n`; log capture proves no URL or code is logged.
- Manual check on the developer machine with an isolated `CLAUDE_CONFIG_DIR`
  through the bridge routes.
- `docs/HARNESS_CAPABILITIES.md` Claude login row and the new
  `docs/regression/claude-code-authentication.md` (including the isolated CLI
  probe and the versions it verified, to re-run on plugin version bumps), so
  the capability is documented in the same PR that exposes it.

### Verification

`dart analyze` and `dart test` in `sesori_plugin_claude`; targeted bridge app
tests if composition changes. User-visible result: Claude shows `Log in` when
authentication is required and completes login from the app.

## Step 5/6 — Reconcile Claude Login Documentation

### Scope

Update `docs/regression/plugin-setup-and-lifecycle.md` for the shared sheet
variant and complete `docs/regression/claude-code-authentication.md` with the
coverage entries and failure signals observed during Step 4's manual checks.

### Verification

Documentation review only.

## Step 6/6 — Verify And Retire

### Highest required level

L3.

### Required matrix

{iOS app, macOS desktop app} x {macOS arm64 bridge with real `claude` CLI and
a real claude.ai account}. L4 and L5 rows run when infrastructure is available
and are reported honestly as `Not run` otherwise.

### Acceptance

Every L1 through L3 entry passes across the matrix with privacy-safe evidence
recorded in `TRACKER.md`; then move the directory to
`.plan/completed/claude-code-login/`.

## Material Risks

- CLI output may change across versions. The parser keys on the first
  absolute HTTPS URL in stdout, not on prose, and the exit code is
  authoritative; a missing URL fails within the URL budget. The verified
  versions are recorded above and the probe lives in the regression document,
  so a plugin version bump re-runs the probe on the new minimum and target
  versions plus one L3 login.
- The wrong-code exit behavior is verified only on 2.1.273 (exit 1); the
  budget bounds other versions and the L4 wrong-code check re-verifies it.
- Keychain writes from a supervised or launchd-started bridge on macOS rely on
  the CLI's file fallback when the Keychain is locked; the L4 supervised
  desktop check covers it.
- Organization policies (`forceLoginMethod`, org restrictions) can reject the
  login; the CLI exits non-zero and the failure stays sanitized.
- The `BROWSER=true` convention and the single-executable spawn were read
  from the 2.1.273 binary, and the probe confirmed that `BROWSER=true` opens
  nothing on 2.1.221, 2.1.269, and 2.1.272 as well. A future CLI that fell
  back to the system browser
  on a missing opener would only affect systems without `true` on `PATH`;
  the L3 login re-verifies that no host browser opens after CLI upgrades.

## Plan Review Record

2026-09-16: `architecture-plan-review` (sub-agent) rejected the first draft
with four must-fix findings and two optional ones. All six were applied in the
same step and, per repository rules, the fixes were not re-reviewed:

- Undefined outcome for a plugin-rejected code shape: the plugin now ends its
  own operation through its event stream by disposing the CLI; the one-shot
  gate is consumed; no rejection type crosses the plugin boundary.
- Backend identity in shared UI copy: sheet strings are harness-neutral and
  parameterized by display name.
- Platform and filesystem decisions in the API layer: moved to the pure
  `ClaudeLoginEnvironment` resolved by the descriptor composition; the API only
  executes.
- Plugin failure wording that never crosses the wire: plugin messages are
  local-log-only; the existing generic remote text is unchanged.
- Optional: `ClaudeLoginOutputMapper` renamed `ClaudeLoginOutputParser`; the
  invalid-URL path is named as the repository request failure rather than the
  cubit's `invalidChallenge`.

Considered by the reviewer and declined on proportionality: unifying both
continuation methods behind a sealed payload, a separate per-operation class
as in Antigravity, a URL host allowlist, persistence, reconnect
reconciliation, a retry loop, and a guard for an orphaned login under an old
app (bounded by the budget and abort).

2026-09-16, PR #1508 automated review (cubic, Codex): seven findings, all
applied in the same step:

- The series order was wrong for sealed types: adding the wire variant breaks
  the client's exhaustive challenge switch, so the wire contract and all
  client consumers now ship together in Step 2, and the plugin interface with
  the bridge core in Step 3.
- The compatibility ordering sentence stated the opposite of the guarantee it
  meant; it now names the real windows.
- The no-host-browser success criterion is scoped to macOS and Linux.
- The ten-minute budget starts at spawn and bounds URL acquisition as well as
  completion, so a CLI that never prints a URL cannot outlive the operation.
- The capability-matrix row and the new regression document land with the
  plugin in Step 4; Step 5 reconciles the shared documents.
- The start request was moved to the relay client's sensitive-response path;
  superseded by the second wave below.
- The code route returns 200 with `SuccessEmptyResponse`, never 204.

2026-09-16, PR #1508 second automated review wave (Codex): two findings,
both applied:

- The sensitive-response path also drops every non-2xx body, which the start
  flow needs to decode typed 409 conflicts. The start request stays on the
  ordinary post; the malformed-successful-body residue is recorded as an
  accepted risk under Security And Privacy instead of adding a selective
  redaction mode to shared client infrastructure.
- Host-browser suppression no longer depends on fixed paths. Reading the
  binary showed the CLI spawns `BROWSER` as a single executable without a
  shell, reports a missing opener without falling back to the system browser,
  and special-cases the value `true`. The plugin now sets `BROWSER=true` on
  every platform, which removes the filesystem probe and the platform branch;
  Windows stays documented as unverified. A bridge-owned no-op like
  Antigravity's was rejected because the bridge invocation is multi-word in
  source mode and the CLI does not split words.

2026-09-16, PR #1508 third automated review wave (cubic, Codex): six
findings, all applied:

- The tracker still recorded the fixed-path browser no-op; it now matches
  `BROWSER=true`.
- Neutral code validation moved from the cubit to
  `PluginManagementService`, which returns a typed `invalidInput` outcome
  the cubit only presents.
- The no-logging success criterion now carries the accepted malformed-body
  exception instead of contradicting it.
- The separate `ClaudeAuthLoginApi` was dropped. The existing
  `HostClaudeProcessFactory` takes a neutral `ClaudeProcessLaunch` so session
  and login share one spawn path; session behavior is unchanged.
- The output parser returns a sealed none, found, or invalid outcome so an
  oversized or unparsable HTTPS token fails immediately while ordinary lines
  keep the wait going.
- The repository's second one-shot flag was removed; the runtime gate is the
  single owner of the one-submission rule.

2026-09-16, PR #1508 fourth automated review wave (Codex): three findings,
all applied:

- Version coverage: the flow had been verified only on 2.1.273 while the
  plugin accepts 2.1.221. The release binaries for 2.1.221 (checksum-verified
  against its manifest), 2.1.269, and 2.1.272 were probed the same way and
  behave identically, so the existing minimum-version gate covers the verified
  range; no login-specific floor is added, and the probe is recorded in the
  regression document for future version bumps.
- The failure table promised a rejoin after an uncertain start that the
  client does not offer: the service keeps the plugin tracked and rejects
  every retry until terminal progress. Step 2 narrows that guard to in-flight
  starts and retained challenges so a retry rejoins the active bridge
  operation, with a test.
- Cancel is unavailable before the challenge arrives, and the app's start
  request times out at two and a half minutes, well inside the ten-minute
  budget. The plugin now bounds URL acquisition at 90 seconds so a URL-less
  CLI fails before the app's timeout; the pre-existing no-cancel window is
  accepted and recorded in the proportionality table instead of adding a
  cancel/start race to the service.

2026-09-16, PR #1508 fifth automated review wave (Codex, cubic): two
findings, both applied:

- Launch configuration skipped a layer: the service handed
  `ClaudeLoginEnvironment` to the API. Descriptor composition now injects the
  environment and the binary path into `ClaudeAuthenticationRepository`,
  which builds and spawns the `ClaudeProcessLaunch`; the service depends only
  on the repository.
- The "single budget" phrase under Deliberately not added was stale after the
  fourth wave; it now names the URL and overall budgets.
