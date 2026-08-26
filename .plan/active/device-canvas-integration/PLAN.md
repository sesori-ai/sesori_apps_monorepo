# Device Canvas Session Integration

## Status

- **Plan slug:** `device-canvas-integration`
- **Status:** Active - Steps 1-7 implemented and verified; Step 8 spike executed
  with a Phase 2 entry-gate NO-GO
- **Plan date:** 2026-08-18
- **Primary repository:** `sesori-ai/sesori_apps_monorepo`
- **Companion repository:** `daniil-shumko/device-canvas`
- **Implementation base:** `upstream/main` at `5c50f38a`
- **Plan branch:** `device-canvas-integration-step-1`
- **Delivery:** twelve ordered steps across Sesori, Device Canvas, and media
  infrastructure; Step 1 publishes this plan before production work

This plan and `TRACKER.md` are the implementation authority. Current code,
released compatibility requirements, and measured feasibility remain
authoritative if this document becomes stale.

## Goal

Connect Sesori AI sessions to simulators and emulators presented by Device
Canvas in two independently releasable phases.

Phase 1 delivers ownership and navigation:

1. An AI session can list available Device Canvas devices and claim or release
   one through a backend-native adapter.
2. The Sesori Bridge records one authoritative owner for each claimed device.
3. Device Canvas visibly marks the device with the owning Sesori session.
4. Opening the claim in Device Canvas deep-links into that exact session in the
   Sesori app.

Phase 2 delivers remote interaction:

1. A user viewing the owning session in Sesori can start an authorized remote
   viewport.
2. Device Canvas streams the device screen over a media-appropriate encrypted
   channel rather than Sesori's JSON relay-message path.
3. The user can send touch, scroll, keyboard, text, and supported device-button
   input from the Sesori app.
4. Android ships first from the existing scrcpy integration. iOS remote view and
   control remain unavailable until a feasibility gate proves both frame capture
   and input injection against the supported private simulator-framework versions.

## Terminology

- **Device Canvas:** the separate macOS application in the companion repository.
- **Device Hub:** Apple's Xcode application. This plan does not modify, patch, or
  inject code into Device Hub. References to a device-side action mean Device
  Canvas unless a later product decision explicitly changes this scope.
- **Canonical session ID:** the bridge-owned `Session.id` exposed to Sesori
  clients, not a backend plugin's session ID.
- **Device key:** Device Canvas's stable local identifier: `ios-<UDID>` for an
  iOS simulator or `android-<adb-serial>` for an Android emulator.
- **Claim:** durable Sesori ownership connecting one bridge-scoped device key to
  one canonical session.
- **Presence:** whether Device Canvas currently reports the device as available.
  Presence and claim ownership are independent state machines.
- **Stream lease:** short-lived authorization for one remote interactive media
  session. A stream lease is not persisted and never replaces the durable claim.

## Non-Goals

### Phase 1

- No modification of Apple's Device Hub or private Device Hub binaries.
- No second authoritative claim store in Device Canvas or a Sesori client.
- No silent claim stealing by another session or surface.
- No universal backend-tool framework invented solely for this integration.
- No requirement that every backend expose agent-initiated claiming in the first
  release. OpenCode is the first supported adapter.
- No physical iOS or Android device support.
- No remote screen frames or high-rate input over `RelayMessage`, SSE, ordinary
  relay HTTP requests, or transcript attachments.

### Phase 2

- No iOS remote-view or remote-control product promise before the explicit
  feasibility gate passes.
- No persisted WebRTC peer, ICE, candidate, or stream-lease state.
- No replay of remote input after reconnect.
- No multi-controller collaboration in the first release. At most one remote
  interactive controller may hold a device stream lease at a time.
- No source-code, prompt, transcript, path, or diff data in Device Canvas IPC,
  media signaling, TURN credentials, or analytics.

## Current Behavior And Findings

### Device Canvas

`DeviceCanvas.swift` owns application startup, device discovery, pane layout,
z-order, and the two-second reconciliation loop through `WorkspaceModel`.
`DeviceIdentifier.stableValue` already yields the required platform-prefixed
device key.

iOS simulators are discovered through `xcrun simctl`, then rendered and
controlled inside the private, opaque
`DeviceView(deviceIdentifier:)` supplied by Xcode's DeviceKit. Device Canvas has
no public frame or HID abstraction around that view.

Android emulators are discovered through adb. `AndroidEmulatorStream` in
`AndroidEmulator.swift` starts scrcpy 4.1, consumes H.264 Annex B video, renders
through VideoToolbox/AVFoundation, and writes touch, key, text, scroll, Back, and
Home control messages to the scrcpy control socket.

Device Canvas currently has no claim model, persistence, network service, URL
scheme, automated test target, or CI workflow. `run.sh` forwards positional iOS
UDIDs only.

### Sesori session and plugin boundaries

`Session.id` in `shared/sesori_shared` is the stable client identity. The bridge
`sessions_table` maps it durably to `pluginId`, `backendSessionId`, `projectId`,
and optional parent information. Session operations and events resolve through
that canonical binding.

Existing `sesori_plugin_*` packages represent AI backends that own projects and
sessions. Device Canvas owns neither, so it is not another `BridgePluginApi`
implementation. Claim authority belongs in a backend-neutral bridge service.
Only the translation that makes a claim operation visible to a particular AI
runtime belongs in that runtime's plugin package.

The shared `PluginCommand` model exposes user-dispatched commands, but there is
no shared mechanism for registering an autonomous model tool across OpenCode,
Codex, Cursor/ACP, Claude, and Hermes. Each backend has a different native tool,
MCP, skill, command, or extension seam.

### Sesori routing

The canonical session route is
`/projects/:projectId/sessions/:sessionId`. Notification navigation already
resolves to that route. Device Canvas must not receive a project ID because it
may disclose source-path information, so its external link instead enters a
narrow `/sessions/:sessionId` resolver route scoped by `bridgeId`.

