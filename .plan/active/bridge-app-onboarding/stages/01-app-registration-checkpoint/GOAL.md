# Stage S01: App Registration Checkpoint

## 0. Stage Metadata

- **Stage ID:** S01
- **Status:** Pending
- **Repositories:** `sesori-ai/sesori_auth_server`, `sesori-ai/sesori_apps_monorepo`
- **Implementation bases:** auth server `master`; monorepo `main`
- **PR count:** 2
- **Manual checkpoints:** 1 advisory

## 1. Outcome

The auth server exposes a race-safe authenticated current-app-registration
status and wakes long polls only after durable token registration. The
standalone interactive bridge consumes that endpoint before plugin startup,
renders bounded terminal setup guidance only when needed, and waits until the
same account registers or the user explicitly skips the current run.

Transient failures retry at a fixed one-minute cadence without warning spam;
unsupported/permanent protocol failures remain backward-compatible and fail
open. Supervised and noninteractive bridge paths remain unchanged.

## 2. Entry Criteria and Baseline

- The complete plan tree is approved and delivered through the user's selected
  delivery mode.
- Before W01, the worker fetches auth-server `master`, assesses drift from
  `b17a6e760b0c70c3dc3d1cd456ff93d814c75453`, and records the exact assessed tip
  as S01/W01's auth-server baseline in `TRACKER.md` before branch creation.
- W02 starts only after S01-W01-P01 merges. Its worker fetches monorepo `main`,
  assesses drift from `5a76c0c420cd7db445f7fe2c8a2570265b4c84e0`
  plus the now-merged auth contract, and records the exact monorepo baseline.
- The worker re-reads repository/workspace `AGENTS.md`, `docs/VISION.md`,
  `docs/ROADMAP.md`, the current bridge version, and touched tests after pinning
  each wave.
- The independent `session-pull-request-monitoring` plan has no semantic conflict
  at audit. Any newly merged overlap is assessed rather than assumed safe.

## 3. Invariants and Non-Goals

- Dependencies flow Foundation -> API/Repository -> Service -> Consumer; no
  repository depends on a repository peer and no route constructs dependencies.
- Auth-server token upsert commits before presence wake; failed writes never wake.
- Waiter registration and repository recheck are race-safe; every terminal path
  removes timers/listeners/map state.
- The server's 30-second wait is one absolute deadline beginning before the
  initial repository read; reads and waiter time do not each receive a new cap.
- The bridge uses its configurable auth backend and existing token authority.
- No startup mutex, plugin runtime, relay, or backend process is held while the
  user waits.
- Normal server long-poll expiry is not a failure and has no retry delay/log.
- Transient failures use exactly one cancellable 60-second delay and one warning
  per attempt; permanent failures warn once and fail open.
- Terminal input has one asynchronous owner with FIFO pending-line preservation
  across sequential prompts; raw single-key mode, lossy broadcast handoff, and
  mixed synchronous/asynchronous stdin are forbidden.
- `TerminalPromptApi` exposes raw terminal facts/I/O only.
  `BridgeStartupOrchestrator` (and the independent logout composition) resolves
  typed `TerminalInteractionMode` and injects it into
  `TerminalPromptRepository`; runner owns no terminal policy.
- Access-token acquisition and one-refresh-on-401 coordination belong to
  `AppClientOnboardingService`; `AppClientPresenceRepository` only maps its API
  using the caller-supplied token.
- `SesoriAuthApi` is the sole per-provider API owner for Sesori auth HTTP. The
  bridge PR migrates existing auth use-case APIs/top-level HTTP operations into
  it and deletes those old boundaries rather than adding a presence wrapper.
- `TokenRefresher` carries required named `forceRefresh` and auth-local
  `AuthRequestCancellationSignal`. Both the renamed `TokenService` and
  `ControlChannelTokenService`, every production caller, and every fake implement
  it; typed refresh failures require no message parsing.
- Onboarding skip actively aborts app-status and in-flight token-refresh
  requests. No request or correlated control pull survives service completion.
- Root Layer-5 `BridgeStartupOrchestrator` owns all auth/terminal/token/
  onboarding construction and pre-plugin sequencing. `BridgeRuntimeRunner`
  receives direct already-built runtime/failure/restart/supervised collaborators
  and constructs no lower layer; existing session `Orchestrator` remains the
  post-plugin control owner.
- The URL is always present when onboarding is shown; QR requires proven ANSI+
  Unicode, explicit black/white polarity, and sufficient known width.
- Generated files are regenerated from source and never hand-edited.
- No persistence migration, app/client UI, browser opening, live heartbeat,
  distributed waiter, analytics, or speculative abstraction is included.

## 4. Execution Waves

| Wave | ID | PR/check | Repository | Base | Can run in parallel | Merge barrier |
|---|---|---|---|---|---|---|
| W01 | S01-W01-P01 | Add app-client presence endpoint | `sesori-ai/sesori_auth_server` | `master` | N/A | Must merge before W02 starts |
| W02 | S01-W02-P01 | Add interactive bridge app onboarding | `sesori-ai/sesori_apps_monorepo` | `main` | N/A | Must merge before stage exit |
| W02 | S01-W02-M01 | Advisory terminal QR/app-registration check | Cross-repository deployed result | N/A | May run after artifacts/deploy are available | Advisory; never blocks |

## 5. Integration and Manual Verification

- Server route tests prove an absent waiter wakes from the existing app token
  registration endpoint only after the Mongo upsert succeeds.
- Bridge integration tests drive immediate present/absent, long-poll expiry,
  post-start registration, old-server 404, 401 refresh, network failure, fixed
  delay, skip during request/delay, and terminal EOF.
- Runner tests prove the checkpoint is after authentication/plugin availability
  but before mutex/provision/plugin start and is absent from supervised or
  noninteractive paths.
- Existing auth, token registration/deletion, provider/email login, replacement,
  logout, plugin startup, and bridge registration tests remain green.
- S01-W02-M01 scans the exact QR/URL and records platform/theme/width evidence
  when available. Missing platform hardware leaves a checkbox unchecked and does
  not block the stage.

## 6. Exit Criteria

- S01-W01-P01 is merged to auth-server `master`, deployed before bridge release,
  and its server verification passes.
- S01-W02-P01 is merged to monorepo `main` with generated output, lockfile,
  analysis, tests, and host build passing.
- Compatibility marker date/version and cleanup text match the implementation
  and endpoint rollout.
- No waiter/request/terminal subscription survives its owner lifecycle in tests.
- `TRACKER.md` contains both pinned baselines, PR URLs, binary checked state on
  implementation branches, and any advisory manual evidence.
- The plan can close even if one or both manual checkboxes remain unexecuted for
  lack of representative terminals/devices.

## 7. Stage-Specific Detail

The strict two-wave shape is also the rollout safety mechanism. Auth capability
lands first as an additive endpoint. The bridge then consumes it with an exact
old-server fallback, so an unexpected deployment rollback does not make a new
bridge unusable. No stacked PR or cross-repository branch dependency is needed.
