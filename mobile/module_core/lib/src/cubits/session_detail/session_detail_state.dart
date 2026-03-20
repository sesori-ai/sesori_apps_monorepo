import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

part "session_detail_state.freezed.dart";

@Freezed()
sealed class SessionDetailState with _$SessionDetailState {
  const factory SessionDetailState.loading() = SessionDetailLoading;

  const factory SessionDetailState.loaded({
    required List<MessageWithParts> messages,
    required Map<String, String> streamingText,
    required SessionStatus sessionStatus,
    @Default([]) List<SesoriQuestionAsked> pendingQuestions,
    // Session title — updated reactively via SSE `session.updated` events.
    String? sessionTitle,
    // Agent/model from the latest assistant message.
    String? agent,
    String? modelID,
    String? providerID,
    // Background tasks (child sessions).
    @Default([]) List<Session> children,
    @Default({}) Map<String, SessionStatus> childStatuses,
    // Queued messages (waiting to be sent when session becomes idle).
    @Default([]) List<String> queuedMessages,
    // Available agents and providers for selection.
    @Default([]) List<AgentInfo> availableAgents,
    @Default([]) List<ProviderInfo> availableProviders,

    // Currently selected agent and model (pre-populated from defaults, never null once loaded).
    required String selectedAgent,
    required String selectedProviderID,
    required String selectedModelID,
  }) = SessionDetailLoaded;

  const factory SessionDetailState.failed({required ApiError error}) = SessionDetailFailed;
}