The resolver waits when that registered bridge is offline, verifies the exact
account/bridge/session binding, derives the canonical project from trusted
client state, and replaces itself with the normal project/session stack. It has
only bounded loading and unavailable presentation; it is not a second session
detail surface. `DeepLinkService` retains the legacy OAuth callback behavior and
dispatches valid Device Canvas links to this resolver.

### Sesori relay transport

The client and bridge exchange encrypted JSON `RelayMessage` frames through the
relay. Framing uses X25519-derived keys and XChaCha20-Poly1305. The protocol has a
64 MiB message ceiling, request/response correlation, ordered SSE queues, and
reconnect/resume behavior, but no codec negotiation, adaptive bitrate, media
congestion control, or frame-loss policy.

This channel is suitable for claims, inventory, signaling, and status. It is not
suitable for continuous interactive video.

## Locked Product And Architecture Decisions

1. Device Canvas integration is an optional backend-neutral bridge capability,
   not an AI backend plugin.
2. The Sesori Bridge database is the only authoritative claim store. Device
   Canvas and clients hold projections only.
3. A device has at most one owning session per bridge identity. Repeating a claim
   from the same session is idempotent; another session receives a conflict.
4. A device going offline does not release its claim. Explicit release, session
   archive, session deletion, or bridge-identity replacement does.
5. Device Canvas and Sesori Bridge run as the same macOS user. Their local IPC is
   loopback-only, uses a fresh bearer secret delivered through an owner-readable
   rendezvous file, and never exposes relay credentials.
6. Claim operations infer the canonical session from the invoking backend
   session. The model cannot supply an arbitrary Sesori session ID.
7. OpenCode is the first agent-initiated adapter. Other backends remain
   unsupported until their native adapter is implemented and verified.
8. Device Canvas links carry only `bridgeId` and canonical `sessionId`. A narrow
   projectless resolver derives the project after exact identity verification,
   then replaces itself with Sesori's existing session-detail stack.
9. Sesori's existing encrypted relay channel carries only low-rate Phase 2
   authorization and WebRTC signaling. Video uses SRTP and input uses an
   encrypted data channel.
10. TURN is required before claiming that remote control works across arbitrary
    networks. Direct ICE may be used for development and a clearly labelled
    limited beta.
11. Device Canvas owns scrcpy, DeviceKit, capture, encoding, and input injection.
    The Sesori Bridge owns authorization, claims, signaling, and client-facing
    product APIs.
12. Android remote view/control ships first. iOS advertises local presentation
    only until its feasibility gate passes.

## Phase 1 Design: Claim And Deep-Link

### 1. Separate state machines

Do not represent device availability, ownership, and IPC connectivity as one
flattened enum or nullable record.

Claim ownership is one of:

- `unclaimed`;
- `claimed(sessionId, revision, claimedAt)`.

Device presence is one of:

- `offline`;
- `online(deviceDescriptor)`.

Local integration connectivity is one of:

- `disconnected`;
- `connected(canvasInstanceId, protocolVersion)`.

A claimed device may be offline. A connected Device Canvas may report no
devices. Losing IPC clears live presence but does not mutate claims.

### 2. Durable claim schema

Add a Drift claim table under `bridge/app/lib/src/api/database/tables/` with:

- `bridge_id TEXT NOT NULL`;
- `device_key TEXT NOT NULL`;
- `session_id TEXT NOT NULL` referencing `sessions_table.session_id` with delete
  cleanup;
- `claim_revision INTEGER NOT NULL`;
- `claimed_at INTEGER NOT NULL`;
- `updated_at INTEGER NOT NULL`;
- primary key `(bridge_id, device_key)`;
- index on `session_id`.

Add a bounded revision-counter table with:

- `bridge_id TEXT NOT NULL` as the primary key;
- `last_revision INTEGER NOT NULL`.

Every ownership-creating claim or reassignment allocates the next revision from
the bridge's counter in the same transaction. A removal carries the removed
claim's revision, and any later ownership receives a strictly greater revision.
The high-water mark survives claim deletion, session cascade, archive cleanup,
and restart, preventing stale compare-and-set operations from succeeding after
an ABA cycle. The table grows by bridge identity, not by historical device key.

Do not duplicate project, plugin, backend-session, session-title, or device-name
facts in the durable row. Those are resolved from the canonical session binding
and live Device Canvas inventory.

Layer ownership follows the bridge's normal dependency direction:

1. Drift table and DAO own persistence.
2. A bridge repository maps rows and performs atomic compare-and-set operations.
3. A bridge service owns claim, conflict, release, and lifecycle decisions.
4. Relay and local IPC handlers parse requests and delegate; they never write
   Drift directly.
5. Composition and lifecycle wiring remain in the orchestrator layer.

Required atomic outcomes are:

- `claimed`: an unclaimed device is now owned;
- `alreadyOwned`: the same session repeated its claim;
- `conflict`: another session owns the device;
- `deviceUnavailable`: a fresh claim named no currently reported device;
- `sessionUnavailable`: the canonical session binding is absent, archived, or
  tombstoned;
- `unsupported`: the bridge or backend lacks the capability.

Only an explicit authenticated human reassignment flow may replace another
session's claim. Agent tools never receive force semantics.

### 3. Claim lifecycle

On bridge startup:

1. Load claims for the current registered bridge identity.
2. Remove rows whose session binding was already deleted or archived.
3. Wait for Device Canvas inventory before marking presence online.
4. Send a full claim snapshot after authenticated IPC hello completes.

On session archive or deletion, release every claim belonging to that canonical
session in the same ordered session-family operation. Session deletion must not
leave a recoverable claim after tombstoning.

On explicit release, require either the owning canonical session or an
authenticated human action. Repeating release is idempotent.

On Device Canvas disconnect, clear inventory/presence and notify remote clients;
retain claim rows. On reconnect, replace inventory atomically and send a fresh
claim snapshot rather than replaying an unbounded delta history.

On bridge-ID revocation or account replacement, do not expose old claims under
the new identity. Delete old rows during bounded startup/registration cleanup;
do not migrate ownership across accounts automatically.

