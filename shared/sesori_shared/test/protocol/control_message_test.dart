import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ControlMessage", () {
    final variants = <String, ControlMessage>{
      "token_request": const ControlMessage.tokenRequest(id: "req-1", forceRefresh: true),
      "token_retry_later": const ControlMessage.tokenRetryLater(id: "req-1"),
      "token_response": const ControlMessage.tokenResponse(id: "req-1", accessToken: "jwt"),
      "status": const ControlMessage.status(
        startup: ControlStartupState.ready,
        relay: ControlRelayConnectionState.connected,
        unhealthyPlugins: [
          ControlUnhealthyPlugin(
            displayName: "Pi",
            state: ControlUnhealthyPluginState.degraded,
            actionHint: "Verify the configured Pi binary and retry.",
          ),
          ControlUnhealthyPlugin(displayName: "Codex", state: ControlUnhealthyPluginState.failed, actionHint: null),
        ],
        activeSessionCount: 3,
      ),
      "prompt_request": const ControlMessage.promptRequest(id: "p-1", message: "Another bridge is running"),
      "prompt_response": const ControlMessage.promptResponse(id: "p-1", accepted: true),
      "shutdown": const ControlMessage.shutdown(),
      "unregister_and_exit": const ControlMessage.unregisterAndExit(),
      "registered": const ControlMessage.registered(bridgeId: "br_abc12345"),
    };

    variants.forEach((type, original) {
      test("round-trips the $type variant with its discriminator", () {
        final json = original.toJson();

        expect(json["type"], equals(type));
        expect(ControlMessage.fromJson(json), equals(original));
      });
    });

    test("tokenRequest defaults forceRefresh to false when absent", () {
      final parsed = ControlMessage.fromJson({"type": "token_request", "id": "req-2"});

      expect(parsed, isA<ControlTokenRequest>());
      expect((parsed as ControlTokenRequest).forceRefresh, isFalse);
    });

    test("tokenResponse omits accessToken when the GUI cannot supply one", () {
      const original = ControlMessage.tokenResponse(id: "req-3", accessToken: null);

      final json = original.toJson();

      expect(json, equals({"type": "token_response", "id": "req-3"}));
      expect((ControlMessage.fromJson(json) as ControlTokenResponse).accessToken, isNull);
    });

    test("promptRequest omits message when null", () {
      const original = ControlMessage.promptRequest(id: "p-2", message: null);

      final json = original.toJson();

      expect(json.containsKey("message"), isFalse);
      expect(ControlMessage.fromJson(json), equals(original));
    });

    test("status defaults activeSessionCount to zero when absent", () {
      final parsed = ControlMessage.fromJson({
        "type": "status",
        "startup": "ready",
        "relay": "connected",
        "unhealthyPlugins": <Object>[],
      });

      expect((parsed as ControlStatus).activeSessionCount, equals(0));
    });

    for (final startup in ControlStartupState.values) {
      test("status round-trips startup state $startup", () {
        final original = ControlMessage.status(
          startup: startup,
          relay: ControlRelayConnectionState.disconnected,
          unhealthyPlugins: const [],
        );
        expect(ControlMessage.fromJson(original.toJson()), original);
      });
    }

    test("status round-trips the takenOver relay state", () {
      const original = ControlMessage.status(
        startup: ControlStartupState.ready,
        relay: ControlRelayConnectionState.takenOver,
        unhealthyPlugins: [],
      );

      final json = original.toJson();

      expect(json["relay"], equals("taken_over"));
      expect(ControlMessage.fromJson(json), equals(original));
    });
  });
}
