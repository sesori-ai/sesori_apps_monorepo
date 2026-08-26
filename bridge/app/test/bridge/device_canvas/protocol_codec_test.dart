import "dart:convert";

import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol_codec.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("DeviceCanvasProtocolCodec", () {
    const codec = DeviceCanvasProtocolCodec();

    test("decodes typed hello and encodes outbound messages with type keys", () {
      final message = codec.decodeInbound(
        jsonEncode({
          "type": "hello",
          "protocolVersion": deviceCanvasIpcProtocolVersion,
          "canvasInstanceId": "canvas-a",
          "capabilities": _capabilitiesJson(),
        }),
      );

      expect(message, isA<DeviceCanvasHello>());
      expect(
        jsonDecode(
          codec.encodeOutbound(const DeviceCanvasOutboundMessage.helloAccepted(protocolVersion: 1, bridgeId: "b")),
        ),
        containsPair("type", "helloAccepted"),
      );
    });

    test("does not expose project identity in outbound claims", () {
      final frame = codec.encodeOutbound(
        const DeviceCanvasOutboundMessage.claimsSnapshot(
          claims: [
            DeviceCanvasClaimProjectionDto(
              bridgeId: "bridge",
              sessionId: "session",
              deviceKey: "device",
              revision: 1,
              displayTitle: null,
            ),
          ],
        ),
      );

      expect(frame, isNot(contains("projectId")));
      expect(frame, isNot(contains("/Users/dev/My App")));
    });

    test("decodes valid stream responses and encodes shared RTC stream commands", () {
      final started = codec.decodeInbound(
        jsonEncode({
          "type": "streamStarted",
          "requestId": "request-1",
          "leaseId": "lease-1",
          "answer": _rtcDescriptionJson(type: "answer"),
          "iceCandidates": [_iceCandidateJson()],
        }),
      );

      expect(started, isA<DeviceCanvasStreamStartedMessage>());
      final frame = codec.encodeOutbound(
        DeviceCanvasOutboundMessage.streamStart(
          requestId: "request-1",
          leaseId: "lease-1",
          bridgeId: "bridge",
          sessionId: "session",
          deviceKey: "device",
          claimRevision: 3,
          expiresAt: 1000,
          control: true,
          offer: _rtcDescription(DeviceCanvasRtcDescriptionType.offer),
          iceCandidates: const [],
          turn: null,
        ),
      );

      expect(jsonDecode(frame), containsPair("type", "streamStart"));
      expect(jsonDecode(frame), containsPair("offer", containsPair("type", "offer")));
    });

    test("rejects invalid stream correlations, answers, candidates, and reasons", () {
      final validStarted = <String, Object?>{
        "type": "streamStarted",
        "requestId": "request-1",
        "leaseId": "lease-1",
        "answer": _rtcDescriptionJson(type: "answer"),
        "iceCandidates": <Object?>[],
      };

      expect(
        () => codec.decodeInbound(jsonEncode({...validStarted, "requestId": ""})),
        throwsFormatException,
      );
      expect(
        () => codec.decodeInbound(jsonEncode({...validStarted, "leaseId": "".padRight(129, "x")})),
        throwsFormatException,
      );
      expect(
        () => codec.decodeInbound(
          jsonEncode({...validStarted, "answer": _rtcDescriptionJson(type: "offer")}),
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decodeInbound(
          jsonEncode({
            ...validStarted,
            "iceCandidates": List.filled(maxDeviceCanvasIceCandidates + 1, _iceCandidateJson()),
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decodeInbound(
          jsonEncode({"type": "streamStartFailed", "requestId": "request-1", "leaseId": "lease-1", "reason": "new"}),
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decodeInbound(jsonEncode({"type": "streamClosed", "leaseId": "lease-1", "reason": "new"})),
        throwsFormatException,
      );
    });

    test("rejects malformed, unknown, empty identity, and invalid descriptors", () {
      expect(() => codec.decodeInbound("not-json"), throwsFormatException);
      expect(() => codec.decodeInbound(jsonEncode({"type": "unknown"})), throwsA(isA<Exception>()));
      expect(
        () => codec.decodeInbound(
          jsonEncode({
            "type": "hello",
            "protocolVersion": 1,
            "canvasInstanceId": "",
            "capabilities": _capabilitiesJson(),
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decodeInbound(
          jsonEncode({
            "type": "inventorySnapshot",
            "devices": [
              {..._descriptorJson(), "deviceKey": ""},
            ],
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decodeInbound(
          jsonEncode({
            "type": "inventorySnapshot",
            "devices": [_descriptorJson(), _descriptorJson()],
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decodeInbound(jsonEncode({"type": "heartbeat", "canvasInstanceId": "canvas", "observedAt": 0})),
        throwsFormatException,
      );
    });

    test("rejects oversized frames, inventories, and descriptor strings", () {
      expect(
        () => codec.decodeInbound("".padRight(maxDeviceCanvasIpcFrameBytes + 1)),
        throwsFormatException,
      );
      expect(
        () => codec.decodeInbound(
          jsonEncode({
            "type": "inventorySnapshot",
            "devices": List.generate(maxDeviceCanvasInventoryDevices + 1, (index) {
              return {..._descriptorJson(), "deviceKey": "ios:$index"};
            }),
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decodeInbound(
          jsonEncode({
            "type": "inventorySnapshot",
            "devices": [
              {..._descriptorJson(), "displayName": "".padRight(maxDeviceCanvasIpcDisplayLength + 1, "x")},
            ],
          }),
        ),
        throwsFormatException,
      );
    });

    test("rejects oversized outbound frames", () {
      final oversized = DeviceCanvasOutboundMessage.claimUpdated(
        claim: DeviceCanvasClaimProjectionDto(
          bridgeId: "bridge",
          sessionId: "session",
          deviceKey: "device",
          revision: 1,
          displayTitle: "".padRight(maxDeviceCanvasIpcFrameBytes, "x"),
        ),
      );

      expect(() => codec.encodeOutbound(oversized), throwsFormatException);
    });
  });
}

Map<String, Object?> _capabilitiesJson() => <String, Object?>{
  "localView": true,
  "remoteVideo": true,
  "remoteControl": true,
  "input": true,
};

Map<String, Object?> _descriptorJson() => <String, Object?>{
  "deviceKey": "ios:booted",
  "platform": "ios",
  "displayName": "iPhone",
  "runtimeDescription": "iOS 18",
  "modelDescription": "iPhone",
  "dimensions": <String, Object?>{"width": 390, "height": 844},
  "orientation": "portrait",
  "capabilities": _capabilitiesJson(),
};

const String _fingerprint =
    "sha-256 AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA";

DeviceCanvasRtcDescription _rtcDescription(DeviceCanvasRtcDescriptionType type) => DeviceCanvasRtcDescription(
  type: type,
  sdp: "v=0\r\na=fingerprint:$_fingerprint\r\n",
  fingerprint: _fingerprint,
);

Map<String, Object?> _rtcDescriptionJson({required String type}) => <String, Object?>{
  "type": type,
  "sdp": "v=0\r\na=fingerprint:$_fingerprint\r\n",
  "fingerprint": _fingerprint,
};

Map<String, Object?> _iceCandidateJson() => <String, Object?>{
  "candidate": "candidate:1 1 udp 1 127.0.0.1 9 typ host",
  "sdpMid": "0",
  "sdpMLineIndex": 0,
};