Relay takeover changes connection reachability only and does not mutate claims.

### 4. Authenticated local IPC

The Bridge hosts a loopback WebSocket on a random port. It writes an atomic
owner-readable rendezvous file under the bridge state directory containing:

- protocol version;
- loopback port;
- fresh high-entropy bearer secret;
- current bridge ID;
- bridge process generation.

The file is never passed through argv. Device Canvas watches the documented path,
connects only to loopback, and sends `Authorization: Bearer <secret>`. The Bridge
rejects unauthenticated clients before reading application messages and allows
one active Device Canvas peer. A replacement peer closes the old connection
without altering durable claims.

The first protocol is versioned JSON:

```text
Device Canvas -> Bridge
  hello(protocolVersion, canvasInstanceId, capabilities)
  inventorySnapshot(devices)
  heartbeat(canvasInstanceId, observedAt)

Bridge -> Device Canvas
  helloAccepted(protocolVersion, bridgeId)
  claimsSnapshot(claims)
  claimUpdated(claim)
  claimRemoved(bridgeId, deviceKey, revision)
```

Each inventory descriptor contains only:

- device key;
- platform;
- display name;
- runtime/model description;
- local dimensions/orientation when known;
- local-view, remote-video, remote-control, and input capability flags.

Each claim projection contains only bridge, session, device, revision, and
bounded display-title facts needed for the badge and link. Project identifiers,
prompts, transcript text, source paths, diffs, tool input, and backend secrets
never cross IPC.

Unknown protocol versions fail closed with a clear compatibility status. A
heartbeat timeout marks the canvas disconnected; it does not release ownership.

### 5. Bridge client contract

Expose additive request/response models and events for:

- bridge Device Canvas capability and connection status;
- current devices and their presence/capabilities;
- claims visible to the authenticated account;
- claims belonging to one canonical session;
- explicit human claim, release, and reassignment actions;
- device, claim, and availability changes.

These are ordinary bounded JSON messages on the existing encrypted transport.
Do not add a new top-level `RelayMessage` union variant where an existing routed
request/response or normalized event suffices.

An older bridge returns unsupported/not-found and the new client hides the
feature. An older client ignores additive fields/events and retains current
session behavior. Transport additions use honest nullable/defaulted fields only
where one valid legacy meaning exists.

### 6. Agent invocation

Define backend-neutral operations in the bridge service:

```text
list_simulators()
claim_simulator(deviceKey)
release_simulator(deviceKey)
```

Tool results contain bounded metadata and typed outcomes. The adapter resolves
the invoking backend session through `SessionRepository` before reaching the
claim service. It never accepts `sessionId`, `bridgeId`, or force from model input.

The first adapter is OpenCode through its native tool support. The adapter:

1. registers exactly three tools only in bridge-managed OpenCode;
2. binds each call to the backend session that invoked it;
3. translates the binding to canonical `Session.id`;
4. reports conflicts without exposing prompt or transcript content;
5. hard-disables every operation when the integration becomes unavailable.

OpenCode's current native registry is fixed for the process lifetime, so tool
definitions may remain visible after Device Canvas disconnects. The bridge must
return the typed unavailable outcome and perform no claim operation; it must not
pretend that dynamic unregistration succeeded.

Codex, Cursor/ACP, Claude, and Hermes adapters are separate follow-ups. A backend
with no verified native registration seam does not advertise a pretend command
as autonomous agent support. User-dispatched `PluginCommand` may be added as a
separate convenience, but it does not satisfy agent-initiated claiming.

### 7. Device Canvas claim presentation

Extend `WorkspaceModel` with an IPC client and an ephemeral claim projection
keyed by `DeviceIdentifier`. Preserve the existing two-second device discovery
and pane layout behavior.

Each pane displays:

- unclaimed or claimed state;
- claiming session title with a generic fallback;
- online/offline state independently;
- an accessibility description of ownership;
- an `Open Sesori session` action when bridge and session IDs are present.

Device Canvas never persists claim ownership. Reconnect always replaces its
projection from `claimsSnapshot` before applying later revisions.

### 8. Deep-link contract and resolution

Device Canvas opens:

```text
com.sesori.app:///sessions/<sessionId>?bridgeId=<bridgeId>&readOnly=false
```

Every path/query value is percent-encoded through one URL builder. The device key
and project ID are not navigation identity and are omitted.

Extend the existing app deep-link service to:

1. retain the OAuth callback behavior;
2. recognize this projectless session path;
3. strictly validate the bridge, session, and editable-only query values;
4. queue the resolver route until authentication completes;
5. replace the navigation stack through the existing route dispatcher;
6. wait when the named registered bridge is offline;
7. verify the exact bridge/account/session identity before deriving the project;
8. replace the resolver with the canonical project/session stack;
9. show a bounded unavailable result when identity cannot be resolved without
   exposing another account's session or project metadata.

Register the custom scheme on the macOS mobile-app runner if it is not already
present. The projectless route is a transient resolver and must not duplicate the
session-detail UI or load session content before verification. Universal links
may be added later using the same normalized target, but are not required for
local Device Canvas launch.

## Phase 1 Failure Semantics

- **Device Canvas absent:** Bridge remains healthy; capability reports
  disconnected; fresh claims fail `deviceUnavailable`; durable existing claims
  remain.
- **Bridge absent:** Device Canvas keeps normal local presentation and hides or
  disables Sesori claim actions.
- **IPC authentication/version failure:** fail closed, log locally with protocol
  context, and expose no session metadata.
- **Claim conflict:** preserve the old owner and return a typed conflict.
- **Session archive/delete race:** the session-family operation wins; no claim is
  committed for a non-ownable binding.
- **Device disappears after claim validation:** commit may succeed, but presence
  becomes offline; ownership is retained.
- **Deep link targets an offline bridge:** open the existing waiting state.
- **Deep link targets a missing/wrong-account bridge:** show unavailable without
  leaking title or project facts.

