# Device Canvas Session Integration: Tracker

## Current State

- **Plan slug:** `device-canvas-integration`
- **Implementation base:** `upstream/main` at `5c50f38a`
- **Current branch:** `device-canvas-integration-step-1`
- **Series state:** Steps 1-7 implemented and verified; Step 8 spike completed
  with a Phase 2 entry-gate NO-GO; Step 9 is blocked
- **Current step:** close the integrated Phase 2 evidence gaps
- **Next action:** prove one real scrcpy source through local rendering and
  WebRTC, then measure authorized signaling, revocation, and end-to-end latency

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
- [x] Device Canvas links omit project identity, enter a bridge-scoped transient
  resolver, and replace themselves with the canonical session-detail stack only
  after exact identity verification.
- [x] OpenCode is the first autonomous agent adapter.
- [x] Relay requests carry Phase 2 signaling only, never continuous media/input.
- [x] WebRTC SRTP/DataChannel is the preferred media/input plane, subject to the
  recorded spike and dependency review.
- [x] TURN is required before an arbitrary-network product claim.
- [x] Android ships first from scrcpy; iOS remains capability-gated.
- [x] One remote interactive controller per device in the first release.

## Complexity Guardrails

- [x] One durable claim table plus one bounded per-bridge revision-counter table,
  not an event store or Device Canvas database.
- [x] Separate claim, presence, and integration-connectivity state machines.
- [x] Normal Bridge table/DAO -> repository -> service -> transport layering.
- [x] No Drift writes from local IPC or relay handlers.
- [x] One current Device Canvas inventory projection in Bridge memory.
- [x] One authenticated local Device Canvas peer.
- [x] Full snapshots on reconnect; no unbounded local replay log.
- [x] No generic plugin-extension framework for this feature.
- [x] No fake cross-backend autonomous-tool abstraction.
- [x] Additive client/bridge contracts with unsupported degradation.
- [x] One transient projectless resolver route, with no duplicate session-detail
  surface or pre-verification content load.
- [x] No media-specific top-level `RelayMessage` variant.
- [x] No persisted peer, ICE, TURN, or stream-lease state.
- [x] No iOS production implementation before all feasibility gates pass.
- [x] No source, prompt, transcript, path, diff, media, or input analytics.

## Delivery Steps

| Done | Step | Repository | State |
|---|---|---|---|
| [x] | 1/12 - Publish plan | Sesori | Published in `00ca3a94` |
| [x] | 2/12 - Persist claims | Sesori | Implemented locally; focused and full verification passed |
| [x] | 3/12 - Connect local inventory | Sesori | Implemented locally; architecture and review gates passed |
| [x] | 4/12 - Show claims and deep-link | Device Canvas | Implemented locally; protocol, IPC, and live-device verification passed |
| [x] | 5/12 - Add client status/deep links | Sesori | Implemented locally; strict analysis, full suites, builds, and independent review passed |
| [x] | 6/12 - Add OpenCode tools | Sesori | Implemented; strict analysis, full suites, production build, security review, and real-agent verification passed |
| [x] | 7/12 - Verify Phase 1 | Both | Automated and user-confirmed ownership, compatibility, restart, conflict, and deep-link matrix passed |
| [x] | 8/12 - Prove media feasibility | Both | Spikes completed; component architecture is feasible, but the integrated Phase 2 entry gate is NO-GO |
| [ ] | 9/12 - Authorize/signaling streams | Sesori | Blocked until the Phase 2 entry-gate gaps close |
| [ ] | 10/12 - Provision TURN | Infrastructure | Blocked on the Step 9 credential contract and external TURN matrix |
| [ ] | 11/12 - Stream/control Android | Device Canvas | Blocked on Steps 9-10 |
| [ ] | 12/12 - Add Sesori viewport/verify | Sesori | Blocked on Steps 9-11 |

## Step 1 Checklist

