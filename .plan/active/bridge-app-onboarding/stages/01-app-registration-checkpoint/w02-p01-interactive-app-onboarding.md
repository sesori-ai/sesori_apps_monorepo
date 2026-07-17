# S01-W02-P01: Add Bounded App Onboarding

## Metadata

- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Base:** `main`
- **Pinned SHA:** `4a156a78b3bf8572c280ce859b3b1370300a8105`
- **Branch:** existing `bridge-onboarding-plan` worktree branch
- **Dependency:** auth-server PR #44 must deploy before bridge release

## Goal

Add a one-time-per-account standalone onboarding checkpoint with the smallest
possible bridge change. If the account has not previously confirmed an app,
perform one immediate status check and at most one 30-second long poll while
showing a bounded terminal QR and exact URL.

## Implementation

1. Add `qr` to `bridge/app` and update `bridge/pubspec.lock` normally.
2. Add bridge-local Freezed `AppClientStatusResponse(registered: bool)` and run
   bridge code generation.
3. Add `AppClientStatusApi` for only the new endpoint. It borrows the runner's
   shared HTTP client, uses the configured auth base, bearer header, strict model,
   and 35-second timeout.
4. Add `AppClientStatusRepository` with three outcomes: registered, absent, and
   unavailable. Keep the dated/versioned 404/405 compatibility marker here.
5. Add `AppOnboardingStateStorage` for raw read/write/clear of one marker file under
   the existing Sesori data directory. Add `AppOnboardingStateRepository` to map
   missing/matching/different/invalid state.
6. Add `AppOnboardingFormatter` for the exact URL and bounded ANSI+Unicode QR.
7. Add `AppClientOnboardingService`. It receives the existing authenticated
   access token, derives `userId` via `parseJwtUserId`, checks the marker, runs
   the immediate request, optionally prints guidance and runs one long poll, and
   fails open on every failure. It has no retry, skip, stdin, or token refresh.
8. In `BridgeRuntimeRunner`, compose and invoke the service only when standalone
   and `TerminalPromptApi.isInteractive`, after plugin availability and before
   plugin startup/mutex/provisioning. Pass the already authenticated token.
9. Inject `AppOnboardingStateRepository` into `BridgeLogoutRunner`. After logout
   is accepted, clear tokens and then the onboarding marker. Cancelled logout
   performs neither operation.

## Guardrails

- Do not edit existing auth APIs/functions except imports needed by composition.
- Do not edit `TokenManager`, `TokenRefresher`, token persistence, runtime auth,
  terminal prompt classes, control-channel token code, push, metadata,
  registration, orchestrator, shared models, clients, plugins, or relay code.
- Do not add async stdin, cancellation plumbing, retries, generic abstractions,
  aliases, migration wrappers, or compatibility layers beyond the endpoint's
  404/405 branch.
- If implementation requires any unexpected production file, stop and ask
  before expanding scope.

## Acceptance

- Same marked account: no status call and no output.
- Different/unmarked account: immediate check runs.
- Immediate true: marker written, silent continuation.
- Immediate false: guidance, QR-or-URL, exact URL, then exactly one long poll.
- Long-poll true: marker written, one success line.
- Long-poll false: one continuation line, no marker, startup continues.
- Any failure: at most one warning, no marker, startup continues.
- Supervised/noninteractive/plugin-unavailable paths never call the endpoint.
- Accepted logout clears marker; cancelled logout preserves it.
- Strict analyzer, focused tests, host build, and architecture implementation
  review pass with no changes outside the declared paths.
