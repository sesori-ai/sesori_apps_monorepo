# Device Canvas Ownership

## Capability

Bridge-authoritative ownership of locally discovered Device Canvas simulators,
including client presentation, exact-session deep links, and OpenCode-native
list, claim, and release tools.

## Required Behavior

- The bridge database is the only claim authority. Claims are scoped to the
  current bridge identity and canonical `Session.id`; presence and Device Canvas
  connectivity are independent ephemeral state.
- A first claim succeeds, a repeat by the same session is idempotent, and a
  different session conflicts without stealing. Release is owner-scoped and
  idempotent. Only an authenticated human reassignment path can replace an
  owner; agent tools never accept force, bridge identity, or canonical session
  identity as model input.
- Device Canvas publishes bounded inventory through authenticated loopback IPC.
  Disconnect and device stop change availability without releasing ownership.
  Explicit release, session archive or deletion, and bridge-identity replacement
  remove the applicable claims.
- Client status keeps online presence separate from ownership and degrades when
  used with an older unsupported bridge. A Device Canvas deep link carries the
  exact bridge and session identity, resolves the canonical project before
  opening session detail, and loads no session content before verification.
- When the bridge-side agent-tool server starts and secure managed-runtime
  injection succeeds, OpenCode exposes exactly `list_simulators`,
  `claim_simulator`, and `release_simulator`. Otherwise it receives no Device
  Canvas capability. The adapter binds trusted invocation `context.sessionID` to
  the stored `(pluginId, backendSessionId)` session before calling the neutral
  claim service. Results expose bounded device metadata and only ownership
  relative to the caller, never another session's identity, project, path,
  prompt, or transcript.
- The OpenCode adapter uses a loopback-only server, an owner-readable
  rendezvous, and a bridge-generated bootstrap credential exchanged for an
  in-memory bearer token. Each OpenCode spawn receives only the path to an
  owner-only one-time credential file; registration consumes that file. The
  credential itself never enters the child environment, capability paths are
  removed from process and shell environments by the loaded adapter, and
  nothing is forwarded when injection fails.
- OpenCode startup writes only bridge-managed plugin/config files. It warms the
  native tool registry and requires an authenticated readiness marker before a
  configured managed runtime is healthy. Device Canvas disconnection
  hard-disables operations with a typed unavailable result; bridge shutdown
  stops intake, drains accepted work, and removes the rendezvous file.
- The Sesori mobile client exposes a Device Canvas `Watch` action only when built
  with `DEVICE_CANVAS_LAN_VIDEO=true`, the current session owns a present Android
  device with `remoteVideo`, and the bridge is connected. The default build has
  no reachable viewport action.
- The gated viewport sends a receive-only offer with `control: false`, starts no
  DataChannel and requests no camera or microphone. It owns one ephemeral peer
  and closes on explicit exit, modal disposal, backgrounding, relay loss,
  ownership/capability change, peer failure, timeout, or lease expiry. Every
  local expiry sends the exact idempotent stop request so phone/bridge clock skew
  cannot strand a sender or controller slot.
- Direct validation signaling retains only private/link-local/ULA/mDNS host
  candidates and strips globally routed, server-reflexive, and relay candidates.
  Candidate foundation, component, transport, priority, address, port, type,
  extension, mDNS, and IPv6-zone syntax is validated before native WebRTC, and
  IPv6 classification uses parsed address bytes rather than textual prefixes.
  In direct mode, any TURN-bearing response fails closed.
- A second default-off development define, `DEVICE_CANVAS_LOCAL_TURN=true`,
  changes only the gated video peer to relay-only ICE. Before creating an offer,
  the client generates an operation and lease ID and calls the authenticated
  prepare route. Bridge reserves that exact controller tuple, mints a short-lived
  coturn REST credential from an owner-only secret file, holds the exact TURN DTO
  in memory, and forwards it unchanged to Device Canvas only when start consumes
  the reservation. Host and reflexive candidates are rejected in this mode.
  The hidden issuer accepts one private/link-local IP endpoint, requires at least
  32 secret bytes in a directory inaccessible to other users, and bounds pending
  authorization work. Prepare/start races, timeout, disconnect, claim change,
  stop, expiry, and shutdown remove the reservation; credentials, SDP,
  candidates, and leases are never persisted or emitted through diagnostics,
  rendezvous, or analytics.