- [x] Inspect Device Canvas discovery, rendering, input, lifecycle, build, and
  private DeviceKit constraints.
- [x] Inspect Sesori plugin, session identity, persistence, event, route,
  deep-link, relay, client-layer, test, and rollout seams.
- [x] Distinguish user-dispatched commands from autonomous backend-native tools.
- [x] Define one authoritative claim owner and independent presence/connectivity.
- [x] Define same-user local IPC authentication and credential bootstrap.
- [x] Define bridge-scoped projectless deep-link identity and canonical route
  resolution.
- [x] Keep media off the JSON request/SSE data path.
- [x] Define Android, WebRTC/TURN, and iOS feasibility gates.
- [x] Record security, compatibility, failure, complexity, and verification
  requirements.
- [x] Run architecture consultation.
- [x] Run `architecture-plan-review`; apply all six valid findings directly.
- [x] Validate the documentation diff and plan structure.

## Phase 1 Acceptance Checklist

- [x] Same-session claim is idempotent.
- [x] Different-session claim conflicts without stealing.
- [x] Different sessions can own different devices concurrently.
- [x] Agent calls infer canonical session identity and cannot name another
  session.
- [x] Device Canvas and Bridge restart recover claims and presence correctly.
- [x] Device stop/restart retains ownership while changing presence.
- [x] Archive, deletion, explicit release, and bridge-identity change release.
- [x] Bridge takeover does not mutate ownership.
- [x] Device Canvas badge and accessibility identify the correct owner.
- [x] Deep link verifies the exact bridge/session identity, derives the canonical
  project, and normalizes to the existing session-detail stack.
- [x] Offline bridge and missing/wrong-account links fail safely.
- [x] Old bridge/client combinations and unsupported Device Canvas protocol
  versions degrade as documented.
- [x] OpenCode agent tools pass real-session end-to-end use.

## Phase 2 Entry-Gate Checklist

- [x] Android source shape plus copy versus VideoToolbox decode/re-encode evidence
  recorded.
- [ ] One real scrcpy source feeds both local rendering and WebRTC without
  lifecycle regressions.
- [ ] Swift and Flutter WebRTC dependencies pass the complete platform, license,
  transitive-notice, maintenance, binary-size, and required-API review.
- [x] Existing encrypted relay framing and generic bridge routing carry
  representative offer/answer fixtures without adding a media-specific relay
  message.
- [ ] One authorized signaling route compares the advertised DTLS fingerprint,
  rejects tampering, and joins client, bridge, claim revision, and Device Canvas.
- [x] Direct host ICE and local coturn relay paths measured with synthetic video.
- [ ] Representative LAN and externally operated TURN paths measured.
- [x] Synthetic SRTP video and ordered DataChannel input proven.
- [ ] Claim revision/release/archive drives input rejection and active peer
  closure within the candidate thresholds.
- [x] Short-run iOS raw-frame extraction proven through private SimulatorKit.
- [x] One iOS touch and one USB keyboard usage proven through private DTUHID.
- [ ] iOS sustained frame/input stability across rotation and restart, repeated
  touch and keyboard variants, drag/multitouch, coordinate mapping, general text,
  latency, production signing, and private-ABI failure containment proven.
- [x] Two-toolchain iOS probe matrix recorded with exact build identifiers.
- [ ] Capture-to-display, input-to-visible, reconnect/revocation, resource, and
  Sesori request/SSE distributions support fixed release targets.

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
- **Implementation review:** Step 3 passed architecture re-review on 2026-08-24
  after moving deletion claim-removal capture into the persisted delete
  transaction and adding deterministic late-claim race coverage
- **Step 5 review:** independent bridge and client re-reviews on 2026-08-25 found
  no remaining correctness, security, privacy, or test findings after the final
  transaction-race and reconciliation fixes

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

### Steps 2-3 bridge claims and local IPC

