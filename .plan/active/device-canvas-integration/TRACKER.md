# Device Canvas Session Integration: Tracker

## Current State

- **Plan slug:** `device-canvas-integration`
- **Implementation base:** `upstream/main` at `5c50f38a`
- **Current branch:** `device-canvas-integration-step-1`
- **Series state:** Step 1 plan prepared; no production implementation started
- **Current step:** publish the reviewed plan
- **Next action:** open/review Step 1, then begin bridge claim persistence only
  after the plan is accepted

## Locked Decisions

- [x] Device Canvas means the companion macOS app, not Apple's Device Hub.
- [x] Device Canvas integration is backend-neutral bridge functionality, not a
  new AI backend plugin.
- [x] Backend plugins own only native agent tool/command translation.
- [x] The bridge database is the sole authoritative claim store.
- [x] Device Canvas and Sesori clients hold projections only.
- [x] Device identity is bridge-scoped `ios-<UDID>` or
  `android-<adb-serial>`.
- [x] Canonical `Session.id`, not backend session ID, owns a claim.
- [x] One session owns a device; repeat is idempotent; another session conflicts.
- [x] Agent operations cannot force-reassign a claim.
- [x] Device/IPC outage changes presence but does not release ownership.
- [x] Explicit release, archive, deletion, or bridge-identity replacement releases
  ownership.
- [x] Local IPC is loopback-only with a rotating bearer secret delivered through
  an owner-readable rendezvous file.
- [x] Deep links reuse the existing session-detail route and include bridge scope.
- [x] OpenCode is the first autonomous agent adapter.
- [x] Relay requests carry Phase 2 signaling only, never continuous media/input.
- [x] WebRTC SRTP/DataChannel is the preferred media/input plane, subject to the
  recorded spike and dependency review.
- [x] TURN is required before an arbitrary-network product claim.
- [x] Android ships first from scrcpy; iOS remains capability-gated.
- [x] One remote interactive controller per device in the first release.

## Complexity Guardrails

- [x] One durable claim table, not an event store or Device Canvas database.
- [x] Separate claim, presence, and integration-connectivity state machines.
- [x] Normal Bridge table/DAO -> repository -> service -> transport layering.
- [x] No Drift writes from local IPC or relay handlers.
- [x] One current Device Canvas inventory projection in Bridge memory.
- [x] One authenticated local Device Canvas peer.
- [x] Full snapshots on reconnect; no unbounded local replay log.
- [x] No generic plugin-extension framework for this feature.
- [x] No fake cross-backend autonomous-tool abstraction.
- [x] Additive client/bridge contracts with unsupported degradation.
- [x] No second session-detail route.
- [x] No media-specific top-level `RelayMessage` variant.
- [x] No persisted peer, ICE, TURN, or stream-lease state.
- [x] No iOS production implementation before all feasibility gates pass.
- [x] No source, prompt, transcript, path, diff, media, or input analytics.

## Delivery Steps

| Done | Step | Repository | State |
|---|---|---|---|
| [ ] | 1/12 - Publish plan | Sesori | Prepared on `device-canvas-integration-step-1` |
| [ ] | 2/12 - Persist claims | Sesori | Blocked on Step 1 acceptance |
| [ ] | 3/12 - Connect local inventory | Sesori | Blocked on Step 2 |
| [ ] | 4/12 - Show claims and deep-link | Device Canvas | Blocked on Step 3 contract |
| [ ] | 5/12 - Add client status/deep links | Sesori | Blocked on Steps 3-4 |
| [ ] | 6/12 - Add OpenCode tools | Sesori | Blocked on Step 2 service and Step 3 inventory |
| [ ] | 7/12 - Verify Phase 1 | Both | Blocked on Steps 2-6 |
| [ ] | 8/12 - Prove media feasibility | Both | Blocked on Phase 1 acceptance |
| [ ] | 9/12 - Authorize/signaling streams | Sesori | Blocked on Step 8 decisions |
| [ ] | 10/12 - Provision TURN | Infrastructure | Blocked on Step 8 network decision |
| [ ] | 11/12 - Stream/control Android | Device Canvas | Blocked on Steps 8-10 |
| [ ] | 12/12 - Add Sesori viewport/verify | Sesori | Blocked on Steps 9-11 |

## Step 1 Checklist

- [x] Inspect Device Canvas discovery, rendering, input, lifecycle, build, and
  private DeviceKit constraints.
- [x] Inspect Sesori plugin, session identity, persistence, event, route,
  deep-link, relay, client-layer, test, and rollout seams.
