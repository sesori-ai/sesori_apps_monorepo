import "dart:convert";

import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol_codec.dart";
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
