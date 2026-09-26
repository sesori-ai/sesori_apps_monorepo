import "package:sesori_dart_core/src/cubits/session_detail/local_send_phase.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_resolvers.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/session_interaction_state.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ranWith", () {
    test("prefers the bridge's prompt defaults, variant included", () {
      const model = AgentModel(providerID: "anthropic", modelID: "sonnet", variant: "high");
      final state = _state(
        promptDefaults: const SessionPromptDefaults(agent: "explore", model: model),
        messages: [_assistant(id: "reply", agent: "build", modelID: "haiku", sender: MessageSender.agent)],
      );

      expect(state.ranWith, (agent: "explore", model: model));
    });

    test("falls back to the newest agent reply, which records no variant", () {
      final state = _state(
        promptDefaults: null,
        messages: [
          _assistant(id: "older", agent: "plan", modelID: "opus", sender: MessageSender.agent),
          _assistant(id: "reply", agent: "build", modelID: "sonnet", sender: MessageSender.agent),
          _assistant(id: "automation", agent: "compaction", modelID: "haiku", sender: MessageSender.system),
          const MessageWithParts(
            info: Message.user(id: "turn", sessionID: "session-1", agent: "general", time: null, promptId: null),
            parts: [],
          ),
        ],
      );

      expect(
        state.ranWith,
        (agent: "build", model: const AgentModel(providerID: "anthropic", modelID: "sonnet", variant: null)),
      );
    });

    test("is unknown when neither the bridge nor a reply names it", () {
      final state = _state(
        promptDefaults: null,
        messages: [_assistant(id: "reply", agent: null, modelID: null, sender: MessageSender.agent)],
      );

      expect(state.ranWith, (agent: null, model: null));
    });
  });
}

MessageWithParts _assistant({
  required String id,
  required String? agent,
  required String? modelID,
  required MessageSender sender,
}) {
  return MessageWithParts(
    info: Message.assistant(
      id: id,
      sessionID: "session-1",
      agent: agent,
      modelID: modelID,
      providerID: modelID == null ? null : "anthropic",
      sender: sender,
      time: null,
    ),
    parts: const [],
  );
}

SessionDetailLoaded _state({
  required SessionPromptDefaults? promptDefaults,
  required List<MessageWithParts> messages,
}) {
  return SessionDetailLoaded(
    interaction: const SessionInteractionState.available(displayName: "Claude Code", refreshError: null),
    messages: messages,
    olderMessagesCursor: null,
    transcriptFolded: false,
    streamingText: const {},
    sessionStatus: const SessionStatus.idle(),
    pendingQuestions: const [],
    pendingPermissions: const [],
    sessionTitle: null,
    session: testConstSession,
    pluginId: "opencode",
    supportsPromptAttachments: false,
    assistantAgentModel: null,
    children: const [],
    childStatuses: const {},
    isRootSession: false,
    isArchived: false,
    queuedMessages: const [],
    bridgePromptAttachments: const {},
    localSend: const LocalSendPhase.idle(),
    availableAgents: const [],
    availableProviders: const [],
    availableCommands: const [],
    selectedAgent: "build",
    selectedAgentModel: null,
    promptDefaults: promptDefaults,
    fastMode: false,
    stagedCommand: null,
    isRefreshing: false,
  );
}