- Drift schema v14, migration, DAO, repository, claim service, lifecycle cleanup,
  authenticated loopback IPC, typed protocol, rendezvous, presence, projection,
  bridge-identity rotation, and runtime disposal are implemented.
- Claim revisions use one monotonic high-water row per bridge. Restart, deletion,
  archive, release, and cascade cannot permit stale CAS operations after an ABA
  cycle, and revision storage does not grow by historical device key.
- Session deletion re-reads the persisted subtree inside the delete transaction,
  captures late descendants and their claims immediately before the FK cascade,
  and publishes removals only after successful deletion. Deterministic
  real-database tests cover late claims and late descendants while backend
  deletion is blocked.
- `dart test --concurrency=4` passed the complete bridge-app suite after the final
  revision, availability, deletion-race, and IPC-buffer fixes.
- Focused Device Canvas IPC, claim-service, deletion-race, and runtime-rotation
  verification passed.
- `dart analyze --fatal-infos`, `make build`, Dart LSP diagnostics, and
  `git diff --check` passed.
- A real typed WebSocket smoke connected through the rendezvous file, completed
  authenticated hello/inventory exchange, and returned `IPC_SMOKE_OK`.
- Architecture, goal, code-quality, and security reviews passed with no blocking
  findings.
- The prior hardening items are closed: authenticated IPC inputs and pending
  initial-snapshot deltas are bounded, overflow fails closed, and neither the IPC
  claim projection nor Device Canvas links expose project identifiers.

### Step 4 Device Canvas projection and navigation

- Added an owner-permission-validated rendezvous reader, authenticated loopback
  WebSocket client, typed protocol codec, heartbeat, reconnect/rotation handling,
  and revision-fenced in-memory claim projection. Device Canvas persists no claim
  ownership.
- Live discovery publishes only online iOS/Android inventory. A claimed pane
  remains visible when its device stops, independently changes to offline, and
  avoids starting its DeviceKit/scrcpy presentation while unavailable.
- Pane UI now distinguishes Sesori disconnected, syncing, incompatible,
  unclaimed, and claimed states; claimed panes expose the owning title, generic
  fallback, accessibility metadata, and a percent-encoded bridge-scoped Open
  action.
- `zsh build.sh` passed and runs the focused Swift protocol tests. The protocol
  tests also passed under complete strict concurrency with warnings as errors.
- A real Swift client connected to the Dart bridge server through an owner-only
  temporary rendezvous, published inventory, received snapshot/update/removal,
  and remained connected through heartbeat (`SWIFT_IPC_SMOKE_OK` and
  `SERVER_IPC_SMOKE_OK`).
- Real local use passed with an iPhone 17 Pro simulator and Pixel 10 Pro emulator.
  Window-specific captures verified claimed/unclaimed presentation and verified
  that a claimed iOS pane retained its owner and Open action after shutdown while
  changing to the offline presentation.
- `plutil -lint Info.plist` and `git diff --check` passed. The private DeviceKit
  runtime continues to emit its pre-existing duplicate `UniversalHID` warnings
  without preventing local presentation.

### Step 5 Sesori client status and navigation

- Added additive shared/bridge/client contracts, pure-Dart repository/service/
  cubit layering, session status and mutation UI, custom-scheme registration, and
  unsupported degradation.
- Device Canvas now opens
  `com.sesori.app:///sessions/<sessionId>?bridgeId=<bridgeId>&readOnly=false`.
  Parsing is strict, unauthenticated links queue safely, and the transient route
  renders no project or session metadata until the exact bridge/account/session
  identity is verified.
- Registered offline target bridges remain in a bounded waiting state and recover
  when that exact bridge reconnects. Missing, wrong-account, wrong-project, and
  mismatched-session targets fail without rendering session content.
- Background-task, subtask, and diff navigation preserve verified bridge scope.
  The diff screen does not create `DiffCubit` until the bridge/session/project
  gate succeeds.