## Phase 1 Compatibility

- Database migration adds the claim table, one bounded per-bridge revision table,
  and indexes; no existing session row is rewritten or backfilled.
- Internal Bridge packages update in lockstep; no internal compatibility shim.
- Client/Bridge messages are additive and remain forward/backward tolerant for
  public release skew.
- Local IPC has an explicit integer protocol version and capability negotiation.
- New Device Canvas with an old Bridge remains a fully functional local canvas
  without claims. New Bridge with old Device Canvas reports disconnected.
- The first release does not claim agent support for plugins without an adapter.

## Phase 1 Verification

### Automated

- DAO/repository tests prove unique ownership, idempotent same-session claim,
  conflict, release, cascade cleanup, archive cleanup, revision monotonicity, and
  bridge-identity isolation.
- Service tests prove device-presence validation, session binding validation,
  no force path for agents, and takeover/disconnect semantics.
- IPC tests prove loopback binding, secret rejection, one-peer replacement,
  version rejection, snapshot ordering, reconnect, heartbeat timeout, and no
  durable release on disconnect.
- Shared protocol tests prove additive JSON decode/encode and old-peer omission.
- Client API/repository/service/cubit tests prove unsupported, disconnected,
  claimed, conflict, and release states.
- Deep-link tests prove percent-encoded route construction, bridge scope,
  disconnected recovery, missing session, wrong account, and unchanged OAuth
  handling.
- OpenCode adapter tests prove backend-to-canonical session binding and reject an
  arbitrary session identity.
- Device Canvas seams receive focused protocol/model tests once a test target is
  introduced; private DeviceKit rendering remains manual integration coverage.

### End-to-end

- One release-target macOS host with two booted devices.
- One current Sesori mobile client and one current Bridge.
- One OpenCode session claims device A and a second session claims device B.
- The second session cannot claim A until the owner releases it.
- Device Canvas shows each correct owner and opens each exact session.
- Restart Device Canvas, the Bridge, and the mobile app independently; claims
  reappear and presence recovers.
- Stop and restart one device; ownership remains while presence changes.
- Archive and delete an owning session; its claim disappears.
- Validate current client/new Bridge and new client/minimum-supported released
  Bridge behavior.

## Phase 2 Entry Gate

No production media-plane implementation begins until three time-boxed spikes
produce recorded evidence and an architecture decision.

### Android source spike

Prove the current scrcpy stream can feed remote media without breaking local
rendering or input. Compare:

1. passing existing encoded H.264 into the selected WebRTC stack, if its supported
   API permits encoded-frame injection; and
2. decoding to a native pixel buffer and re-encoding through WebRTC.

Record latency, CPU, memory, frame pacing, resolution changes, orientation, and
local-plus-remote input behavior. Select the smallest supported path from
evidence rather than assuming encoded pass-through.

### WebRTC and network spike

Prove a Device Canvas peer and Flutter peer can:

- exchange SDP and ICE through bounded existing Sesori requests;
- validate DTLS fingerprints carried through the E2E channel;
- stream video over SRTP;
- send ordered low-latency input over DataChannel;
- connect directly on a local network;
- connect across representative NATs through TURN;
- end promptly when authorization is revoked.

Select the Swift and Flutter WebRTC dependencies only after checking current
supported platform versions, licensing, binary size, maintenance, and the needed
encoded/raw-frame APIs.

### iOS feasibility spike

iOS may advertise remote video/control only after proving all of:

1. stable frame extraction from the target simulator without using periodic
   screenshots as the production path;
2. stable touch, keyboard, and text injection into the selected simulator;
3. no unavailable Apple-private entitlement;
4. acceptable interaction latency and frame pacing;
5. repeatability across every Xcode/SimulatorKit/DTUHID combination claimed by
   Device Canvas;
6. failure containment when the private API changes.

Investigate SimulatorKit and DTUHID first, with DeviceKit frame/HID providers,
supported simulator tooling, and window capture only as candidates. A spike
failure results in `remoteVideo=false` and `remoteControl=false`; it does not
block Android.

## Phase 2 Design: Remote View And Control

The exact provider and dependency names remain conditional on the entry-gate
evidence. The ownership and security boundaries below are locked.

### 1. Capability contract

Extend the existing device descriptor additively with:

- `remoteVideo`;
- `remoteControl`;
- supported codecs;
- maximum dimensions/frame-rate hints;
- touch, scroll, keyboard, text, Back, and Home support;
- current orientation.

Capability absence decodes as unsupported. The client never infers control
support from platform alone.

### 2. Ephemeral stream authorization

The bridge issues an in-memory stream lease containing:

- random lease ID;
- bridge ID;
- device key;
- canonical session ID;
- claim revision;
- authenticated client connection/surface identity;
- issue and expiry time.

The bridge grants a lease only when the named session currently owns an online
device with the required capabilities. A second interactive request receives a
controller conflict; there is no silent takeover.

Leases are not persisted or resumed after bridge restart. Reconnect creates a
new lease after rechecking the claim. Release, archive, deletion, claim revision
change, Device Canvas disconnect, explicit viewport close, timeout, or bridge
shutdown terminates the lease.

### 3. Control plane

Use existing encrypted routed requests for:

- stream start/stop;
- lease authorization and status;
- SDP offers/answers;
- ICE candidates;
- short-lived TURN configuration;
- bounded errors and reconnect decisions.

Do not add media, input frames, or a media-specific top-level `RelayMessage`
variant. The Bridge forwards signaling to Device Canvas over the authenticated
local IPC and never decodes or proxies video.

TURN credentials are short-lived and scoped to the authenticated stream setup.
They are never persisted, logged, placed in analytics, or shared through the
Device Canvas rendezvous file.

### 4. Media and input plane

The peer connection is Device Canvas to Sesori client:

- video over DTLS-SRTP/WebRTC media;
- input over an encrypted reliable ordered DataChannel;
- relay/TURN infrastructure sees encrypted media;
- DTLS fingerprints are authenticated through Sesori's existing E2E signaling.