- A separate `DEVICE_CANVAS_EXTERNAL_TURN_TEST=true` development gate permits
  that same relay-only path to target canonical DNS coturn URLs before the
  auth issuer is deployed. The Bridge requires separately named hidden URL and
  owner-only secret-file flags, reuses the bounded local HMAC issuer, and never
  sends the static secret to a client. This mode cannot be combined with local or
  production TURN and is external-network evidence only, not deployed credential
  service evidence.
- Production relay selection is a separate default-off
  `DEVICE_CANVAS_PRODUCTION_TURN=true` client define and Bridge environment gate;
  the existing LAN-video define is still required. The Bridge first authorizes
  the exact claim/lease locally, then calls the authenticated auth-server issuer
  with its registered bridge ID. One 401 forces one token refresh; the request is
  aborted after 10 seconds. The response must contain canonical production DNS
  TURN URLs, a canonical SHA1 credential, the exact operation-bound username,
  and an expiry no later than the lease. Registration change, timeout, malformed
  output, or late completion fails unavailable without promoting or logging the
  reservation. Local, external-test, and production Bridge issuers cannot be
  enabled together.
- Each start has a bounded random operation ID; status is accepted only for that
  operation and when its echoed offer fingerprint matches the current peer.
  Start and prepare processing are bounded to 15 seconds; a timeout or late
  completion cannot promote the lease. `Live` is announced only after the
  renderer reports its first frame. Native signaling failures expose only
  sanitized runtime categories in diagnostics.
- A durable claim reassignment publishes the committed owner identity before
  projection reads. The stream service immediately closes any lease whose exact
  bridge, session, device, or claim revision no longer matches, including while
  claim projection is delayed.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated bridge coverage proves canonical binding, idempotent claim/release, conflict without reassignment, privacy-safe bounded listing, disconnected behavior, bridge-rotation cleanup, loopback authentication, request bounds, and rendezvous cleanup. OpenCode package coverage proves the exact native tool surface, trusted context use, config isolation, capability stripping, and readiness gating. |
| L2 Routine | Headless bridge with a Device Canvas fixture and two stored OpenCode sessions exercises list, claim, repeat, conflict, wrong-owner release, owner release, archive cleanup, Device Canvas disconnect/reconnect, and bridge restart. A successfully configured live managed OpenCode runtime must advertise exactly the three native tools through its real tool registry; failed injection must advertise none. |
| L3 Release | Live OpenCode agent plus Device Canvas and Sesori client: two real sessions demonstrate relative listing, claim, repeat, conflict, release, inability to act as another canonical session, ownership badges/accessibility, and exact deep-link navigation. Client end to end and live plugin on the release-target bridge host. |
| L4 Extended | Device Canvas and bridge takeover/restart in both orders; device stop/restart; OpenCode crash/restart; malformed, oversized, unauthorized, and stalled local requests; archive/deletion during activity; alternate client platform; older client/new bridge and new client/older bridge degradation. |
| L5 Full | Packaged Sesori and Device Canvas builds across supported bridge hosts with large bounded inventories, multiple concurrent sessions and devices, repeated lifecycle recovery, and every documented compatible version pairing. |

## Phase 1 Verification Evidence

Recorded on 2026-08-25 on the release-target macOS host:

- Bridge and client code generation left no tracked drift. Strict analysis passed
  every bridge and client package; the complete bridge suite passed at 2,781
  tests with two expected host-platform skips, and every client module suite
  passed. The host bridge production build also passed.
- `zsh build.sh` rebuilt Device Canvas and passed its Swift protocol suite. A
  disposable live-simulator run used an iPhone 17 Pro simulator, the actual Device
  Canvas app, and two distinct OpenCode agent sessions to verify list, repeat
  claim, caller-relative ownership, conflict, wrong-owner release rejection,
  owner release, canonical database ownership, and reconnect projection.
