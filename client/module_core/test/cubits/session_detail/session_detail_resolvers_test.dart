import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const command = CommandMessageInfo(
    name: "compact",
    arguments: null,
    origin: CommandOrigin.automatic,
    displayPartID: "command-result",
  );

  group("resolveCommandResultText", () {
    test("returns the finalized selected part", () {
      final state = _loadedState(
        messages: [_commandMessage(result: "Final result")],
        streamingText: const {},
      );

      expect(
        state.resolveCommandResultText(command: command, messageId: "command-message"),
        "Final result",
      );
    });

    test("streaming text takes precedence over the finalized part", () {
      final state = _loadedState(
        messages: [_commandMessage(result: "Final result")],
        streamingText: const {"command-result": "Streaming result"},
      );

      expect(
        state.resolveCommandResultText(command: command, messageId: "command-message"),
        "Streaming result",
      );
    });

    test("preserves an empty active streaming value", () {
      final state = _loadedState(
        messages: [_commandMessage(result: "Final result")],
        streamingText: const {"command-result": ""},
      );

      expect(
        state.resolveCommandResultText(command: command, messageId: "command-message"),
        "",
      );
    });

    test("returns null when the selected part is absent from the message", () {
      final state = _loadedState(
        messages: [_commandMessage(result: "Unselected part", partId: "other-part")],
        streamingText: const {},
      );

      expect(
        state.resolveCommandResultText(command: command, messageId: "command-message"),
        isNull,
      );
    });

    test("does not select a matching part from another message", () {
      final state = _loadedState(
        messages: [
          _commandMessage(
            result: "Other message result",
            messageId: "other-message",
          ),
        ],
        streamingText: const {},
      );

      expect(
        state.resolveCommandResultText(command: command, messageId: "command-message"),
        isNull,
      );
    });

    test("returns null outside loaded state", () {
      const state = SessionDetailState.loading();

      expect(
        state.resolveCommandResultText(command: command, messageId: "command-message"),
        isNull,
      );
    });
  });
}

SessionDetailState _loadedState({
  required List<MessageWithParts> messages,
  required Map<String, String> streamingText,
}) {
  return SessionDetailState.loaded(
    messages: messages,
    streamingText: streamingText,
    sessionStatus: const SessionStatus.idle(),
    pendingQuestions: const [],
    pendingPermissions: const [],
    sessionTitle: null,
    agent: null,
    assistantAgentModel: null,
    children: const [],
    childStatuses: const {},
    isRootSession: true,
    queuedMessages: const [],
    availableAgents: const [],
    availableProviders: const [],
    availableCommands: const [],
    selectedAgent: "coder",
    selectedAgentModel: null,
    stagedCommand: null,
    isRefreshing: false,
    retryErrorMessage: null,
  );
}

MessageWithParts _commandMessage({
  required String result,
  String partId = "command-result",
  String messageId = "command-message",
}) {
  return MessageWithParts(
    info: Message.user(
      id: messageId,
      sessionID: "session-1",
      agent: null,
      time: null,
      command: const CommandMessageInfo(
        name: "compact",
        arguments: null,
        origin: CommandOrigin.automatic,
        displayPartID: "command-result",
      ),
    ),
    parts: [
      MessagePart(
        id: partId,
        sessionID: "session-1",
        messageID: messageId,
        type: MessagePartType.text,
        text: result,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
      ),
    ],
  );
}
