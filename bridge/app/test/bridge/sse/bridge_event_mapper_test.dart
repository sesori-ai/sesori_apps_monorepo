import "package:sesori_bridge/src/bridge/sse/bridge_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  group("BridgeEventMapper", () {
    late BridgeEventMapper mapper;
    late FakeBridgePlugin plugin;

    setUp(() {
      plugin = FakeBridgePlugin();
      mapper = BridgeEventMapper(
        plugin: plugin,
        failureReporter: FakeFailureReporter(),
      );
    });

    test("filters heartbeat events", () {
      final result = mapper.map(const BridgeSseServerHeartbeat());

      expect(result, isNull);
    });

    test("maps session.created with provided enriched payload", () {
      final result = mapper.map(
        const BridgeSseSessionCreated(
          info: {
            "id": "s1",
            "projectID": "p1",
            "directory": "/tmp/project",
            "parentID": null,
            "title": "session",
            "time": {"created": 1, "updated": 2, "archived": null},
            "summary": null,
            "pullRequest": {
              "number": 11,
              "url": "https://github.com/org/repo/pull/11",
              "title": "Newest open PR",
              "state": "open",
              "mergeableStatus": "mergeable",
              "reviewDecision": "approved",
              "checkStatus": "success",
            },
            "hasWorktree": true,
          },
        ),
      );

      expect(result, isA<SesoriSessionCreated>());
      final event = result! as SesoriSessionCreated;
      expect(event.info.pullRequest?.number, equals(11));
      expect(event.info.hasWorktree, isTrue);
    });

    test("maps session.updated with provided enriched payload", () {
      final result = mapper.map(
        const BridgeSseSessionUpdated(
          info: {
            "id": "s1",
            "projectID": "p1",
            "directory": "/tmp/project",
            "parentID": null,
            "title": "replacement session",
            "time": {"created": 3, "updated": 4, "archived": null},
            "summary": null,
            "pullRequest": {
              "number": 19,
              "url": "https://github.com/org/repo/pull/19",
              "title": "Stored update PR",
              "state": "open",
              "mergeableStatus": "mergeable",
              "reviewDecision": "reviewRequired",
              "checkStatus": "pending",
            },
          },
        ),
      );

      expect(result, isA<SesoriSessionUpdated>());
      final event = result! as SesoriSessionUpdated;
      expect(event.info.title, equals("replacement session"));
      expect(event.info.pullRequest?.number, equals(19));
      expect(event.info.pullRequest?.title, equals("Stored update PR"));
    });

    test("maps session.diff without diff payload", () async {
      final result = mapper.map(const BridgeSseSessionDiff(sessionID: "s1"));

      expect(result, isA<SesoriSessionDiff>());
      expect((result! as SesoriSessionDiff).sessionID, equals("s1"));
    });

    test("maps command.executed events", () {
      final result = mapper.map(
        const BridgeSseCommandExecuted(
          name: "review",
          sessionID: "s1",
          arguments: "lib/main.dart",
          messageID: "m1",
        ),
      );

      expect(result, isA<SesoriCommandExecuted>());
      final event = result! as SesoriCommandExecuted;
      expect(event.name, equals("review"));
      expect(event.sessionID, equals("s1"));
      expect(event.arguments, equals("lib/main.dart"));
      expect(event.messageID, equals("m1"));
    });

    test("filters file message part updates", () async {
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

    test("filters snapshot message part updates", () async {
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

    test("filters patch message part updates", () async {
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

    test("filters compaction message part updates", () async {
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

    test("passes agent message part updates", () async {
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

    test("passes retry message part updates", () async {
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

    test("truncates tool output to 500 characters", () async {
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

    test("passes through text message parts", () async {
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

    test("keeps short tool output unchanged", () async {
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

    test("map() returns null and reports failure when buildProjectsSummaryEvent() throws", () async {
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
