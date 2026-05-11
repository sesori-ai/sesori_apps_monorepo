// ignore_for_file: cast_nullable_to_non_nullable

import "package:codex_plugin/codex_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CodexEventMapper", () {
    const mapper = CodexEventMapper();

    test("thread/started → BridgeSseSessionCreated carrying thread map", () {
      final mapped = mapper.map(
        const CodexServerNotification(
          method: "thread/started",
          params: {
            "thread": {"id": "t-1", "cwd": "/repo/app"},
          },
        ),
      );
      expect(mapped, isA<BridgeSseSessionCreated>());
      final created = mapped as BridgeSseSessionCreated;
      expect(created.info["id"], equals("t-1"));
    });

    test("turn/started → BridgeSseSessionStatus(running)", () {
      final mapped = mapper.map(
        const CodexServerNotification(
          method: "turn/started",
          params: {"threadId": "t-1", "turn": {"id": "u-1"}},
        ),
      );
      expect(mapped, isA<BridgeSseSessionStatus>());
      final status = mapped as BridgeSseSessionStatus;
      expect(status.sessionID, equals("t-1"));
      expect(status.status["state"], equals("running"));
    });

    test("turn/completed → BridgeSseSessionIdle", () {
      final mapped = mapper.map(
        const CodexServerNotification(
          method: "turn/completed",
          params: {"threadId": "t-1"},
        ),
      );
      expect(mapped, isA<BridgeSseSessionIdle>());
      expect((mapped as BridgeSseSessionIdle).sessionID, equals("t-1"));
    });

    test("item/agentMessage/delta → BridgeSseMessagePartDelta", () {
      final mapped = mapper.map(
        const CodexServerNotification(
          method: "item/agentMessage/delta",
          params: {
            "threadId": "t-1",
            "turnId": "u-1",
            "itemId": "i-1",
            "delta": "hello ",
          },
        ),
      );
      expect(mapped, isA<BridgeSseMessagePartDelta>());
      final delta = mapped as BridgeSseMessagePartDelta;
      expect(delta.sessionID, equals("t-1"));
      expect(delta.messageID, equals("i-1"));
      expect(delta.delta, equals("hello "));
      expect(delta.field, equals("text"));
    });

    test("error → BridgeSseSessionError", () {
      final mapped = mapper.map(
        const CodexServerNotification(
          method: "error",
          params: {"threadId": "t-1", "error": {"message": "boom"}},
        ),
      );
      expect(mapped, isA<BridgeSseSessionError>());
      expect((mapped as BridgeSseSessionError).sessionID, equals("t-1"));
    });

    test("unmapped notifications return null", () {
      expect(
        mapper.map(
          const CodexServerNotification(
            method: "account/rateLimits/updated",
            params: {},
          ),
        ),
        isNull,
      );
    });

    test("notifications missing required fields return null", () {
      expect(
        mapper.map(
          const CodexServerNotification(
            method: "item/agentMessage/delta",
            params: {"threadId": "t-1"},
          ),
        ),
        isNull,
      );
    });
  });
}
