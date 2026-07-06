import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ControlMessage", () {
    final variants = <String, ControlMessage>{
      "token_request": const ControlMessage.tokenRequest(id: "req-1", forceRefresh: true),
      "token_response": const ControlMessage.tokenResponse(id: "req-1", accessToken: "jwt"),
      "token_update": const ControlMessage.tokenUpdate(accessToken: "jwt"),
      "status": const ControlMessage.status(
        relay: ControlRelayConnectionState.connected,
        plugin: ControlPluginHealthState.degraded,
        activeSessionCount: 3,
      ),
      "prompt_request": const ControlMessage.promptRequest(
        id: "p-1",
        kind: ControlPromptKind.replaceBridge,
        message: "Another bridge is running",
      ),
      "prompt_response": const ControlMessage.promptResponse(id: "p-1", accepted: true),
      "restart": const ControlMessage.restart(),
      "unregister_and_exit": const ControlMessage.unregisterAndExit(),
      "registered": const ControlMessage.registered(bridgeId: "br_abc12345"),
      "provision_progress": const ControlMessage.provisionProgress(
        progress: ControlProvisionProgress.downloading(receivedBytes: 10, totalBytes: 100),
      ),
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
      const original = ControlMessage.promptRequest(
        id: "p-2",
        kind: ControlPromptKind.loginNeeded,
        message: null,
      );

      final json = original.toJson();

      expect(json.containsKey("message"), isFalse);
      expect(ControlMessage.fromJson(json), equals(original));
    });

    test("status nests the provision-progress discriminator independently", () {
      const original = ControlMessage.provisionProgress(
        progress: ControlProvisionProgress.ready(binaryPath: "/bin/opencode"),
      );

      final json = original.toJson();

      expect(json["type"], equals("provision_progress"));
      expect(json["progress"], equals({"type": "ready", "binaryPath": "/bin/opencode"}));
      expect(ControlMessage.fromJson(json), equals(original));
    });

    group("forward-compatibility", () {
      test("relay enum falls back to unknown for an unrecognized value", () {
        final parsed = ControlMessage.fromJson({
          "type": "status",
          "relay": "rebooting",
          "plugin": "healthy",
        });

        final status = parsed as ControlStatus;
        expect(status.relay, equals(ControlRelayConnectionState.unknown));
        expect(status.plugin, equals(ControlPluginHealthState.healthy));
        expect(status.activeSessionCount, equals(0));
      });

      test("prompt-kind enum falls back to unknown for an unrecognized value", () {
        final parsed = ControlMessage.fromJson({
          "type": "prompt_request",
          "id": "p-3",
          "kind": "future_prompt",
          "message": null,
        });

        expect((parsed as ControlPromptRequest).kind, equals(ControlPromptKind.unknown));
      });
    });

    test("status round-trips the takenOver relay state", () {
      const original = ControlMessage.status(
        relay: ControlRelayConnectionState.takenOver,
        plugin: ControlPluginHealthState.healthy,
      );

      final json = original.toJson();

      expect(json["relay"], equals("taken_over"));
      expect(ControlMessage.fromJson(json), equals(original));
    });
  });
}