- The user-confirmed release pass covered two-device ownership, exact badge and
  deep-link routing, spoof rejection, independent Device Canvas/bridge/mobile
  restarts, device stop/restart, and archive/deletion cleanup.
- Released-baseline compatibility harnesses used the published macOS `v1.4.0`
  bridge artifact and its client source at `be344a56`. The current client
  repository mapped the real old bridge's absent Device Canvas route to
  unsupported. The old client consumed current `device_canvas.changed`, emitted
  its expected nonfatal unknown-event diagnostic, and then processed a known
  heartbeat. Unsupported local protocol versions also failed closed. Current
  live-agent verification used OpenCode `1.18.20`; automated runtime gates retain
  PATH minimum `1.14.49` and managed target `1.18.19`.

## Phase 2 Transport Gate

Step 9 adds locally testable Android video-only streaming, ephemeral stream
leases, and bounded signaling. It does not make a Phase 2 product-release claim.
The gate remains **NO-GO** for input, external TURN, end-to-end latency/resource
distributions, reconnect coverage, complete dependency acceptance, and iOS.

The default-off Sesori LAN viewport is an approved cross-device validation seam,
not Step 12 completion. Build it with
`--dart-define=DEVICE_CANVAS_LAN_VIDEO=true`, open the owning session's Device
Canvas details, and choose `Watch` on its assigned Android device. The phone and
bridge host must share a reachable private/link-local route. Close the preview
before changing claims; also verify that app backgrounding and claim revision
changes close it automatically. Private VPN routes can satisfy the address
filter, so the filter is not an authorization or physical-adjacency proof.

### Development local TURN runbook

The local relay path is a development validation seam, not Step 10 production
infrastructure. On the bridge host, choose its canonical private or link-local
LAN IPv4 and run:

```sh
cd bridge/app
dart run tool/device_canvas_local_turn.dart --lan-ip 192.168.1.10
```

The tool starts the installed `turnserver` with UDP/TCP port 3478 and UDP relay
ports 49160-49200. It creates a random shared secret and coturn configuration in
a mode-0700 temporary directory, marks both files mode 0600, keeps the secret off
process arguments and output, disables coturn credential logging, and deletes the
directory after bounded child shutdown. Coturn limits allocations to 300 seconds,
caps per-user/total allocations and bandwidth, denies every IPv4 peer by default,
and permits only the configured LAN IP so the two same-host relay allocations can
reach each other. Allow the listener and relay ports only on the trusted LAN;
this configuration intentionally has no TLS and must not be exposed as an
Internet service.

While the tool remains running, append the printed
`--device-canvas-local-turn-url` and
`--device-canvas-local-turn-secret-file` flags to a source-run Bridge. Build or
run the mobile client with both defines:

```sh
--dart-define=DEVICE_CANVAS_LAN_VIDEO=true \
--dart-define=DEVICE_CANVAS_LOCAL_TURN=true
```

The Bridge reads and validates the nonsymlink owner-only secret once at startup.
The client must prepare before offer creation, both peers must gather only relay
candidates, and the start/status response must echo the exact prepared lease,
expiry, URLs, username, and credential. Repeat explicit close, modal dismissal,
backgrounding, source loss, and claim release/reassignment. This proves the
production signaling and media peers can traverse local coturn; it does not prove
external NAT/cellular reachability, TLS/SNI, public firewall behavior, abuse
limits, observability, or deployed production credential issuance.

### Development external TURN runbook

This default-off seam validates the existing clients and Bridge against public
self-hosted coturn without waiting for auth-server deployment. It deliberately
keeps the REST secret on the coturn host and one isolated development Bridge. It
must not be enabled in a packaged or shared Bridge deployment.

1. Allocate an isolated Linux VM with a stable public IPv4 address. Point a
   canonical name such as `turn-dev.example.com` at it. If Cloudflare manages the
   zone, the record must be DNS-only; Workers, Tunnel, and ordinary proxied DNS do
   not carry TURN. Confirm from the Bridge host that every returned address is
   the intended global VM address; URL parsing deliberately does not resolve DNS
   or treat a hostname as proof of public routing.