The first DataChannel message binds the connection to the lease ID, claim
revision, protocol version, and negotiated device dimensions. Later input carries
monotonically increasing sequence numbers and normalized coordinates.

Supported input variants are sealed and explicit:

- touch down/move/up/cancel;
- scroll;
- key down/up with supported modifiers;
- bounded UTF-8 text;
- Back;
- Home.

Device Canvas rejects input after lease expiry/revision change, for unsupported
variants, or against stale dimensions/orientation. No input is replayed after
reconnect.

### 5. Device Canvas media ownership

Device Canvas owns one remote-device-session boundary around its existing device
implementations. The first production implementation wraps Android scrcpy.

It is responsible for:

- acquiring/tearing down the media source;
- feeding the selected WebRTC video path;
- maintaining current dimensions/orientation;
- translating normalized input to scrcpy control packets;
- preserving local rendering;
- ending the peer when the bridge revokes the lease.

The Bridge never imports scrcpy, SimulatorKit, or DeviceKit concepts. The iOS
component probes succeeded under Xcode 26.6 and Xcode 27 beta 5, but its full
feasibility gate remains open. Any separately planned private
SimulatorKit/DTUHID provider must first close the sustained stability,
rotation/restart, input coverage, coordinate mapping, latency, text,
production-signing, and ABI-failure-containment gaps without making Android
depend on private iOS behavior.

### 6. Sesori client viewport

Host the remote viewport under the existing session-detail stack. Pure Dart
`module_core` owns API, repository, service, cubit, authorization, lifecycle, and
reconnect state. The Flutter app shell owns the WebRTC widget, gesture mapping,
focus, keyboard forwarding, full-screen presentation, orientation UI, and
accessibility.

The viewport:

- is visible only for the owning session and supported device;
- starts on explicit user action;
- shows connecting, live, paused, disconnected, revoked, and unsupported states;
- disables input whenever the lease is not live;
- maps system Back to closing keyboard/view/route, while simulator Back is an
  explicit control;
- pauses video and input when backgrounded;
- reauthorizes instead of blindly resuming on foreground;
- exposes an accessible exit and named device controls;
- terminates immediately when ownership changes.

No video frame or input data is persisted in client caches, transcript models,
notifications, or analytics.

## Phase 2 Failure Semantics

- **ICE/TURN failure:** keep the Sesori session usable, close the lease, and offer
  bounded retry.
- **Signaling timeout:** cancel local and client peer setup; never retain a zombie
  lease.
- **Claim change:** bridge revokes; Device Canvas closes peer/data channel;
  client exits live state.
- **Device rotation/resolution change:** publish negotiated dimensions before
  accepting coordinates in the new space.
- **Device Canvas crash:** bridge marks presence offline and revokes leases while
  preserving durable claims.
- **Bridge restart:** media does not resume; user explicitly reconnects after
  claim revalidation.
- **App background:** pause/close according to measured platform constraints;
  foreground always reauthorizes.
- **Private iOS framework change:** iOS remote capability disappears without
  affecting claims, local Device Canvas, Android, or Sesori sessions.

## Phase 2 Verification

### Automated

- Lease service tests cover authorization, one-controller conflict, expiry,
  revision fencing, archive/delete/release, disconnect, and restart.
- Signaling tests prove bounded payloads, route authorization, fingerprint
  forwarding, TURN credential lifetime, and cleanup after every failure.
- Device Canvas tests cover capability negotiation, Android frame source
  lifecycle, input mapping, stale dimensions, sequence ordering, and revocation.
- Client tests cover route/state transitions, lifecycle, disabled input,
  coordinate mapping, keyboard/system Back behavior, accessibility, and no
  reconnect without reauthorization.
- Protocol tests prove old peers decode capability omission as unsupported.

### Performance and end-to-end

Before implementation, the media spike records a baseline and proposes release
targets for representative LAN and TURN paths. The entry gate closes only after
the complete matrix validates and fixes those targets. At minimum, record:

- capture-to-display latency distribution;
- input-to-visible-response latency distribution;
- achieved resolution/frame rate/bitrate;
- host and phone CPU/memory;
- reconnect and revocation time;
- Sesori request/SSE latency with and without an active stream.

The release matrix includes one supported Android emulator, one release-target
iOS client, one release-target Android client, LAN direct ICE, remote TURN, app
background/foreground, bridge and Device Canvas restart, claim reassignment, and
network loss. Chat/session control must remain responsive under media load.

iOS receives its own matrix only after its feasibility gate passes.

## Phase 2 Entry-Gate Decision

Step 8's time-boxed spikes completed on 2026-08-25 with a **NO-GO**. On
2026-08-26, Step 9 implemented the bounded authorization/signaling boundary and
an Android video-only production peer for local cross-device testing. This closes
the integrated source and authorization unknowns, but it does not open the Phase
2 product gate: input, external TURN, latency/resource distributions, reconnect
coverage, complete dependency acceptance, and iOS containment remain open.

The component-level decisions are:

- **GO, Android architecture candidate:** retain the existing scrcpy compressed
  path for local display, decode the same access units to `CVPixelBuffer`, and
  pass decoded frames to WebRTC for H.264 re-encode.
- **GO, WebRTC protocol candidate:** the selected native and Flutter libraries
  can negotiate H.264, DTLS-SRTP, relay candidates, and a reliable ordered
  DataChannel in disposable peers.
- **GO, authorization/signaling boundary:** encrypted routed requests, exact
  relay-connection incarnation, claim revision, expiring in-memory leases, and
  authenticated local IPC now carry bounded offer/answer/ICE signaling. Exact
  fingerprint tampering fails before peer setup and signaling is not persisted or
  emitted through media-specific relay messages.
- **PARTIAL, iOS private seams:** raw SimulatorKit surfaces and DTUHID touch plus
  one USB keyboard usage work under both tested toolchains. General text input,
  interaction latency, long-run and restart/rotation stability, drag/multitouch,
  coordinate mapping, keyboard-up/modifier behavior, production-signing
  constraints, and fail-closed behavior on ABI drift remain unproven.