- Human reassignment and release use revision-fenced compare-and-set operations.
  Server errors, transport loss, empty/truncated responses, and JSON parse failures
  preserve mutation uncertainty through queued refreshes and refresh failures
  until an authoritative projection proves the outcome.
- `dart analyze --fatal-infos` passed in shared, bridge app, client module-core,
  and client app. `dart test --concurrency=4` passed each package's complete suite
  after the final fixes.
- `make build` passed in `bridge/app`; `zsh build.sh` and focused Swift protocol
  tests passed in Device Canvas; `plutil -lint Info.plist` passed.
- Independent bridge and client reviews found no remaining findings.

### Step 6 OpenCode-native simulator tools

- Added backend-neutral list, claim, and release operations that resolve the
  trusted OpenCode invocation session through `SessionRepository` before using
  canonical `Session.id`; model input has no session, bridge, force, or
  reassignment field.
- Added exactly three managed-OpenCode native tools, typed bounded outcomes,
  authenticated loopback transport, rotating in-memory bearer registration, and
  owner-only one-time bootstrap delivery. Reserved capability variables are
  stripped from inherited setup/generation environments and from child process
  and shell environments.
- OpenCode's native registry is process-static. Definitions remain visible after
  a Device Canvas disconnect, but operations hard-disable with a typed
  unavailable outcome and cannot mutate claims.
- `make codegen`, workspace `make analyze`, full workspace `make test`, and the
  bridge-app production `make build` passed. Focused service, transport,
  generation, runtime-policy, and inherited-capability regressions passed.
- Independent compatibility and security reviews found no remaining high- or
  medium-severity findings after capability timing, inherited-environment, and
  bootstrap-delivery hardening.
- OpenCode `1.18.20` loaded exactly `list_simulators`, `claim_simulator`, and
  `release_simulator`; a real model invocation called `list_simulators` and the
  bridge received the exact invoking OpenCode session ID.
- A disposable live-simulator end-to-end run booted an iPhone 17 Pro simulator,
  launched the actual Device Canvas app, and used two distinct OpenCode agent
  sessions. It verified list, initial and repeated claim, caller-relative
  ownership, conflict without stealing, wrong-owner release rejection, owner
  release, canonical ownership in the bridge database, and Device Canvas
  disconnect/reconnect recovery. Temporary processes, state, and the simulator
  were cleaned up.

### Step 7 Phase 1 ownership verification

- `make codegen` completed in the bridge and client workspaces with no tracked
  drift. Strict `make analyze` passed every bridge and client package.
- Complete `make test` runs passed for the bridge and client workspaces. The
  bridge ended at 2,781 tests with the two expected host-platform skips.
- The host bridge production `make build` passed. Device Canvas `zsh build.sh`
  rebuilt the app and passed its Swift protocol suite.
- Current-component live coverage includes the real OpenCode `1.18.20` agent and
  two-session Device Canvas run recorded in Step 6. A focused revocation test
  proves old-identity claims are deleted before fresh registration completes.
- Released-baseline compatibility harnesses used the published macOS `v1.4.0`
  bridge artifact (SHA-256 `3bc744674eef9c57d939107744c808017e9b1d250a07357c6f0cbe306fb9e8a6`)
  and client source `be344a56`. The current client repository mapped the old
  bridge's actual `404` to unsupported; the old client tolerated
  `device_canvas.changed` as nonfatal and processed the following heartbeat.
- The user confirmed the release checklist passes for two-device ownership,
  repeat/conflicting claims, release restrictions, caller-identity spoof
  rejection, badge/accessibility and exact deep links, independent app/bridge/
  Device Canvas restart, device stop/restart, and archive/deletion cleanup.
- `projects-and-sessions.md`, `bridge-connectivity.md`, and the shipped OpenCode
  lifecycle documentation now point to the dedicated Phase 1 ownership contract
  and its L1-L5 matrix.

### Step 8 remote simulator transport feasibility