2. Open `3478/udp`, `3478/tcp`, `5349/tcp`, and only the selected UDP relay range,
   such as `49160-49200/udp`, in both the cloud and host firewalls. Remove every
   rule after the test VM is retired.
3. Install coturn and a valid certificate chain for the DNS name. Configure the
   service with `fingerprint`, `use-auth-secret`, one high-entropy
   `static-auth-secret`, `max-allocate-lifetime=300`, `stale-nonce=600`, bounded
   user/total quotas and bandwidth, `no-cli`, `no-tcp-relay`, `no-dtls`,
   `no-multicast-peers`, and credential-safe logging. Set `listening-port=3478`,
   `tls-listening-port=5349`, and the exact relay range. For a VM behind 1:1 NAT,
   set `listening-ip` and `relay-ip` to its private address and
   `external-ip=<public>/<private>`; use the directly assigned public address
   when no translation exists. Restrict peer destinations to prevent access to
   loopback, metadata, and internal infrastructure without blocking the relay
   address used by the two allocations.
4. Create the matching Bridge secret file without a trailing newline. Run the
   isolated Bridge as a dedicated non-root account, keep the immediate parent
   directory mode 0700 and the file mode 0600, transfer the token through SSH or
   a secret manager, and never put the static token in an environment variable,
   process argument, shell history, repository file, or client build. These mode
   checks complement, but do not replace, host account and ACL isolation.

```sh
install -d -m 700 "$HOME/.sesori/device-canvas-turn"
umask 077
openssl rand -base64 48 | tr -d '\n' > "$HOME/.sesori/device-canvas-turn/external-secret"
chmod 600 "$HOME/.sesori/device-canvas-turn/external-secret"
```

After coturn and TLS are live, run the bounded smoke utility from `bridge/app`:

```sh
dart run tool/device_canvas_external_turn_smoke.dart \
  --turn-url 'turn:turn-dev.example.com:3478?transport=udp' \
  --turn-url 'turn:turn-dev.example.com:3478?transport=tcp' \
  --turn-url 'turns:turn-dev.example.com:5349?transport=tcp' \
  --secret-file "$HOME/.sesori/device-canvas-turn/external-secret" \
  --ca-file /etc/ssl/cert.pem
```

Use `/etc/ssl/certs/ca-certificates.crt` on distributions whose system CA bundle
is there. Before the encrypted relay test, the utility uses OpenSSL to verify the
TLS certificate chain, hostname, and SNI endpoint. It then reads the static secret
through the same mode checks as Bridge startup, derives a fresh five-minute
operation credential per URL, and runs two 100-byte client-to-client relay
messages with a 30-second process deadline. Only the short-lived credential
reaches `turnutils_uclient`; the static secret is not printed or placed in child
process arguments. Coturn's test client does not itself verify the hostname, so
the separate OpenSSL preflight is required evidence.

Then start one source-run Bridge with production TURN unset and the explicit
external-test gate plus paired hidden options:

```sh
DEVICE_CANVAS_EXTERNAL_TURN_TEST=true \
dart run bin/bridge.dart \
  --device-canvas-external-turn-url 'turn:turn-dev.example.com:3478?transport=udp' \
  --device-canvas-external-turn-url 'turn:turn-dev.example.com:3478?transport=tcp' \
  --device-canvas-external-turn-url 'turns:turn-dev.example.com:5349?transport=tcp' \
  --device-canvas-external-turn-secret-file "$HOME/.sesori/device-canvas-turn/external-secret"
```

Build the isolated validation client with:

```sh
--dart-define=DEVICE_CANVAS_LAN_VIDEO=true \
--dart-define=DEVICE_CANVAS_EXTERNAL_TURN_TEST=true
```

Use exactly one of the local, external-test, or production TURN client defines;
mixed client modes fail closed. The wire behavior is intentionally the same
relay-only prepare flow, so the Bridge remains the authoritative issuer-mode
boundary and the external-test client label is an operator/build convention.

