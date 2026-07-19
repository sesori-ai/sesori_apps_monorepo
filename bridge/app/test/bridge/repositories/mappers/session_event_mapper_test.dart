import "package:sesori_bridge/src/bridge/repositories/mappers/session_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const mapper = SessionEventMapper();
  const ids = {
    "backend-session": "ses-session",
    "backend-parent": "ses-parent",
  };

  group("SessionEventMapper", () {
    test("rewrites every session-bearing event variant", () {
      final sessionInfo = _sessionInfo(
        sessionId: "backend-session",
        parentId: "backend-parent",
      );
      final messageInfo = const Message.user(
        id: "message",
        sessionID: "backend-session",
        agent: null,
        time: null,
      ).toJson();
      const part = PluginMessagePart(
        id: "part",
        sessionID: "backend-session",
        messageID: "message",
        type: PluginMessagePartType.text,
        text: "text",
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
      );
      final cases = <({String name, BridgeSseEvent event, Set<String> expectedBackendIds})>[
        (
          name: "session created",
          event: BridgeSseSessionCreated(info: sessionInfo),
          expectedBackendIds: ids.keys.toSet(),
        ),
        (
          name: "session updated",
          event: BridgeSseSessionUpdated(info: sessionInfo, titleChanged: true),
          expectedBackendIds: ids.keys.toSet(),
        ),
        (
          name: "session deleted",
          event: BridgeSseSessionDeleted(info: sessionInfo),
          expectedBackendIds: ids.keys.toSet(),
        ),
        (
          name: "sessions updated",
          event: const BridgeSseSessionsUpdated(sessionID: "backend-session", projectID: "project"),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "session diff",
          event: const BridgeSseSessionDiff(sessionID: "backend-session"),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "session error",
          event: const BridgeSseSessionError(sessionID: "backend-session"),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "session compacted",
          event: const BridgeSseSessionCompacted(sessionID: "backend-session"),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "session status",
          event: const BridgeSseSessionStatus(sessionID: "backend-session", status: {"type": "busy"}),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "session idle",
          event: const BridgeSseSessionIdle(sessionID: "backend-session"),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "command executed",
          event: const BridgeSseCommandExecuted(
            name: "review",
            sessionID: "backend-session",
            arguments: "",
            messageID: "message",
          ),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "message updated",
          event: BridgeSseMessageUpdated(info: messageInfo),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "message removed",
          event: const BridgeSseMessageRemoved(sessionID: "backend-session", messageID: "message"),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "message part updated",
          event: const BridgeSseMessagePartUpdated(part: part),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "message part delta",
          event: const BridgeSseMessagePartDelta(
            sessionID: "backend-session",
            messageID: "message",
            partID: "part",
            field: "text",
            delta: "delta",
          ),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "message part removed",
          event: const BridgeSseMessagePartRemoved(
            sessionID: "backend-session",
            messageID: "message",
            partID: "part",
          ),
          expectedBackendIds: {"backend-session"},
        ),
        (
          name: "permission asked",
          event: const BridgeSsePermissionAsked(
            requestID: "permission",
            sessionID: "backend-session",
            displaySessionId: "backend-parent",
            tool: "bash",
            description: "run",
          ),
          expectedBackendIds: ids.keys.toSet(),
        ),
        (
          name: "permission replied",
          event: const BridgeSsePermissionReplied(
            requestID: "permission",
            sessionID: "backend-session",
            displaySessionId: "backend-parent",
            reply: "once",
          ),
          expectedBackendIds: ids.keys.toSet(),
        ),
        (
          name: "question asked",
          event: const BridgeSseQuestionAsked(
            id: "question",
            sessionID: "backend-session",
            displaySessionId: "backend-parent",
            questions: [],
          ),
          expectedBackendIds: ids.keys.toSet(),
        ),
        (
          name: "question replied",
          event: const BridgeSseQuestionReplied(
            requestID: "question",
            sessionID: "backend-session",
            displaySessionId: "backend-parent",
          ),
          expectedBackendIds: ids.keys.toSet(),
        ),
        (
          name: "question rejected",
          event: const BridgeSseQuestionRejected(
            requestID: "question",
            sessionID: "backend-session",
            displaySessionId: "backend-parent",
          ),
          expectedBackendIds: ids.keys.toSet(),
        ),
        (
          name: "todo updated",
          event: const BridgeSseTodoUpdated(sessionID: "backend-session"),
          expectedBackendIds: {"backend-session"},
        ),
      ];

      for (final testCase in cases) {
        expect(
          mapper.backendSessionIds(event: testCase.event),
          testCase.expectedBackendIds,
          reason: testCase.name,
        );
        final mapped = mapper.map(event: testCase.event, sessionIdsByBackendId: ids);
        expect(mapped, isNotNull, reason: testCase.name);
        expect(
          mapper.backendSessionIds(event: mapped!),
          testCase.expectedBackendIds.map((id) => ids[id]!).toSet(),
          reason: testCase.name,
        );
      }
    });

    test("drops an event when any required session reference is unknown", () {
      expect(
        mapper.map(
          event: const BridgeSsePermissionAsked(
            requestID: "permission",
            sessionID: "backend-session",
            displaySessionId: "unknown-display",
            tool: "bash",
            description: "run",
          ),
          sessionIdsByBackendId: ids,
        ),
        isNull,
      );
      expect(
        mapper.map(
          event: BridgeSseSessionCreated(
            info: _sessionInfo(
              sessionId: "backend-session",
              parentId: "unknown-parent",
            ),
          ),
          sessionIdsByBackendId: ids,
        ),
        isNull,
      );
    });

    test("preserves nullable session references and non-session events", () {
      const error = BridgeSseSessionError(sessionID: null);
      const connected = BridgeSseServerConnected();

      expect(mapper.backendSessionIds(event: error), isEmpty);
      final mappedError = mapper.map(event: error, sessionIdsByBackendId: const {});
      expect(mappedError, isA<BridgeSseSessionError>());
      expect((mappedError! as BridgeSseSessionError).sessionID, isNull);
      expect(mapper.map(event: connected, sessionIdsByBackendId: const {}), same(connected));
    });
  });
}

Map<String, dynamic> _sessionInfo({required String sessionId, required String? parentId}) {
  return Session(
    id: sessionId,
    pluginId: "plugin",
    projectID: "project",
    directory: "/repo/$sessionId",
    parentID: parentId,
    title: "title",
    time: null,
    pullRequest: null,
    promptDefaults: null,
    branchName: null,
  ).toJson();
}
