import "package:sesori_bridge/src/sse/bridge_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  group("BridgeEventMapper", () {
    late BridgeEventMapper mapper;

    setUp(() {
      mapper = BridgeEventMapper(
        failureReporter: FakeFailureReporter(),
      );
    });

    SesoriSseEvent? mapEvent(BridgeSseEvent event) {
      if (event case BridgeSseMessagePartUpdated(:final part)) {
        if (!mapper.isMessagePartVisible(part: part)) return null;
        return mapper.buildMessagePartEvent(part: mapper.mapMessagePart(part: part));
      }
      return mapper.map(event: event, pluginId: "test-plugin");
    }

    test("finalized part events require the store-before-delivery mapping seam", () {
      expect(
        mapper.map(
          event: const BridgeSseMessagePartUpdated(
            part: PluginMessagePart.text(id: "p1", sessionID: "s1", messageID: "m1", text: "hello"),
          ),
          pluginId: "test-plugin",
        ),
        isNull,
      );
    });

    test("filters plugin lifecycle events from bridge-global wire semantics", () {
      const lifecycleEvents = <BridgeSseEvent>[
        BridgeSseServerConnected(),
        BridgeSseServerHeartbeat(),
        BridgeSseServerInstanceDisposed(directory: "/repo"),
        BridgeSseGlobalDisposed(),
      ];

      for (final event in lifecycleEvents) {
        expect(mapEvent(event), isNull, reason: event.runtimeType.toString());
      }
    });

    test("does not expose the internal session-options change event to clients", () {
      expect(
        mapEvent(const BridgeSseSessionOptionsChanged(sessionID: "backend-session")),
        isNull,
      );
    });

    test("maps backend-originated prompt defaults to the existing wire event", () {
      final result = mapEvent(
        const BridgeSseSessionPromptDefaultsChanged(
          sessionID: "stable-session",
          agent: "Default",
          model: null,
        ),
      );

      expect(
        result,
        const SesoriSessionPromptDefaultsChanged(
          sessionID: "stable-session",
          promptDefaults: SessionPromptDefaults(agent: "Default", model: null),
        ),
      );
    });

    test("attributes command catalog updates to their source plugin", () {
      final result = mapper.map(
        event: const BridgeSseCommandCatalogUpdated(),
        pluginId: "cursor",
      );

      expect(result, const SesoriCommandCatalogUpdated(pluginId: "cursor"));
    });

    test("maps session.created with provided enriched payload", () {
      final result = mapEvent(
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
      final result = mapEvent(
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
          titleChanged: false,
        ),
      );

      expect(result, isA<SesoriSessionUpdated>());
      final event = result! as SesoriSessionUpdated;
      expect(event.info.title, equals("replacement session"));
      expect(event.info.pullRequest?.number, equals(19));
      expect(event.info.pullRequest?.title, equals("Stored update PR"));
    });

    test("maps session.diff without diff payload", () async {
      final result = mapEvent(const BridgeSseSessionDiff(sessionID: "s1"));

      expect(result, isA<SesoriSessionDiff>());
      expect((result! as SesoriSessionDiff).sessionID, equals("s1"));
    });

    test("maps command.executed events", () {
      final result = mapEvent(
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

    test("passes file message part updates with normalized attachment data", () async {
      final result = mapEvent(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart.file(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            attachment: PluginMessageAttachment.metadata(mime: "text/plain", filename: "notes.txt"),
          ),
        ),
      );

      expect(result, isA<SesoriMessagePartUpdated>());
      final event = result! as SesoriMessagePartUpdated;
      expect(
        event.part.attachment,
        equals(const MessageAttachment.metadata(mime: "text/plain", filename: "notes.txt")),
      );
    });

    test("filters snapshot message part updates", () async {
      final result = mapEvent(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart.snapshot(id: "p1", sessionID: "s1", messageID: "m1"),
        ),
      );

      expect(result, isNull);
    });

    test("filters patch message part updates", () async {
      final result = mapEvent(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart.patch(id: "p1", sessionID: "s1", messageID: "m1"),
        ),
      );

      expect(result, isNull);
    });

    test("filters compaction message part updates", () async {
      final result = mapEvent(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart.compaction(id: "p1", sessionID: "s1", messageID: "m1"),
        ),
      );

      expect(result, isNull);
    });

    test("passes agent message part updates", () async {
      final result = mapEvent(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart.agent(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            agentName: "test-agent",
          ),
        ),
      );

      expect(result, isNotNull);
      expect(result, isA<SesoriMessagePartUpdated>());
    });

    test("passes retry message part updates", () async {
      final result = mapEvent(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart.retry(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
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
      final result = mapEvent(
        BridgeSseMessagePartUpdated(
          part: PluginMessagePart.tool(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            tool: "tool",
            state: PluginToolState(
              status: PluginToolStatus.completed,
              title: null,
              output: longOutput,
              error: null,
              attachments: const [],
            ),
          ),
        ),
      );

      expect(result, isA<SesoriMessagePartUpdated>());
      final event = result! as SesoriMessagePartUpdated;
      expect(event.part.state?.output?.length, lessThanOrEqualTo(500));
      expect(event.part.state?.output?.length, equals(500));
    });

    test("passes through text message parts", () async {
      final result = mapEvent(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart.text(id: "p1", sessionID: "s1", messageID: "m1", text: "hello"),
        ),
      );

      expect(result, isA<SesoriMessagePartUpdated>());
      final event = result! as SesoriMessagePartUpdated;
      expect(event.part.type, equals(MessagePartType.text));
      expect(event.part.text, equals("hello"));
    });

    test("keeps short tool output unchanged", () async {
      final result = mapEvent(
        const BridgeSseMessagePartUpdated(
          part: PluginMessagePart.tool(
            id: "p1",
            sessionID: "s1",
            messageID: "m1",
            tool: "tool",
            state: PluginToolState(
              status: PluginToolStatus.completed,
              title: null,
              output: "short",
              error: null,
              attachments: [],
            ),
          ),
        ),
      );

      expect(result, isA<SesoriMessagePartUpdated>());
      final event = result! as SesoriMessagePartUpdated;
      expect(event.part.state?.output, equals("short"));
    });

    test("map() drops BridgeSseProjectUpdated (the orchestrator builds the summary)", () {
      final result = mapEvent(const BridgeSseProjectUpdated());

      expect(result, isNull);
    });

    test("buildProjectsSummaryEvent() wraps already-remapped summary data", () {
      final result = mapper.buildProjectsSummaryEvent(
        projects: const [
          ProjectActivitySummary(
            id: "/repo",
            activeSessions: [
              ActiveSession(
                id: "s1",
                mainAgentRunning: true,
                awaitingInput: false,
                isRetrying: false,
                childSessionIds: [],
                lastUserActivityAt: null,
                updatedAt: null,
              ),
            ],
          ),
        ],
      );

      final event = result as SesoriProjectsSummary;
      expect(event.projects.single.id, "/repo");
      expect(event.projects.single.activeSessions.single.id, "s1");
    });
  });
}