Prove relay-only selection from separate external networks, then block UDP to
exercise TCP/TLS fallback. Repeat explicit close, backgrounding, source loss,
claim release/reassignment, allocation expiry, and Bridge/coturn restart. Record
selected ICE pairs, transport, loss, setup latency, relay traffic, coturn
allocations, and cost without recording credentials, SDP, or user content. This
closes neither deployed auth issuance nor the production abuse, rotation,
monitoring, and rollout gates.

### Production self-hosted TURN deployment gate

The authenticated issuer and Bridge client are implemented, but they are not a
deployed Step 10 claim. Before enabling any production gate:

1. Allocate a dedicated coturn host and canonical DNS name. Publish UDP and TCP
   listeners, a TLS/TCP listener with a valid certificate chain and SNI, and one
   bounded UDP relay range through the host and cloud firewalls.
2. Generate one high-entropy coturn REST `static-auth-secret`; deliver it only to
   coturn and the auth server's encrypted production environment. Never place it
   in Bridge/client configuration, logs, images, analytics, or this repository.
3. Configure coturn fingerprints, REST-secret auth, a 300-second maximum
   allocation lifetime, stale nonces, per-user/total allocation quotas,
   bandwidth capacity, restricted peer ranges, disabled credential logging, and
   a disabled or separately protected CLI.
4. Configure the auth server's `DEVICE_CANVAS_TURN_URLS` with unique canonical
   DNS URLs, set the paired secret and TTL, deploy with
   `DEVICE_CANVAS_TURN_ENABLED=true`, and verify that disabled/partial
   configurations still fail closed.
5. Enable `DEVICE_CANVAS_PRODUCTION_TURN=true` only on an isolated Bridge and
   validation client build. Prove UDP, TCP fallback, TLS/SNI, two carrier or NAT
   shapes, IPv4/IPv6 where supported, allocation expiry, revocation, network
   loss, restart, abuse limits, secret rotation, dashboards/alerts, and bounded
   cost before widening rollout.

The Flutter WebRTC SDK and its generated native registrations remain present in
the app artifact even when the UI flag is off. The flag is rollout reachability,
not dependency exclusion; transitive notices, platform policy, maintenance, and
binary-size acceptance remain open release gates.

- Android keeps scrcpy H.264 for the existing local display and uses
  VideoToolbox decode to `CVPixelBuffer` before WebRTC re-encode. The selected
  public WebRTC ObjC API has no stable encoded-H.264 injection seam. The
  production local-test path now feeds both consumers from one scrcpy source.
- SDP, fingerprints, ICE candidates, TURN fields, lease identity, and claim
  revision remain bounded JSON inside existing encrypted routed requests. Media
  uses DTLS-SRTP and ordered input uses the WebRTC DataChannel; neither belongs
  in `RelayMessage`, request/SSE, transcripts, attachments, or analytics.
- The provisional Android release profile is H.264 with maximum dimension 1600,
  nominal 30 frames/s under active animation, a 20 frames/s floor, and at most 4
  Mbit/s.
  Stream-start p95 must be at most 1 second direct and 3 seconds through TURN.
  Steady capture-to-display p95 must be at most 250 ms direct and 500 ms through
  TURN. Input acknowledgement p95 must be at most 100 ms.
- Revocation must reject new input within 250 ms of Device Canvas receiving it
  and close the peer within 1 second. Active streaming may add no more than 100
  ms or 25%, whichever is greater, to Sesori request/SSE p95 latency.
- Release-host streaming overhead is capped at 200 MiB incremental RSS and 50%
  of one logical core averaged over 30 seconds. A mobile client is capped at 450
  MiB total RSS, 325 MiB PSS, and one logical core averaged over 30 seconds.
- These thresholds are planning hypotheses, not fixed release targets. The
  missing capture-to-display, input-to-visible, revocation, reconnect, and Sesori
  responsiveness distributions must show they are attainable first.
- iOS component probes under Xcode 26.6 and Xcode 27 beta 5 exposed live BGRA
  IOSurfaces at about 60 callbacks/s, activated a UIKit button through DTUHID, and
  entered `a` through USB usage 4. Sustained rotation/restart runs, repeated
  touch and keyboard variants, drag/multitouch, coordinate mapping, general text,
  input latency, production signing, and fail-closed private-ABI containment
  remain unproven, so iOS remote capability remains unavailable.