The first two items are now closed by Step 9. The gate remains closed until one
executable matrix proves all of:

1. **Closed:** one real scrcpy source feeds both the existing local renderer and
   the WebRTC track through the selected shared lifecycle;
2. **Closed:** authenticated fingerprint comparison and tamper rejection pass
   through a bounded authorized Sesori signaling route;
3. claim-revision/release/archive-driven input rejection and peer closure;
4. capture-to-display, input-to-visible, reconnect/revocation, resource, and
   Sesori request/SSE latency distributions on release-target clients;
5. representative LAN and externally operated TURN paths; and
6. complete dependency acceptance, including transitive notices, supported
   platform policy, and a defensible maintenance/version-pinning plan.

Closing those Android-first conditions does not enable iOS. iOS additionally
requires sustained frame/input runs across rotation and restart, repeated touch
and keyboard variants, general text, coordinate mapping, latency, production
signing, and deliberate private-ABI failure tests on every claimed toolchain.

### Candidate dependencies and source paths

- The Flutter client candidate is `flutter_webrtc 1.6.0` (MIT), which currently
  pins native WebRTC `144.7559.09`. Disposable macOS and Android debug clients
  built and ran. Android requires `INTERNET`, `ACCESS_NETWORK_STATE`,
  `CHANGE_NETWORK_STATE`, and `MODIFY_AUDIO_SETTINGS`; omitting
  `ACCESS_NETWORK_STATE` caused the native network monitor to abort. The plugin
  also emits a forward-compatibility warning because it still applies the Kotlin
  Gradle plugin instead of Built-in Kotlin.
- The Device Canvas candidate is `stasel/WebRTC 151.0.0` (WebRTC BSD-3 license).
  Its release XCFramework is 42.6 MiB compressed, 95.7 MiB unpacked, and its
  universal macOS binary is 27.1 MiB. The actively maintained LiveKit build was
  also reviewed, but its 63.5 MiB archive and 141.3 MiB unpacked footprint add no
  required API for this separate-process integration. These build, API, license,
  and size checks do not by themselves close the full dependency gate.
- The selected public ObjC API accepts decoded `CVPixelBuffer` frames through
  `RTCVideoSource`/`RTCCVPixelBuffer`; it exposes no stable encoded-H.264 track
  injection API. Android therefore keeps scrcpy Annex-B H.264 for local
  `AVSampleBufferDisplayLayer` rendering and adds a VideoToolbox decode feeding
  WebRTC's encoder. Production versions remain exactly pinned and retain binary
  license notices.

### Measured evidence

- A real Pixel 10 Pro Android 17 scrcpy 4.1 source produced 210 constrained-
  baseline H.264 frames over 25.57 seconds, including live rotation between
  `716x1600` and `1600x716`, at 739 kbit/s. The mostly static workload was VFR at
  8.21 frames/s; it is not a release frame-rate measurement.
- Copying the H.264 source took 0.07 seconds and 22.0 MiB peak RSS. VideoToolbox
  decode took 0.36 seconds and 85.5 MiB peak RSS. Decode plus H.264 VideoToolbox
  re-encode took 0.77 seconds and 127.7 MiB peak RSS, processing about 273 source
  frames/s. Source timestamps caused duplicate/drop warnings, so production must
  stamp decoded WebRTC frames from one monotonic host clock.
- During a separate real-time file re-encode and repeated emulator input, the
  existing local Device Canvas renderer and scrcpy process stayed alive. Device
  Canvas averaged 14.8% of one host core, peaked at 35.6%, and held 56.6-58.1 MiB
  RSS; the separate re-encode process averaged 0.6%, peaked at 3.2%, and reached
  about 116 MiB RSS. The re-encode process wrote to `/dev/null`; it did not
  consume the live renderer's access units or feed WebRTC, so this is only a
  coexistence baseline.
- A native WebRTC 151 peer generating synthetic `640x360` frames and a Flutter
  WebRTC peer negotiated H.264, a reliable ordered DataChannel, SDP fingerprints,
  DTLS `TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256`, and SRTP AES-128. Direct host ICE
  rendered its first frame 209 ms after remote-description application and had
  input acknowledgement p95 of 25.4 ms. Local coturn relay rendered in 307 ms
  with 27.2 ms input p95.
- An Android-emulator client behind emulator NAT selected relay/relay candidates
  through local coturn, decoded 67 frames, acknowledged 128 ordered inputs, and
  rejected input sent after test revocation. First frame was 1.67 seconds after
  remote-description application because the non-trickle harness deliberately
  settled both relay candidates; input p95 was 47.0 ms. The client peaked at
  268 MiB PSS and 379 MiB RSS during startup/streaming.
- A connected bridge test now joins encrypted relay framing, exact connection
  incarnation, persisted claim revision, authenticated loopback IPC, parser-valid
  SDP, fingerprint tamper rejection, correlated answer delivery, claim-release
  revocation, and post-release denial. Exact late responses are bounded and
  ignored without disconnecting an unrelated current Canvas peer.
- The production Device Canvas path reuses the live scrcpy Annex-B source for the
  local renderer and VideoToolbox decode into a pinned WebRTC 151 peer. A real
  emulator smoke delivered 295 remote frames at `534x1200` while preserving the
  `716x1600` local two-plane buffer, then stopped remote delivery on revocation.
  Decoder input and native work in flight are bounded; discontinuities reset to a
  requested keyframe. Remote control and DataChannel input remain disabled.
- Local coturn proves the relay protocol and emulator-NAT topology. Arbitrary-
  network reliability, short-lived credential issuance, and external TURN
  operations remain Step 10 release gates.

### iOS feasibility matrix