- Android scrcpy 4.1 exposed Annex-B constrained-baseline H.264 before local
  decode. A real Pixel 10 Pro Android 17 source covered portrait/landscape
  resolution changes at maximum dimension 1600 and the existing 4 Mbit/s cap.
  The selected public WebRTC APIs have no encoded-frame injection seam, so the
  candidate path is VideoToolbox decode to `CVPixelBuffer` followed by WebRTC
  H.264 encode.
- Copy, decode, and decode/re-encode completed the 25.57-second, 210-frame source
  in 0.07, 0.36, and 0.77 seconds respectively. During real-time re-encode and
  repeated emulator input, the production local renderer stayed connected.
  Device Canvas averaged 14.8% host CPU and 56.6-58.1 MiB RSS, but the re-encode
  was an independent file replay to `/dev/null`, not a shared scrcpy/WebRTC
  lifecycle.
- `flutter_webrtc 1.6.0` and `stasel/WebRTC 151.0.0` passed focused build,
  platform-slice, direct-license, binary-size, and required-API checks. Complete
  maintenance policy and transitive-notice acceptance remain open. Android must
  declare network-state/change and audio-settings permissions in addition to
  internet. The Flutter plugin's Built-in Kotlin migration warning remains an
  implementation dependency risk.
- Disposable native and Flutter peers using synthetic `640x360` video passed
  direct host ICE, local coturn, and Android-emulator-NAT TURN. The final Android
  run selected relay/relay, negotiated H.264 with connected DTLS and AES-128 SRTP,
  decoded 67 frames, acknowledged 128 ordered inputs at 47.0 ms p95, and rejected
  input after a local test boolean changed. It did not consume scrcpy frames or a
  real claim event.
- A representative offer request and answer/TURN response now have focused tests.
  The client test proves exact serialized request plaintext after decrypting its
  emitted frame, ignores a wrong-ID response, and correlates the answer. The
  independent bridge test exercises framing primitives around a generic test-only
  route, captures the parsed body, and rejects an internally mismatched
  fingerprint. It proves neither parser-valid WebRTC signaling nor production
  receive/send integration. No connected authorized client-to-bridge route,
  independently authenticated fingerprint, production route, or top-level relay
  message was added.
- Xcode 26.6 and Xcode 27 beta 5 both exposed live `1206x2622` BGRA IOSurfaces
  through private `SimulatorKit.SimDeviceScreen` at approximately 60 callbacks/s.
  Private DTUHID touch and USB usage 4 changed a UIKit probe and entered `a` under
  both toolchains. Sustained rotation/restart runs, repeated touch and key events,
  drag/multitouch, coordinate mapping, general text, input latency, production
  signing, and ABI-drift containment remain open; iOS remote capability stays
  unavailable.
- The plan and regression contract retain provisional direct/TURN, video, input,
  revocation, resource, and Sesori responsiveness thresholds. External TURN,
  claim-bound active peer revocation, shared production source wiring, and the
  required capture/input-to-visible and responsiveness distributions must close
  before those targets become fixed.
- Strict analysis passed every bridge and client package. Complete bridge and
  client workspace test runs passed; the bridge ended at 2,783 tests with the two
  expected host-platform skips. `zsh build.sh` rebuilt Device Canvas and passed
  its Swift protocol suite. Focused signaling tests and `git diff --check` passed.
- Independent review rejected the initial unconditional gate-pass claim because
  the component probes did not cover the integrated source, authorization,
  revocation, latency, and iOS containment boundaries. This tracker now records
  the resulting NO-GO rather than advancing to Step 9.

## Open Product Confirmations

These defaults are locked for planning but may be changed explicitly before their
own implementation step:

- OpenCode ships before other backend adapters.
- Device Canvas, not Apple Device Hub, owns the local badge/action.
- Claims survive temporary device and Device Canvas outages.
- A conflict never silently steals ownership.
- Android remote control ships before iOS.
- Arbitrary-network release includes TURN rather than direct-ICE-only support.