## Phase 2 Feasibility Evidence

Recorded on 2026-08-25 on the release-target macOS host:

- A real Pixel 10 Pro Android 17 source produced 210 H.264 frames over 25.57
  seconds with live portrait/landscape changes. VideoToolbox decode/re-encode
  processed about 273 source frames/s from wall-clock elapsed time. The local
  Device Canvas renderer stayed connected during a separate file replay to
  `/dev/null`, averaging 14.8% host CPU and 56.6-58.1 MiB RSS. This did not feed
  WebRTC from the live scrcpy source.
- Direct and local-coturn native/Flutter peers using synthetic `640x360` frames
  negotiated H.264, connected DTLS, AES-128 SRTP, and an ordered reliable
  DataChannel. An Android-emulator-NAT run selected relay/relay, acknowledged 128
  ordered inputs at 47.0 ms p95, and rejected input after a local test boolean
  changed. It did not exercise external TURN or claim-bound revocation.
- On 2026-08-27, coturn 4.17.2 started from the production development launcher
  on `192.168.0.39`. `turnutils_uclient` authenticated with the generated REST
  secret and sent two messages/200 bytes through both UDP and TCP TURN transports
  with zero loss under the default-deny same-host peer ACL. HUP shutdown left no
  listener, temporary secret/config directory, or coturn server log.
- User-confirmed physical relay-only testing on 2026-08-27 passed from both
  Android and iOS Sesori clients. Each displayed the Android device's first frame
  and continuous real-time screen updates through development local coturn. This
  proves the bounded local launcher, production relay peers, signaling, and
  physical client path on the trusted LAN, not external TURN behavior.
- On 2026-08-31, a disposable Google Cloud trial `e2-micro` VM in
  `europe-west3-a` ran Ubuntu 24.04 and coturn 4.6.1 behind reserved IPv4
  `34.159.67.140`. A dedicated VPC and matching host firewall exposed only
  `3478/udp`, `3478/tcp`, `5349/tcp`, and `49160-49200/udp`; SSH was reachable
  only through authenticated Google IAP tunneling. Coturn ran as its unprivileged
  service account with REST-secret auth, five-minute allocation lifetime,
  bounded quotas and bandwidth, private/metadata/reserved peer denial, disabled
  CLI, DTLS, and TCP relay, and no secret in process arguments.
- The development-only name `turn-dev.34-159-67-140.sslip.io` resolved only to
  that address. Let's Encrypt issued an ECDSA certificate valid through
  2026-11-29. OpenSSL independently verified its chain, hostname, and SNI before
  the smoke tool loaded the secret; TLS negotiated TLS 1.2 with
  `ECDHE-ECDSA-AES256-GCM-SHA384`. The temporary ACME port was removed after
  issuance, so renewal is deliberately manual.
- The bounded external smoke passed UDP, TCP, and TLS/TCP with fresh five-minute
  credentials and zero packet loss. The recorded average round-trip delays were
  27.5 ms, 52.25 ms, and 51.5 ms respectively. Coturn also survived an explicit
  service restart and a fresh post-restart UDP allocation. This proves public
  coturn authentication, allocation, relay, TLS, firewall, NAT advertisement,
  and restart behavior from the Bridge host; it does not prove Flutter selected
  pairs, separate carrier/NAT shapes, production auth issuance, abuse controls,
  monitoring, or sustained media cost.
- A connected test joins encrypted relay framing, exact connection incarnation,
  claim revision, authenticated local IPC, parser-valid SDP, fingerprint tamper
  rejection, answer correlation, claim-release revocation, and post-release
  denial. Signaling DTO diagnostics are redacted and signaling is not persisted.
- The production Device Canvas path delivered 295 remote frames at `534x1200`
  from the same live source that retained a `716x1600` local two-plane buffer.
  Revocation stopped remote delivery while local presentation remained intact.