- [x] Distinguish user-dispatched commands from autonomous backend-native tools.
- [x] Define one authoritative claim owner and independent presence/connectivity.
- [x] Define same-user local IPC authentication and credential bootstrap.
- [x] Define bridge-scoped deep-link identity and reuse the existing route.
- [x] Keep media off the JSON request/SSE data path.
- [x] Define Android, WebRTC/TURN, and iOS feasibility gates.
- [x] Record security, compatibility, failure, complexity, and verification
  requirements.
- [x] Run architecture consultation.
- [x] Run `architecture-plan-review`; apply all six valid findings directly.
- [x] Validate the documentation diff and plan structure.

## Phase 1 Acceptance Checklist

- [ ] Same-session claim is idempotent.
- [ ] Different-session claim conflicts without stealing.
- [ ] Different sessions can own different devices concurrently.
- [ ] Agent calls infer canonical session identity and cannot name another
  session.
- [ ] Device Canvas and Bridge restart recover claims and presence correctly.
- [ ] Device stop/restart retains ownership while changing presence.
- [ ] Archive, deletion, explicit release, and bridge-identity change release.
- [ ] Bridge takeover does not mutate ownership.
- [ ] Device Canvas badge and accessibility identify the correct owner.
- [ ] Deep link opens the exact bridge/project/session route.
- [ ] Offline bridge and missing/wrong-account links fail safely.
- [ ] Old bridge/client/Device Canvas combinations degrade as documented.
- [ ] OpenCode agent tools pass real-session end-to-end use.

## Phase 2 Entry-Gate Checklist

- [ ] Android encoded-frame versus decode/re-encode evidence recorded.
- [ ] Local rendering and remote streaming coexist without lifecycle regressions.
- [ ] Swift and Flutter WebRTC dependencies pass platform, license, maintenance,
  binary-size, and required-API review.
- [ ] SDP/ICE/fingerprint negotiation through existing E2E requests proven.
- [ ] Direct ICE and TURN paths measured.
- [ ] SRTP video and DataChannel input proven with claim revocation.
- [ ] iOS frame extraction proven or rejected explicitly.
- [ ] iOS touch/keyboard/text injection proven or rejected explicitly.
- [ ] Supported Xcode/DeviceKit matrix recorded.
- [ ] Release latency/resource targets fixed from measurements.

## Phase 2 Acceptance Checklist

- [ ] Only the current claim owner can obtain a stream lease.
- [ ] At most one remote controller is active per device.
- [ ] Claim revision/release/archive/delete immediately revokes the stream.
- [ ] Bridge/Device Canvas restart does not resume stale peer state.
- [ ] Touch, drag, scroll, keyboard, text, Back, and Home map correctly.
- [ ] Rotation/resolution changes fence stale coordinates.
- [ ] Background/foreground reauthorizes before input resumes.
- [ ] LAN direct and remote TURN paths pass.
- [ ] Sesori chat/request/SSE responsiveness remains acceptable during streaming.
- [ ] TURN and relay infrastructure never receives plaintext media.
- [ ] iOS remains hidden unless every gate passes.

## Architecture Review

- **Reviewer:** `architecture-plan-review` sub-agent
- **Date:** 2026-08-18
- **Result:** Draft rejected on six under-specified boundaries; all findings
  applied directly without a second review, per repository policy
- **Applied findings:** existing deep-link route/service ownership; bridge-scoped
  identity; concrete IPC secret/bootstrap; DAO/repository/service layering;
  signaling-only RelayMessage use; Device Canvas ownership of scrcpy/DeviceKit
- **Oracle consultation:** agreed with bridge-owned claims, backend-neutral service,
  plugin adapters, Android-first WebRTC plane, TURN requirement, and iOS gate

## Verification Record

### Step 1 documentation

- `git diff --no-index --check` passed for both new Markdown files.
- The plan structure check passed: required sections, all twelve delivery steps,
  architecture-review record, and transport feasibility gates are present in the
  plan and tracker.
- Markdown LSP diagnostics were unavailable because this workspace has no `.md`
  language server configured; no production-language diagnostics apply.
- Dart/Flutter/Swift suites are intentionally not required for this plan-only
  step under repository documentation verification rules.

### Production and manual evidence

Pending implementation steps. Record focused commands, totals, target devices,
network paths, compatibility peers, privacy-safe measurements, and architecture
implementation reviews as each step lands.

## Open Product Confirmations

These defaults are locked for planning but may be changed explicitly before their
own implementation step:

- OpenCode ships before other backend adapters.
- Device Canvas, not Apple Device Hub, owns the local badge/action.
- Claims survive temporary device and Device Canvas outages.
- A conflict never silently steals ownership.
- Android remote control ships before iOS.
- Arbitrary-network release includes TURN rather than direct-ICE-only support.
