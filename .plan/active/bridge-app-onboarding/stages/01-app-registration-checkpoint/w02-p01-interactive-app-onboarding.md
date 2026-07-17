# S01-W02-P01: Add Bounded App Onboarding

## Metadata

- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Base:** `main`
- **Pinned SHA:** `4a156a78b3bf8572c280ce859b3b1370300a8105`
- **Branch:** existing `bridge-onboarding-plan` worktree branch
- **Dependency:** auth-server PR #44 must deploy before bridge release

## Goal

Add a one-time-per-backend/account standalone onboarding checkpoint with the
smallest possible bridge change. If the account has not previously confirmed an
app, perform one immediate status check and at most one 30-second long poll while
showing a bounded terminal QR and exact URL.

## Implementation

1. Add `qr` to `bridge/app` and update `bridge/pubspec.lock` normally.
2. Add bridge-local Freezed `AppClientStatusResponse(registered: bool)` under
   `src/api/` and run bridge code generation.
3. Add provider-level `SesoriServerApi` under `src/api/` with only the new status
   operation. It borrows the runner's shared HTTP client, uses the configured
   auth base, bearer header, strict model, and a request-local abortable 35-second
   deadline that closes the underlying request and cleans its timer in every
   completion path. Do not migrate any legacy auth operation into this boundary.
4. Add `AppClientStatusRepository` under `src/repositories/` with three outcomes:
   registered, absent, and unavailable. Keep the dated/versioned 404/405
   compatibility marker here.
5. Add `AppOnboardingStateStorage` for raw exists/write/clear-all operations over
   a marker directory under the existing Sesori data directory. Require 0700
   directory and 0600 file permissions on Unix. Add
   `AppOnboardingStateRepository` to derive an opaque SHA-256 key from a
   UTF-8 JSON encoding of `[normalizedAuthBackend, userId]` and map
   present/absent/read-failure outcomes. One empty file is retained per confirmed
   pair; read failures warn and still perform the remote status check, and never
   count as present. A later true response still attempts the idempotent marker
   write; read and write failures remain independently observable.
6. Add `AppOnboardingFormatter` for the exact URL and bounded ANSI+Unicode QR.
7. Add `AppClientOnboardingService`. It receives the existing authenticated
   access token and configured auth backend, derives `userId` via
   `parseJwtUserId`, and warns/fails open without a marker or status request when
   that result is null. Otherwise it checks the backend-scoped marker, runs the
   immediate request, optionally prints guidance and runs one long poll, and
   fails open on every failure. It has no retry, skip, stdin, or token refresh.
8. In `BridgeRuntimeRunner`, compose and invoke the service only when standalone
   and `TerminalPromptApi.isInteractive`, after plugin availability and before
   plugin startup/mutex/provisioning. Pass the already authenticated token.
9. Inject `AppOnboardingStateRepository` into `BridgeLogoutRunner`. After logout
   is accepted, clear all onboarding markers and then tokens. If state deletion
   fails, return the existing failed result and leave tokens intact. Cancelled
   logout performs neither operation.

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
- Same `userId` on a different configured auth backend: status check runs.
- A -> B -> A: each pair checks once; confirming B does not replace A's flag.
- Different/unmarked account: immediate check runs.
- Immediate true: marker written, silent continuation.
- Immediate false: guidance, QR-or-URL, exact URL, then exactly one long poll.
- Long-poll true: marker written, one success line.
- Long-poll false: one continuation line, no marker, startup continues.
- Marker-read failure: one warning, remote check continues, and a later true
  response still attempts the marker write.
- Remote or marker-write failure: one warning for that failed operation, no new
  marker from that operation, and startup continues.
- Supervised/noninteractive/plugin-unavailable paths never call the endpoint.
- Accepted logout clears all markers before tokens; state-clear failure is
  observable and leaves tokens intact; cancelled logout preserves both.
- Strict analyzer, focused tests, host build, and architecture implementation
  review pass with no changes outside the declared paths.
