import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "queued_session_submission.dart";

part "session_detail_state.freezed.dart";

@Freezed()
sealed class SessionDetailState with _$SessionDetailState {
  const factory SessionDetailState.loading() = SessionDetailLoading;

  const factory SessionDetailState.loaded({
    required List<MessageWithParts> messages,
    required Map<String, String> streamingText,
    required SessionStatus sessionStatus,
    required List<SesoriQuestionAsked> pendingQuestions,
    required List<SesoriPermissionAsked> pendingPermissions,
    // Session title — updated reactively via SSE `session.updated` events.
    required String? sessionTitle,
    // Agent/model from the latest assistant message.
    required String? agent,
    required AgentModel? assistantAgentModel,
    // Background tasks (child sessions).
    required List<Session> children,
    required Map<String, SessionStatus> childStatuses,
    // Queued messages (waiting to be sent when connection is restored).
    required List<QueuedSessionSubmission> queuedMessages,
    // Available agents and providers for selection.
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required List<CommandInfo> availableCommands,

    // Currently selected agent and model (pre-populated from defaults, never null once loaded).
    required String selectedAgent,
    required AgentModel? selectedAgentModel,
    required CommandInfo? stagedCommand,
    required bool isRefreshing,
  }) = SessionDetailLoaded;

  const factory SessionDetailState.failed({required ApiError error}) = SessionDetailFailed;
}
