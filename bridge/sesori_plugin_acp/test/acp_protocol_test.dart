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
      expect(result.configOptions.single.category, "model");
    });
  });

  test("AcpStopReason parses ACP values", () {
    expect(AcpStopReason.parse("end_turn"), AcpStopReason.endTurn);
    expect(AcpStopReason.parse("cancelled"), AcpStopReason.cancelled);
    expect(AcpStopReason.parse("refusal"), AcpStopReason.refusal);
    expect(AcpStopReason.parse("???"), AcpStopReason.unknown);
  });

  group("AcpSessionListResult", () {
    test("parses sessions with ISO-8601 and epoch-ms timestamps", () {
      final result = AcpSessionListResult.fromJson({
        "sessions": [
          {"sessionId": "s1", "cwd": "/repo", "title": "One", "updatedAt": "2026-07-01T10:00:00Z"},
          {"sessionId": "s2", "cwd": "/repo", "updatedAt": 1751364000000},
        ],
        "nextCursor": "page-2",
      });
      expect(result.sessions, hasLength(2));
      expect(result.sessions.first.updatedAtMs, DateTime.utc(2026, 7, 1, 10).millisecondsSinceEpoch);
      expect(result.sessions.last.updatedAtMs, 1751364000000);
      expect(result.nextCursor, "page-2");
    });

    test("a malformed entry is skipped without hiding the page's valid sessions", () {
      final result = AcpSessionListResult.fromJson({
        "sessions": [
          {"sessionId": "good", "cwd": "/repo"},
          "junk-string-entry",
          {"sessionId": 42, "cwd": "/repo"},
          {"sessionId": "also-good", "cwd": "/other"},
        ],
      });
      expect(result.sessions.map((s) => s.sessionId), ["good", "also-good"]);
      expect(result.nextCursor, isNull);
    });

    test("a non-list sessions payload parses as empty", () {
      expect(AcpSessionListResult.fromJson({"sessions": "nope"}).sessions, isEmpty);
      expect(AcpSessionListResult.fromJson(const {}).sessions, isEmpty);
    });
  });
}
