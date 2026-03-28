import "package:sesori_bridge/src/bridge/sse/bridge_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  group("BridgeEventMapper", () {
    late BridgeEventMapper mapper;

    setUp(() {
      mapper = BridgeEventMapper(
        plugin: FakeBridgePlugin(),
        failureReporter: FakeFailureReporter(),
      );
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
            agentName: null,
            attempt: null,
            retryError: null,
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
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(result, isNull);
    });

    test("filters patch message part updates", () {
      final result = mapper.map(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            type: PluginMessagePartType.patch,
            text: null,
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(result, isNull);
    });

    test("filters compaction message part updates", () {
      final result = mapper.map(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            type: PluginMessagePartType.compaction,
            text: null,
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(result, isNull);
    });

    test("passes agent message part updates", () {
      final result = mapper.map(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            type: PluginMessagePartType.agent,
            text: null,
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: "test-agent",
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(result, isNotNull);
      expect(result, isA<SesoriMessagePartUpdated>());
    });

    test("passes retry message part updates", () {
      final result = mapper.map(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            type: PluginMessagePartType.retry,
            text: null,
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: 2,
            retryError: "timeout",
          ),
        ),
      );

      expect(result, isNotNull);
      expect(result, isA<SesoriMessagePartUpdated>());
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
            agentName: null,
            attempt: null,
            retryError: null,
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
            agentName: null,
            attempt: null,
            retryError: null,
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
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(result, isA<SesoriMessagePartUpdated>());
      final event = result! as SesoriMessagePartUpdated;
      expect(event.part.state?.output, equals("short"));
    });

    test("map() returns null and reports failure when buildProjectsSummaryEvent() throws", () {
      final capturingReporter = CapturingFailureReporter();
      final throwingMapper = BridgeEventMapper(
        plugin: _ThrowingActiveSessionsPlugin(),
        failureReporter: capturingReporter,
      );

      final result = throwingMapper.map(const BridgeSseProjectUpdated());

      expect(result, isNull);
      expect(capturingReporter.recordedIdentifiers, contains("sse_projects_summary"));
    });

    test("buildProjectsSummaryEvent() returns null and reports failure when plugin throws", () {
      final capturingReporter = CapturingFailureReporter();
      final throwingMapper = BridgeEventMapper(
        plugin: _ThrowingActiveSessionsPlugin(),
        failureReporter: capturingReporter,
      );

      final result = throwingMapper.buildProjectsSummaryEvent();

      expect(result, isNull);
      expect(capturingReporter.recordedIdentifiers, contains("sse_projects_summary"));
    });
  });
}

class _ThrowingActiveSessionsPlugin extends FakeBridgePlugin {
  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    throw StateError("summary mapping failed");
  }
}