- Under Xcode 26.6 and Xcode 27 beta 5, raw iOS frame callbacks measured 59.97/s
  and 59.93/s. Public screenshots averaged 444 ms and 367 ms respectively and
  are not an interactive capture path. Runtime screenshots confirmed DTUHID
  touch and single-key-to-text effects under both toolchains. Xcode 27 beta 5's
  recorded build identifier is `27A5237l`.

The gate remains closed until release-target evidence covers DataChannel input,
representative LAN and external TURN paths, restart/network-loss recovery, and
every required latency/resource distribution. Complete dependency acceptance,
including transitive notices, supported-platform policy, maintenance, and
version pinning, is also required.

## Exploration Guidance

Vary which session claims first, whether devices are iOS or Android, whether a
device or Device Canvas disconnects before or after a mutation, and whether the
bridge or OpenCode restarts while claims exist. Use unrelated canonical and
backend session IDs so an accidental identity shortcut is visible. Restore
claims, sessions, plugin eligibility, and local processes after the run.

## Failure Signals

- A model can provide `sessionId`, `bridgeId`, or force; one session can mutate
  another session's claim; a conflict reveals owner identity or content.
- Device or IPC loss releases ownership, stale bridge identity leaves a durable
  late claim, or archive/deletion leaves an owned device behind.
- Inventory or tool output is unbounded or includes project paths, prompts,
  transcripts, account data, or another session's identity.
- The local server binds beyond loopback, accepts bootstrap/bearer mismatches,
  leaves a rendezvous after shutdown, or exposes credentials to another bridge
  backend or an OpenCode shell when injection is absent or failed.
- A managed OpenCode runtime reports healthy before its configured native
  adapter registers, modifies user/project configuration, advertises extra
  simulator tools, or accepts claims while Device Canvas is unavailable.
- A deep link opens the wrong bridge/session, guesses project identity, or loads
  session content before exact resolution.

## Known Limitations

- Autonomous simulator tools are currently OpenCode-only and require a
  bridge-managed OpenCode process. Attach mode is unchanged because the bridge
  cannot safely inject a trusted invocation adapter into an existing process.
- OpenCode's current plugin API does not dynamically unregister native tools.
  Definitions remain visible after Device Canvas disconnects, but every
  operation is hard-disabled with `integrationUnavailable` until reconnection.
- User-installed OpenCode plugins execute inside the same trusted backend
  process. Capability isolation protects other bridge backends and model shell
  commands; it is not a sandbox against a malicious in-process OpenCode plugin.
- Remote video and control are not yet product behavior. The default-off LAN
  video viewport, development-only local and external-test coturn modes, and
  shared Android production source support cross-device validation, while the
  Phase 2 entry gate remains closed. External Device Canvas client/carrier
  evidence, production credential deployment, DataChannel input,
  reconnect/recovery, cumulative latency/resource and Sesori responsiveness
  distributions, full dependency acceptance, and the formal Step 12 release
  matrix remain unresolved.
- iOS transport depends on private SimulatorKit and DTUHID APIs, not a public
  simulator control contract. Compatibility is limited to the recorded matrix
  until a separately planned implementation expands it.

## Sources

- `bridge/app/lib/src/services/device_canvas_claim_service.dart`
- `bridge/app/lib/src/services/device_canvas_agent_tool_service.dart`
- `bridge/app/lib/src/bridge/device_canvas/`
- `bridge/app/lib/src/services/device_canvas_stream_service.dart`
- `bridge/app/tool/device_canvas_local_turn.dart`
- `bridge/app/tool/device_canvas_external_turn_smoke.dart`
- `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_device_canvas_tools.dart`
- `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_runtime_policy.dart`
- Focused tests under `bridge/app/test/bridge/device_canvas/`,
  `bridge/app/test/bridge/services/`, and
  `bridge/sesori_plugin_opencode/test/runtime/`
- `client/module_core/test/capabilities/relay/relay_client_handshake_replay_test.dart`
- `client/app/lib/core/platform/flutter_device_canvas_video_peer.dart`
- `bridge/app/test/bridge/routing/routed_request_dispatcher_test.dart`
- Active plan: `.plan/active/device-canvas-integration/`