| Host toolchain | Raw frame result | Input result | Selected seam |
|---|---|---|---|
| Xcode 26.6 (`17F113`), iOS 26.5 runtime | `SimDeviceScreen` exposed live `1206x2622` BGRA IOSurfaces at 59.97 callbacks/s | DTUHID touch and USB-keyboard events changed a UIKit probe | SimulatorKit under `Developer/Library/PrivateFrameworks`; DeviceKit unavailable |
| Xcode 27 beta 5 (`27A5237l`), iOS 26.5 runtime | Same IOSurface shape at 59.93 callbacks/s | Same DTUHID touch and single-key-to-text behavior | SimulatorKit under `Contents/SharedFrameworks`; DeviceKit 255 remains local-view-only |

Public `simctl screenshot` averaged 444 ms under Xcode 26.6 and 367 ms under
Xcode 27 beta 5, which is too slow for interactive raw capture. Public
`recordVideo` produced H.264 at about 60 frames/s and remains an encoded fallback,
not the selected low-latency source. The iOS provider uses private
`SimulatorKit.SimDeviceScreen.unmaskedSurface` and the private DTUHID XPC service;
its compile shim requires library evolution. The ad hoc probe executed without a
private entitlement, but production signing and capability discovery have not
yet proved fail-closed behavior when either ABI changes.

### Provisional release targets

These candidate thresholds constrain the eventual release design, but the
required distributions have not all been measured and therefore they do not
close the entry gate:

| Metric | Candidate target |
|---|---|
| Stream start to first frame | p95 <= 1 second on direct LAN; p95 <= 3 seconds through TURN |
| Steady capture-to-display latency | p95 <= 250 ms on direct LAN; p95 <= 500 ms through TURN |
| Ordered input acknowledgement | p95 <= 100 ms direct or TURN |
| Input-to-visible-response latency | p95 <= 250 ms direct; p95 <= 500 ms through TURN |
| Android video | H.264, maximum dimension 1600, nominal 30 frames/s under active animation, >= 20 frames/s floor, <= 4 Mbit/s |
| Revocation | reject new input within 250 ms of Device Canvas receiving revocation and close the peer within 1 second |
| Release-host overhead | <= 200 MiB incremental RSS and <= 50% of one logical core averaged over 30 seconds |
| Mobile-client overhead | <= 450 MiB total RSS, <= 325 MiB PSS, and <= one logical core averaged over 30 seconds |
| Sesori responsiveness | active streaming adds no more than 100 ms or 25%, whichever is greater, to request/SSE p95 latency |

The gate-closing matrix must measure distributions from capture timestamp to
display and from input send to visible frame response. Setup latency and
DataChannel acknowledgements are only Step 8 baselines and cannot substitute for
those measurements. The thresholds become fixed only after that matrix shows
they are attainable on every claimed release target.

## Security And Privacy

- Claims and stream leases are authorized against the current account, bridge,
  canonical session, and claim revision.
- Local IPC is loopback-only with an owner-readable rotating secret. It receives
  no Sesori JWT or room key.
- The E2E relay channel authenticates signaling and DTLS fingerprints.
- Video and input are encrypted end-to-end by WebRTC; TURN relays ciphertext.
- No media is sent through transcript/attachment endpoints or push notifications.
- No prompts, transcripts, source paths, titles, raw identifiers, raw errors, or
  frames enter analytics.
- Local logs may retain device/session operation context needed for diagnosis,
  but remote presentation and analytics use bounded privacy-safe categories.
- A remote stream begins only from an explicit authenticated user action in the
  owning session. An agent claim alone cannot start screen sharing.

## Analytics Assessment

Phase 1 should consider one authoritative outcome event only if it answers
adoption: whether a claim succeeded, conflicted, or was unsupported, with bounded
platform/backend categories and no IDs or titles. Do not track badge taps.

Phase 2 may consider stream-start success/failure and coarse direct/TURN outcome
only if it informs reliability and rollout. Never report duration together with
device/session identity, codec payload, input, frame content, or raw error text.

The implementation step must load the repository analytics skill before adding
any event. No analytics event is mandated by this plan.

## Complexity Budget

### Phase 1 allowed mutable parts

1. One durable claim table, one bounded per-bridge revision-counter table, and
   one DAO boundary.
2. One bridge claim repository/service boundary.
3. One current Device Canvas inventory projection in bridge memory.
4. One authenticated local IPC peer and heartbeat lifecycle.
5. One Device Canvas ephemeral claim projection.
6. Existing client session-detail state extended through normal layers.
7. One backend adapter per backend actually claimed as supported.

Do not add a generic extension registry, distributed lock, claim event store,
per-surface claim cache, retry job, Device Canvas database, or second claim
authority.

### Phase 2 allowed mutable parts

1. One ephemeral interactive stream lease per controlled device.
2. One peer connection and input channel per active lease.
3. One Device Canvas Android media/control provider.
4. Existing client session-detail state extended for one viewport.
5. Bounded signaling requests and local IPC messages.

Do not persist peer state, add media replay, multiplex frames into RelayMessage,
or add iOS production machinery before its gate passes. If implementation needs
a general media-job framework, multi-viewer synchronization, a second media
protocol, or a relay-server video tunnel, stop and revise this plan first.

## Delivery Plan

