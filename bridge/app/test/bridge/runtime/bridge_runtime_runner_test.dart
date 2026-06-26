import "package:sesori_bridge/src/bridge/runtime/bridge_runtime_runner.dart";
import "package:test/test.dart";

void main() {
  group("BridgeRuntimeRunner.isLoopbackControlUrl", () {
    test("accepts ws/wss on loopback hosts", () {
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("ws://127.0.0.1:54321/control")), isTrue);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("wss://localhost:9/ctrl")), isTrue);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("ws://[::1]:8080")), isTrue);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("WS://LOCALHOST:9")), isTrue);
    });

    test("rejects non-loopback hosts", () {
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("ws://evil.example.com:80/control")), isFalse);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("ws://10.0.0.5:9")), isFalse);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("wss://0.0.0.0:9")), isFalse);
    });

    test("rejects non-ws schemes even on loopback", () {
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("http://127.0.0.1:9")), isFalse);
      expect(BridgeRuntimeRunner.isLoopbackControlUrl(Uri.parse("https://localhost:9")), isFalse);
    });
  });
}
