import "package:acp_plugin/acp_plugin.dart";
import "package:test/test.dart";

void main() {
  group("AcpInitializeResult", () {
    test("parses Cursor's real initialize result", () {
      // Captured from a live `cursor-agent acp` (2026.05.28). Note
      // sessionCapabilities.list is an object `{}`, not a bool.
      final init = AcpInitializeResult.fromJson(const {
        "protocolVersion": 1,
        "agentCapabilities": {
          "loadSession": true,
          "sessionCapabilities": {"list": <String, dynamic>{}},
        },
        "authMethods": [
          {"id": "cursor_login", "name": "Cursor Login"},
        ],
      });
      expect(init.protocolVersion, 1);
      expect(init.agentCapabilities.loadSession, isTrue);
      expect(init.agentCapabilities.listSessions, isTrue);
      expect(init.requiresAuth, isTrue);
      expect(init.authMethods.single.id, "cursor_login");
    });

    test("absent capabilities default to false", () {
      final init = AcpInitializeResult.fromJson(const {"protocolVersion": 1});
      expect(init.agentCapabilities.loadSession, isFalse);
      expect(init.agentCapabilities.listSessions, isFalse);
      expect(init.requiresAuth, isFalse);
    });
  });

  group("AcpNewSessionResult", () {
    test("parses sessionId and configOptions from Cursor's session/new", () {
      final result = AcpNewSessionResult.fromJson(const {
        "sessionId": "s-1",
        // modes is an object (not a list) — must not break parsing.
        "modes": {"currentModeId": "agent"},
        "configOptions": [
          {
            "id": "model",
            "category": "model",
            "currentValue": "composer-2.5",
            "options": [
              {"value": "composer-2.5", "name": "Composer 2.5"},
              {"value": "claude-opus-4-7", "name": "Opus 4.7"},
            ],
          },
        ],
      });
      expect(result.sessionId, "s-1");
      expect(result.configOptions, hasLength(1));
      expect(result.configOptions.single["category"], "model");
    });
  });

  test("AcpStopReason parses ACP values", () {
    expect(AcpStopReason.parse("end_turn"), AcpStopReason.endTurn);
    expect(AcpStopReason.parse("cancelled"), AcpStopReason.cancelled);
    expect(AcpStopReason.parse("refusal"), AcpStopReason.refusal);
    expect(AcpStopReason.parse("???"), AcpStopReason.unknown);
  });
}