| Step | Repository | Exact PR title / delivery label | Scope |
|---|---|---|---|
| 1/12 | Sesori | `🌱 [device-canvas-integration] docs: plan session-owned simulators [step 1/12]` | Add this reviewed plan and tracker only. |
| 2/12 | Sesori | `⚙️ [device-canvas-integration] feat(bridge): persist simulator claims [step 2/12]` | Add claim migration, DAO, repository, service, session lifecycle cleanup, and focused tests without a client or Device Canvas transport. |
| 3/12 | Sesori | `⚙️ [device-canvas-integration] feat(bridge): connect Device Canvas inventory [step 3/12]` | Add authenticated loopback IPC, rendezvous secret, inventory/presence state, claim projection, lifecycle wiring, and tests. |
| 4/12 | Device Canvas | `[device-canvas-integration] show claimed Sesori sessions [step 4/12]` | Add IPC client, inventory publication, ephemeral claim projection, pane badge, accessibility, deep-link action, and protocol tests. |
| 5/12 | Sesori | `⚙️ [device-canvas-integration] feat(client): open claimed simulator sessions [step 5/12]` | Add additive bridge/client contracts, client layering, session status UI, custom session deep links, macOS registration, and tests. Keep first writer and reader in this compatibility slice. |
| 6/12 | Sesori | `⚙️ [device-canvas-integration] feat(opencode): let sessions claim simulators [step 6/12]` | Add OpenCode-native list/claim/release tools bound to canonical session identity and verify agent behavior. |
| 7/12 | Sesori + Device Canvas | `🌿 [device-canvas-integration] test: verify simulator ownership [step 7/12]` | Reconcile regression docs, run Phase 1 compatibility/restart/conflict/deep-link matrix, and record evidence before remote-media work. |
| 8/12 | Device Canvas + Sesori | `🚧 [device-canvas-integration] test: prove remote simulator transport [step 8/12]` | Run Android source, WebRTC/network, and iOS feasibility spikes; record dependency, TURN, performance, and iOS go/no-go decisions. No production claim beyond evidence. |
| 9/12 | Sesori | `🚧 [device-canvas-integration] feat(bridge): authorize remote simulator streams [step 9/12]` | Add additive capabilities, ephemeral leases, bounded signaling, local IPC forwarding, claim-revision fencing, and tests. |
| 10/12 | Infrastructure | `[device-canvas-integration] provision encrypted media relay [step 10/12]` | Provision STUN/TURN, short-lived credential issuance, observability, abuse limits, and remote-network verification without media decryption. |
| 11/12 | Device Canvas | `[device-canvas-integration] stream and control Android emulators [step 11/12]` | Add the evidence-selected Android WebRTC source, DataChannel input, revocation, orientation, local rendering preservation, and tests. |
| 12/12 | Sesori | `🚧 [device-canvas-integration] feat(client): control claimed simulators remotely [step 12/12]` | Add the Flutter viewport, lifecycle/input/accessibility behavior, cumulative Phase 2 matrix, regression docs, compatibility evidence, and plan retirement. |

Every Sesori production step requires the owning package's focused tests and
strict analysis. Generated files are changed only through their source and
generator. Device Canvas steps require `zsh build.sh` plus real local use with
supported simulators/emulators. Media steps require end-to-end use across the
actual network paths, not source inspection alone.

Conditional iOS implementation is a separately planned series after follow-up
evidence closes its private-API gate. It is not silently folded into Steps 9-12.

## Regression Documentation

Phase 1 adds a dedicated regression document for Device Canvas ownership and
updates, where necessary:

- `docs/regression/projects-and-sessions.md` for session claim projection and
  deep-link behavior;
- `docs/regression/bridge-connectivity.md` for local integration presence,
  restart, and bridge takeover;
- plugin/runtime documentation only for adapters actually shipped.

Phase 2 extends the dedicated document with stream authorization, claim-revision
fencing, lifecycle, TURN/direct connectivity, input, and capability degradation.
Security documentation is updated for local IPC, WebRTC signaling, SRTP,
DataChannel input, and TURN trust boundaries.

## Architecture Review History

An `architecture-plan-review` sub-agent reviewed the draft on 2026-08-18 and
rejected six under-specified boundaries. This plan applies those findings
directly without a second review, following repository policy:

1. Deep links extend `DeepLinkService` and enter a narrow projectless resolver
   before replacing themselves with `AppRouteSessionDetail`; they do not add a
   second detail surface.
2. Claim projections and links carry bridge scope while durable ownership remains
   local to the bridge database.
3. Local IPC specifies credential bootstrap, loopback enforcement, one-peer
   behavior, and secret isolation.
4. Persistence follows table/DAO -> repository -> service -> transport layers.
5. Relay requests carry signaling only; media and input remain on WebRTC.
6. scrcpy and DeviceKit stay owned by Device Canvas, with iOS behind a strict
   feasibility gate.

Oracle architecture consultation independently agreed with the bridge-owned
claim authority, backend-neutral service, per-backend adapters, Android-first
media plan, separate WebRTC media plane, and iOS gate.

## Risks And Accepted Limits

- Device Canvas depends on unsupported private DeviceKit and may require changes
  for every Xcode build. Phase 1 claims remain useful even if iOS rendering
  temporarily degrades.
- No universal autonomous-tool seam exists across Sesori plugins. The first
  release supports OpenCode and makes no broader claim.
- A durable claim can outlive temporary device presence by design. The UI must
  distinguish offline ownership clearly.
- Session archive releases ownership. If product later wants archived sessions to
  retain devices, that is a behavior change requiring explicit migration and
  conflict review.
- Direct WebRTC cannot satisfy arbitrary-network reliability. TURN cost,
  operations, abuse prevention, and jurisdiction are real release dependencies.
- The selected WebRTC APIs do not support Android encoded-H.264 injection.
  VideoToolbox decode/re-encode is the measured path and must synthesize
  monotonic frame timestamps.
- Local and remote input may interleave. The first release arbitrates only remote
  controllers and does not lock out a person using Device Canvas locally.
- iOS raw view/control passed only through private SimulatorKit and DTUHID APIs
  on the recorded matrix. ABI drift disables the capability, and its separate
  delivery remains independent of Android and all Phase 1 behavior.

## Expected Result

After Phase 1, an OpenCode-backed Sesori session can discover and exclusively
claim a local simulator or emulator. The Bridge persists that ownership, Device
Canvas visibly identifies the owning session, and the user can open the exact
bridge-scoped Sesori session from the device pane. Claims survive ordinary
process/device outages and release predictably with session lifecycle.

After Phase 2, the owner can explicitly open an Android emulator viewport from
the Sesori session and control it over an authorized, encrypted,
media-appropriate connection from local or remote networks. Sesori chat remains
responsive, ownership changes revoke access immediately, and iOS remains
unavailable unless a separately planned private-API provider closes its full
evidence gate on every claimed toolchain.
