import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("Device Canvas requests validate bounded identifiers and default reassignment off", () {
    final request = DeviceCanvasClaimRequest.fromJson(const {
      "expectedBridgeId": "bridge-1",
      "sessionId": "session-1",
      "deviceKey": "ios:booted",
    });

    expect(request.reassign, isFalse);
    expect(request.isValid, isTrue);
    expect(
      const DeviceCanvasClaimRequest(
        expectedBridgeId: "bridge-1",
        sessionId: "session-1",
        deviceKey: "ios:booted",
        reassign: true,
        expectedOwnerSessionId: "session-2",
        expectedClaimRevision: 3,
      ).isValid,
      isTrue,
    );
    expect(
      const DeviceCanvasClaimRequest(
        expectedBridgeId: "bridge-1",
        sessionId: "session-1",
        deviceKey: "ios:booted",
        reassign: true,
        expectedOwnerSessionId: null,
        expectedClaimRevision: null,
      ).isValid,
      isFalse,
    );
    expect(
      DeviceCanvasClaimRequest(
        expectedBridgeId: "bridge-1",
        sessionId: "session-1",
        deviceKey: "".padRight(maxDeviceCanvasClientDeviceKeyLength + 1, "x"),
        expectedOwnerSessionId: null,
        expectedClaimRevision: null,
      ).isValid,
      isFalse,
    );
    expect(
      const DeviceCanvasReleaseRequest(
        expectedBridgeId: "bridge-1",
        sessionId: "session-1",
        deviceKey: "ios:booted",
        expectedClaimRevision: 0,
      ).isValid,
      isFalse,
    );
  });

  test("Device Canvas status round-trips independent connection, presence, and ownership", () {
    const response = DeviceCanvasSessionStatusResponse(
      bridgeId: "bridge-1",
      sessionId: "session-1",
      sessionAvailable: true,
      projectId: "project/with spaces",
      connection: DeviceCanvasClientConnectionStatus.connected,
      devices: [
        DeviceCanvasDeviceStatus(
          deviceKey: "ios:booted",
          descriptor: DeviceCanvasClientDescriptor(
            platform: DeviceCanvasClientPlatform.ios,
            displayName: "iPhone",
            runtimeDescription: "iOS 18",
            modelDescription: "iPhone 17 Pro",
            dimensions: DeviceCanvasClientDimensions(width: 390, height: 844),
            orientation: DeviceCanvasClientOrientation.portrait,
            capabilities: DeviceCanvasClientCapabilities(localView: true),
          ),
          claim: DeviceCanvasClaimStatus(
            projectId: "project/with spaces",
            sessionId: "session-1",
            revision: 3,
            claimedAt: 1000,
            displayTitle: "Build",
          ),
        ),
      ],
      supportsReassignment: true,
    );

    expect(DeviceCanvasSessionStatusResponse.fromJson(response.toJson()), response);
  });

  test("Device Canvas status decodes omitted additive fields and unknown enum values safely", () {
    final omitted = DeviceCanvasSessionStatusResponse.fromJson(const {
      "bridgeId": "bridge-1",
      "sessionId": "session-1",
      "sessionAvailable": false,
      "projectId": null,
    });
    final unknown = DeviceCanvasSessionStatusResponse.fromJson(const {
      "bridgeId": "bridge-1",
      "sessionId": "session-1",
      "sessionAvailable": false,
      "projectId": null,
      "connection": "future-state",
    });

    expect(omitted.connection, DeviceCanvasClientConnectionStatus.unknown);
    expect(omitted.devices, isEmpty);
    expect(omitted.supportsReassignment, isFalse);
    expect(unknown.connection, DeviceCanvasClientConnectionStatus.unknown);
  });

  test("Device Canvas invalidation event uses an additive normalized SSE type", () {
    const event = SesoriSseEvent.deviceCanvasChanged();

    expect(event.toJson(), {"type": "device_canvas.changed"});
    expect(SesoriSseEvent.fromJson(event.toJson()), event);
  });

  test("RTC descriptions require one matching bounded SHA-256 fingerprint line", () {
    final crlfOffer = _description(type: DeviceCanvasRtcDescriptionType.offer, lineEnding: "\r\n");
    final lfOffer = _description(type: DeviceCanvasRtcDescriptionType.offer, lineEnding: "\n");

    expect(crlfOffer.isValid, isTrue);
    expect(lfOffer.isValid, isTrue);
    expect(
      crlfOffer.copyWith(sdp: "${crlfOffer.sdp}a=fingerprint:$_fingerprint\r\n").isValid,
      isFalse,
    );
    expect(crlfOffer.copyWith(fingerprint: _otherFingerprint).isValid, isFalse);
    expect(crlfOffer.copyWith(fingerprint: "sha-256 00:11").isValid, isFalse);

    const fingerprintLine = "a=fingerprint:$_fingerprint\n";
    final exactLimit = crlfOffer.copyWith(
      sdp: fingerprintLine.padRight(maxDeviceCanvasRtcSdpBytes, "x"),
    );
    expect(exactLimit.isValid, isTrue);
    expect(exactLimit.copyWith(sdp: "${exactLimit.sdp}x").isValid, isFalse);
  });

  test("ICE candidates and TURN configuration enforce collection and field bounds", () {
    const candidate = DeviceCanvasIceCandidate(candidate: "candidate:1", sdpMid: "0", sdpMLineIndex: 0);
    final turn = DeviceCanvasTurnConfiguration(
      urls: List.generate(maxDeviceCanvasTurnUrls, (index) => "turn:relay-$index.example.com"),
      username: "user",
      credential: "secret",
      expiresAt: 1,
    );

    expect(candidate.isValid, isTrue);
    expect(candidate.copyWith(candidate: "x" * maxDeviceCanvasIceCandidateLength).isValid, isTrue);
    expect(candidate.copyWith(candidate: "x" * (maxDeviceCanvasIceCandidateLength + 1)).isValid, isFalse);
    expect(candidate.copyWith(sdpMLineIndex: -1).isValid, isFalse);
    expect(turn.isValid, isTrue);
    expect(turn.copyWith(urls: [...turn.urls, "turn:extra.example.com"]).isValid, isFalse);
    expect(turn.copyWith(credential: "").isValid, isFalse);
    expect(
      turn.copyWith(username: "u" * maxDeviceCanvasTurnUsernameByteCount).isValid,
      isTrue,
    );
    expect(
      turn.copyWith(username: "u" * (maxDeviceCanvasTurnUsernameByteCount + 1)).isValid,
      isFalse,
    );
    expect(turn.copyWith(username: "é" * 254).isValid, isTrue);
    expect(turn.copyWith(username: "é" * 255).isValid, isFalse);
  });

  test("TURN URLs canonicalize the native-compatible DNS, IP, port, and transport subset", () {
    const turn = DeviceCanvasTurnConfiguration(
      urls: [
        "TURN:TURN.EXAMPLE.TEST.:03478?TRANSPORT=UDP",
        "turn:192.168.1.9?transport=tcp",
        "turns:[2001:0DB8:0:0:0:0:0:1]",
      ],
      username: "user",
      credential: "secret",
      expiresAt: 1000,
    );

    expect(turn.isValid, isTrue);
    expect(turn.canonicalUrls, const [
      "turn:turn.example.test:3478?transport=udp",
      "turn:192.168.1.9:3478?transport=tcp",
      "turns:[2001:db8::1]:5349?transport=tcp",
    ]);
    expect(canonicalizeDeviceCanvasTurnUrl("turn:[::1]"), "turn:[::1]:3478?transport=udp");
    expect(canonicalizeDeviceCanvasTurnUrl("turn:[::]"), "turn:[::]:3478?transport=udp");
  });

  test("TURN URLs reject malformed, duplicate, and alternate numeric endpoints", () {
    const invalid = [
      "https:turn.example.test",
      "turn://turn.example.test",
      "turn:user@turn.example.test",
      "turn:turn.example.test/path",
      "turn:turn.example.test?transport=ws",
      "turns:turn.example.test?transport=udp",
      "turn:turn.example.test:0",
      "turn:127.000.0.1",
      "turn:127.1",
      "turn:0x7f000001",
      "turn:[::ffff:192.168.1.9]",
      "turn:[::ffff:c0a8:109]",
      "turn:[::c0a8:109]",
      "turn:[0:0:0:0:ffff:0:c0a8:109]",
      "turn:turn example.test",
    ];
    for (final url in invalid) {
      expect(canonicalizeDeviceCanvasTurnUrl(url), isNull, reason: url);
    }

    const duplicates = DeviceCanvasTurnConfiguration(
      urls: [
        "turn:TURN.EXAMPLE.TEST",
        "turn:turn.example.test:03478?transport=udp",
      ],
      username: "user",
      credential: "secret",
      expiresAt: 1000,
    );
    expect(duplicates.isValid, isFalse);
  });

  test("stream prepare requires exact opaque correlation and a complete TURN payload", () {
    const request = DeviceCanvasStreamPrepareRequest(
      expectedBridgeId: "bridge-1",
      sessionId: "session-1",
      deviceKey: "android:emulator-1",
      expectedClaimRevision: 4,
      operationId: "operation-1",
      leaseId: "lease_1",
      control: false,
    );
    const turn = DeviceCanvasTurnConfiguration(
      urls: ["turn:relay.example.com"],
      username: "1000:operation-1",
      credential: "secret",
      expiresAt: 1000,
    );
    const prepared = DeviceCanvasStreamPrepareResponse(
      outcome: DeviceCanvasStreamPrepareOutcome.prepared,
      leaseId: "lease_1",
      expiresAt: 1000,
      turn: turn,
    );

    expect(request.isValid, isTrue);
    expect(DeviceCanvasStreamPrepareRequest.fromJson(request.toJson()), request);
    expect(request.copyWith(leaseId: "not an opaque id").isValid, isFalse);
    expect(prepared.isValid, isTrue);
    expect(DeviceCanvasStreamPrepareResponse.fromJson(prepared.toJson()), prepared);
    expect(prepared.copyWith(expiresAt: 999).isValid, isFalse);
    expect(prepared.copyWith(outcome: DeviceCanvasStreamPrepareOutcome.unavailable).isValid, isFalse);
    expect(
      const DeviceCanvasStreamPrepareResponse(
        outcome: DeviceCanvasStreamPrepareOutcome.unsupported,
        leaseId: null,
        expiresAt: null,
        turn: null,
      ).isValid,
      isTrue,
    );
    expect(
      DeviceCanvasStreamPrepareResponse.fromJson(const {"outcome": "future"}).isValid,
      isFalse,
    );
  });

  test("stream start request validates identity, offer type, and candidate count", () {
    const candidate = DeviceCanvasIceCandidate(candidate: "candidate:1", sdpMid: "0", sdpMLineIndex: 0);
    final request = DeviceCanvasStreamStartRequest(
      expectedBridgeId: "bridge-1",
      sessionId: "session-1",
      deviceKey: "android:emulator-1",
      expectedClaimRevision: 4,
      operationId: "operation-1",
      leaseId: null,
      control: true,
      offer: _description(type: DeviceCanvasRtcDescriptionType.offer),
      iceCandidates: List.filled(maxDeviceCanvasIceCandidates, candidate),
    );

    expect(request.isValid, isTrue);
    expect(request.copyWith(expectedClaimRevision: 0).isValid, isFalse);
    expect(request.copyWith(operationId: "not an opaque id").isValid, isFalse);
    expect(request.copyWith(leaseId: "lease-1").isValid, isTrue);
    expect(request.copyWith(leaseId: "not a lease").isValid, isFalse);
    expect(request.copyWith(offer: _description(type: DeviceCanvasRtcDescriptionType.answer)).isValid, isFalse);
    expect(request.copyWith(iceCandidates: [...request.iceCandidates, candidate]).isValid, isFalse);

    final status = DeviceCanvasStreamStatusRequest(
      expectedBridgeId: request.expectedBridgeId,
      sessionId: request.sessionId,
      deviceKey: request.deviceKey,
      expectedClaimRevision: request.expectedClaimRevision,
      operationId: request.operationId,
    );
    expect(status.isValid, isTrue);
    expect(status.copyWith(operationId: "").isValid, isFalse);
  });

  test("flattened stream responses require complete active payloads and empty inactive payloads", () {
    final answer = _description(type: DeviceCanvasRtcDescriptionType.answer);
    final started = DeviceCanvasStreamStartResponse(
      outcome: DeviceCanvasStreamStartOutcome.started,
      leaseId: "lease-1",
      expiresAt: 1000,
      answer: answer,
      turn: null,
    );

    expect(started.isValid, isTrue);
    expect(started.copyWith(leaseId: "").isValid, isFalse);
    expect(started.copyWith(answer: _description(type: DeviceCanvasRtcDescriptionType.offer)).isValid, isFalse);
    expect(
      started.copyWith(outcome: DeviceCanvasStreamStartOutcome.unavailable).isValid,
      isFalse,
    );
    expect(
      const DeviceCanvasStreamStatusResponse(
        outcome: DeviceCanvasStreamStatusOutcome.inactive,
        leaseId: null,
        expiresAt: null,
        answer: null,
        turn: null,
        offerFingerprint: null,
      ).isValid,
      isTrue,
    );
    expect(
      DeviceCanvasStreamStatusResponse(
        outcome: DeviceCanvasStreamStatusOutcome.active,
        leaseId: "lease-1",
        expiresAt: 1000,
        answer: answer,
        turn: null,
        offerFingerprint: _otherFingerprint,
      ).isValid,
      isTrue,
    );
    expect(
      DeviceCanvasStreamStatusResponse(
        outcome: DeviceCanvasStreamStatusOutcome.active,
        leaseId: "lease-1",
        expiresAt: 1000,
        answer: answer,
        turn: null,
        offerFingerprint: "sha-256 invalid",
      ).isValid,
      isFalse,
    );
    expect(
      const DeviceCanvasStreamStatusResponse(
        outcome: DeviceCanvasStreamStatusOutcome.inactive,
        leaseId: null,
        expiresAt: null,
        answer: null,
        turn: null,
        offerFingerprint: _fingerprint,
      ).isValid,
      isFalse,
    );
    expect(
      DeviceCanvasStreamStartResponse.fromJson(const {"outcome": "future"}).outcome,
      DeviceCanvasStreamStartOutcome.unknown,
    );
    expect(
      DeviceCanvasStreamStopResponse.fromJson(const {"outcome": "future"}).isValid,
      isFalse,
    );
  });

  test("stream signaling diagnostics do not expose SDP, candidates, or credentials", () {
    final answer = _description(type: DeviceCanvasRtcDescriptionType.answer);
    const candidate = DeviceCanvasIceCandidate(
      candidate: "candidate:private-address",
      sdpMid: "private-mid",
      sdpMLineIndex: 0,
    );
    const turn = DeviceCanvasTurnConfiguration(
      urls: ["turn:private-relay"],
      username: "private-user",
      credential: "private-credential",
      expiresAt: 4_000_000_000_000,
    );
    final response = DeviceCanvasStreamStartResponse(
      outcome: DeviceCanvasStreamStartOutcome.started,
      leaseId: "lease-private",
      expiresAt: 4_000_000_000_000,
      answer: answer,
      iceCandidates: const [candidate],
      turn: turn,
    );
    const prepare = DeviceCanvasStreamPrepareResponse(
      outcome: DeviceCanvasStreamPrepareOutcome.prepared,
      leaseId: "lease-private",
      expiresAt: 4_000_000_000_000,
      turn: turn,
    );
    final diagnostics = [answer, candidate, turn, prepare, response].join("\n");

    expect(diagnostics, isNot(contains(_fingerprint)));
    expect(diagnostics, isNot(contains("candidate:private-address")));
    expect(diagnostics, isNot(contains("private-credential")));
    expect(diagnostics, isNot(contains("lease-private")));
  });
}

const _fingerprint =
    "sha-256 00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:10:21:32:43:54:65:76:87:98:A9:BA:CB:DC:ED:FE:0F";
const _otherFingerprint =
    "sha-256 FF:EE:DD:CC:BB:AA:99:88:77:66:55:44:33:22:11:00:0F:1E:2D:3C:4B:5A:69:78:87:96:A5:B4:C3:D2:E1:F0";

DeviceCanvasRtcDescription _description({
  required DeviceCanvasRtcDescriptionType type,
  String lineEnding = "\n",
}) => DeviceCanvasRtcDescription(
  type: type,
  sdp: "v=0${lineEnding}a=fingerprint:$_fingerprint$lineEnding",
  fingerprint: _fingerprint,
);
