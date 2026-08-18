import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "queued_session_submission.dart";

part "session_detail_state.freezed.dart";

@Freezed()
sealed class SessionDetailState with _$SessionDetailState {
  const factory loading() = SessionDetailLoading;

  const factory loaded({
    required List<MessageWithParts> messages,

    /// Cursor for the page of messages before [messages], or null when the
    /// start of the transcript is loaded — so the UI shows no load-older
    /// affordance. Also null against a bridge that predates pagination, which
    /// always sends the whole transcript.
    required int? olderMessagesCursor,

    /// Whether a load-older request is in flight, so the action is not
    /// re-issued while it runs.
    @Default(false) bool isLoadingOlderMessages,
    required Map<String, String> streamingText,
    required SessionStatus sessionStatus,
    required List<SesoriQuestionAsked> pendingQuestions,
    required List<SesoriPermissionAsked> pendingPermissions,
    // Session title — updated reactively via SSE `session.updated` events.
    required String? sessionTitle,
    // The harness running this session, or null when it could not be resolved.
    required String? pluginId,
    // Null when the plugin metadata lookup could not resolve the capability.
    required bool? supportsPromptAttachments,
    // Agent/model from the latest assistant message.
    required String? agent,
    required AgentModel? assistantAgentModel,
    // Background tasks (child sessions).
    required List<Session> children,
    required Map<String, SessionStatus> childStatuses,
    // Whether this session is a root (main) session. `true` = root,
    // `false` = child, `null` = unknown (metadata lookup failed).
    required bool? isRootSession,
    required bool isArchived,
    // Queued messages (waiting to be sent when connection is restored).
    required List<QueuedSessionSubmission> queuedMessages,
    // Submission currently awaiting bridge acceptance.
    required QueuedSessionSubmission? sendingSubmission,

    // Prompts the bridge has accepted but not yet dispatched to the harness,
    // owned by the bridge (snapshot + session.queued-prompts events). Distinct
    // from [queuedMessages], which only stages sends the bridge has not
    // accepted yet.
    @Default([]) List<QueuedSessionPrompt> bridgeQueuedPrompts,
    // Available agents and providers for selection.
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required List<CommandInfo> availableCommands,

    // Currently selected agent and model (pre-populated from defaults, never null once loaded).
    required String selectedAgent,
    required AgentModel? selectedAgentModel,
    required CommandInfo? stagedCommand,
    required bool isRefreshing,
    @Default([]) List<SessionVariant> availableVariants,
    // Transient retry error message from the AI provider (e.g. "Provider is overloaded").
    required String? retryErrorMessage,
  }) = SessionDetailLoaded;

  const factory failed({required RemoteFailureReason reason}) = SessionDetailFailed;
}
