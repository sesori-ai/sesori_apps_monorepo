import "package:opencode_plugin/opencode_plugin.dart";
import "package:opencode_plugin/src/assistant_message_mapper.dart";
import "package:opencode_plugin/src/sse_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  late OpenCodeCommandTracker tracker;
  late OpenCodeCommandEventService service;

  setUp(() {
    tracker = OpenCodeCommandTracker();
    service = OpenCodeCommandEventService(
      tracker: tracker,
      commandMapper: const OpenCodeCommandMapper(),
      eventMapper: SseEventMapper(),
      messagePartMapper: const MessagePartMapper(),
      assistantMessageMapper: const AssistantMessageMapper(),
    );
  });

  test("correlates an ordinary command when the trigger envelope is lost", () {
    const triggerId = "msg_sesori_0123456789abcdef0123456789abcdef";
    tracker.registerDispatch(
      sessionId: "session",
      invocationId: "opaque-invocation",
      name: "review",
      arguments: "recent changes",
      backendMessageId: triggerId,
    );

    final events = service.map(
      SseEventData.messagePartUpdated(
        part: Part.fromJson(
          _textPart(id: "trigger-part", messageId: triggerId, text: "Review recent changes"),
        ),
      ),
      displaySessionId: null,
    );

    expect(events, hasLength(1));
    final command = (events.single as BridgeSseMessageUpdated).info;
    expect(command["role"], "command");
    expect(command["id"], triggerId);
    expect(command["invocationId"], "opaque-invocation");
  });

  test("manual compaction hides guidance and reparents only the typed summary", () {
    tracker.registerDispatch(
      sessionId: "session",
      invocationId: "compact-invocation",
      name: "compact",
      arguments: "Keep auth decisions",
      backendMessageId: null,
    );

    expect(
      service.map(
        SseEventData.messageUpdated(
          info: Message.fromJson(_userInfo(id: "guidance", created: 10)),
        ),
        displaySessionId: null,
      ),
      isEmpty,
    );
    expect(
      service.map(
        SseEventData.messagePartUpdated(
          part: Part.fromJson(
            _textPart(id: "guidance-part", messageId: "guidance", text: "Keep auth decisions"),
          ),
        ),
        displaySessionId: null,
      ),
      isEmpty,
    );
    service.map(
      SseEventData.messageUpdated(
        info: Message.fromJson(_userInfo(id: "manual-trigger", created: 20)),
      ),
      displaySessionId: null,
    );
    final triggerEvents = service.map(
      SseEventData.messagePartUpdated(
        part: Part.fromJson(_compactionPart(messageId: "manual-trigger", automatic: false)),
      ),
      displaySessionId: null,
    );

    final command = (triggerEvents.single as BridgeSseMessageUpdated).info;
    expect(command["origin"], PluginCommandOrigin.manual.name);
    expect(command["invocationId"], "compact-invocation");

    expect(
      service.map(
        SseEventData.messageUpdated(
          info: Message.fromJson(
            _assistantInfo(
              id: "summary",
              parentId: "manual-trigger",
              summary: true,
              mode: "compaction",
            ),
          ),
        ),
        displaySessionId: null,
      ),
      isEmpty,
    );
    final resultEvents = service.map(
      SseEventData.messagePartUpdated(
        part: Part.fromJson(
          _textPart(id: "summary-part", messageId: "summary", text: "Compacted context"),
        ),
      ),
      displaySessionId: null,
    );
    final result = (resultEvents.single as BridgeSseMessagePartUpdated).part;
    expect(result.id, "summary-part");
    expect(result.messageID, "manual-trigger");
  });

  test("automatic compaction emits an uncorrelated automatic command", () {
    service.map(
      SseEventData.messageUpdated(
        info: Message.fromJson(_userInfo(id: "auto-trigger", created: 30)),
      ),
      displaySessionId: null,
    );
    final events = service.map(
      SseEventData.messagePartUpdated(
        part: Part.fromJson(_compactionPart(messageId: "auto-trigger", automatic: true)),
      ),
      displaySessionId: null,
    );

    final command = (events.single as BridgeSseMessageUpdated).info;
    expect(command["origin"], PluginCommandOrigin.automatic.name);
    expect(command["invocationId"], isNull);
  });

  test("turns a correlated assistant error into visible command result text", () {
    const triggerId = "msg_sesori_fedcba9876543210fedcba9876543210";
    tracker.registerDispatch(
      sessionId: "session",
      invocationId: "error-invocation",
      name: "review",
      arguments: "",
      backendMessageId: triggerId,
    );

    final events = service.map(
      SseEventData.messageUpdated(
        info: Message.fromJson(
          _assistantInfo(
            id: "assistant-error",
            parentId: triggerId,
            summary: false,
            mode: "primary",
            errorMessage: "Model unavailable",
          ),
        ),
      ),
      displaySessionId: null,
    );

    final part = (events.single as BridgeSseMessagePartUpdated).part;
    expect(part.messageID, triggerId);
    expect(part.type, PluginMessagePartType.text);
    expect(part.text, "Model unavailable");
  });

  test("leaves a non-command user and part unchanged", () {
    expect(
      service.map(
        SseEventData.messageUpdated(
          info: Message.fromJson(_userInfo(id: "ordinary-user", created: 40)),
        ),
        displaySessionId: null,
      ),
      isEmpty,
    );
    final events = service.map(
      SseEventData.messagePartUpdated(
        part: Part.fromJson(
          _textPart(id: "ordinary-part", messageId: "ordinary-user", text: "hello"),
        ),
      ),
      displaySessionId: null,
    );

    expect(events, hasLength(2));
    expect(events.first, isA<BridgeSseMessageUpdated>());
    final part = (events.last as BridgeSseMessagePartUpdated).part;
    expect(part.messageID, "ordinary-user");
    expect(part.text, "hello");
  });

  test("tracker ignores unknown parts without losing held user correlation", () {
    tracker.observeMessage(Message.fromJson(_userInfo(id: "ordinary-user", created: 40)));

    expect(
      () => tracker.observePart(const PartUnknown(raw: "future-part")),
      returnsNormally,
    );
    tracker.observePart(
      Part.fromJson(
        _textPart(id: "ordinary-part", messageId: "ordinary-user", text: "hello"),
      ),
    );

    expect(tracker.takeReleasedUser("ordinary-user")?.id, "ordinary-user");
  });
}

