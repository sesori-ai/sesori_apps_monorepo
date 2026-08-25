import "package:sesori_bridge/src/bridge/device_canvas/integration_state.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:test/test.dart";

void main() {
  group("DeviceCanvasIntegrationState", () {
    late DeviceCanvasIntegrationState state;

    setUp(() {
      state = DeviceCanvasIntegrationState();
    });

    tearDown(() => state.dispose());

    test("tracks connection independently from inventory", () async {
      final connectionChange = state.connectionChanges.first;

      state.connect(canvasInstanceId: "canvas", protocolVersion: 1);

      expect((await connectionChange as DeviceCanvasConnectedSnapshot).canvasInstanceId, equals("canvas"));
      expect(state.presenceSnapshot.devicesByKey, isEmpty);
    });

    test("full inventory snapshot atomically replaces presence", () async {
      state.connect(canvasInstanceId: "canvas", protocolVersion: 1);
      state.replaceInventory([_descriptor("ios:one"), _descriptor("ios:two")]);
      expect(state.isDeviceAvailable("ios:one"), isTrue);
      expect(state.isDeviceAvailable("ios:two"), isTrue);

      state.replaceInventory([_descriptor("ios:two")]);

      expect(state.isDeviceAvailable("ios:one"), isFalse);
      expect(state.isDeviceAvailable("ios:two"), isTrue);
    });

    test("disconnect clears connectivity and inventory without touching claim state", () {
      state.connect(canvasInstanceId: "canvas", protocolVersion: 1);
      state.replaceInventory([_descriptor("ios:one")]);

      state.disconnect();

      expect(state.isConnected, isFalse);
      expect(state.presenceSnapshot.devicesByKey, isEmpty);
    });
  });
}

DeviceCanvasDescriptor _descriptor(String deviceKey) {
  return DeviceCanvasDescriptor(
    deviceKey: deviceKey,
    platform: DeviceCanvasPlatform.ios,
    displayName: "iPhone",
    runtimeDescription: "iOS 18",
    modelDescription: "iPhone",
    dimensions: const DeviceCanvasDimensions(width: 390, height: 844),
    orientation: DeviceCanvasOrientation.portrait,
    capabilities: const DeviceCanvasCapabilities(localView: true, remoteVideo: true, remoteControl: true, input: true),
  );
}
