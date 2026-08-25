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
}