Map<String, dynamic> _userInfo({required String id, required int created}) => {
  "role": "user",
  "id": id,
  "sessionID": "session",
  "time": {"created": created},
  "agent": "build",
  "model": const {"providerID": "openai", "modelID": "gpt"},
};

Map<String, dynamic> _assistantInfo({
  required String id,
  required String parentId,
  required bool summary,
  required String mode,
  String? errorMessage,
}) => {
  "role": "assistant",
  "id": id,
  "sessionID": "session",
  "time": const {"created": 50},
  "parentID": parentId,
  "modelID": "gpt",
  "providerID": "openai",
  "mode": mode,
  "agent": "compaction",
  "path": const {"cwd": "/repo", "root": "/repo"},
  "summary": summary,
  if (errorMessage != null)
    "error": {
      "name": "UnknownError",
      "data": {"message": errorMessage},
    },
  "cost": 0,
  "tokens": const {
    "input": 0,
    "output": 0,
    "reasoning": 0,
    "cache": {"read": 0, "write": 0},
  },
};

Map<String, dynamic> _textPart({
  required String id,
  required String messageId,
  required String text,
}) => {
  "id": id,
  "sessionID": "session",
  "messageID": messageId,
  "type": "text",
  "text": text,
};

Map<String, dynamic> _compactionPart({
  required String messageId,
  required bool automatic,
}) => {
  "id": "$messageId-compaction",
  "sessionID": "session",
  "messageID": messageId,
  "type": "compaction",
  "auto": automatic,
  "overflow": automatic,
};
