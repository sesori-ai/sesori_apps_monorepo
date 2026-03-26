import "package:sesori_bridge/src/bridge/sse/bridge_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../routing/routing_test_helpers.dart";

void main() {
  group("BridgeEventMapper", () {
    late BridgeEventMapper mapper;

    setUp(() {
      mapper = BridgeEventMapper(FakeBridgePlugin());
    });

    test("filters heartbeat events", () {
      final result = mapper.map(const BridgeSseServerHeartbeat());

      expect(result, isNull);
    });

    test("maps session.diff without diff payload", () {
      final result = mapper.map(const BridgeSseSessionDiff(sessionID: "s1"));

      expect(result, isA<SesoriSessionDiff>());
      expect((result! as SesoriSessionDiff).sessionID, equals("s1"));
    });

    test("filters file message part updates", () {
      final result = mapper.map(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            type: PluginMessagePartType.file,
            text: null,
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
          ),
        ),
      );

      expect(result, isNull);
    });

    test("filters snapshot message part updates", () {
      final result = mapper.map(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            type: PluginMessagePartType.snapshot,
            text: null,
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
          ),
        ),
      );

      expect(result, isNull);
    });

    test("truncates tool output to 500 characters", () {
      final longOutput = List.filled(1000, "x").join();
      final result = mapper.map(
        BridgeSseMessagePartUpdated(
          part: PluginMessagePart(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            type: PluginMessagePartType.tool,
            text: null,
            tool: null,
            state: PluginToolState(
              status: "completed",
              title: null,
              output: longOutput,
              error: null,
            ),
            prompt: null,
            description: null,
            agent: null,
          ),
        ),
      );

      expect(result, isA<SesoriMessagePartUpdated>());
      final event = result! as SesoriMessagePartUpdated;
      expect(event.part.state?.output?.length, lessThanOrEqualTo(500));
      expect(event.part.state?.output?.length, equals(500));
    });

    test("passes through text message parts", () {
      final result = mapper.map(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            type: PluginMessagePartType.text,
            text: "hello",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
          ),
        ),
      );

      expect(result, isA<SesoriMessagePartUpdated>());
      final event = result! as SesoriMessagePartUpdated;
      expect(event.part.type, equals(MessagePartType.text));
      expect(event.part.text, equals("hello"));
    });

    test("keeps short tool output unchanged", () {
      final result = mapper.map(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            type: PluginMessagePartType.tool,
            text: null,
            tool: null,
            state: PluginToolState(
              status: "completed",
              title: null,
              output: "short",
              error: null,
            ),
            prompt: null,
            description: null,
            agent: null,
          ),
        ),
      );

      expect(result, isA<SesoriMessagePartUpdated>());
      final event = result! as SesoriMessagePartUpdated;
      expect(event.part.state?.output, equals("short"));
    });
  });
}
