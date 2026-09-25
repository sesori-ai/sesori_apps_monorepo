import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "../../foundation/models/composer/composer_attachment.dart";
import "../../foundation/models/session_interaction_state.dart";
import "../../services/fast_mode_toggle_calculator.dart";
import "../../services/session_selection_calculator.dart";
import "local_send_phase.dart";
import "queued_session_submission.dart";
import "session_approval_control.dart";

part "session_detail_state.freezed.dart";

@Freezed()
sealed class SessionDetailState with _$SessionDetailState {
  const factory loading() = SessionDetailLoading;

  const factory loaded({
    required SessionInteractionState interaction,
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
    // The hydrated session, for surfaces that act on it (rename, archive,
    // delete).
    required Session session,
    @Default(false) bool isUpdatingAutoContinuation,
    // The harness running this session, or null when it could not be resolved.
    required String? pluginId,
    // Null when the plugin metadata lookup could not resolve the capability.
    required bool? supportsPromptAttachments,
    // Model from the latest assistant message.
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
    // The head submission awaiting bridge acceptance, or failed; later
    // [queuedMessages] wait behind a failed one until Retry or removal.
    required LocalSendPhase localSend,

    // Prompts the bridge has accepted and retains until their user echo is visible,
    // owned by the bridge (snapshot + session.queued-prompts events). Distinct
    // from [queuedMessages], which only stages sends the bridge has not
    // accepted yet.
    @Default([]) List<QueuedSessionPrompt> bridgeQueuedPrompts,
    // Memory-only, bounded previews retained from this surface's submissions.
    required Map<String, List<ComposerAttachment>> bridgePromptAttachments,
    // Accepted sends whose bridge-side representation has not arrived yet.
    // Rendered as read-only queue rows so a prompt never blanks between
    // its acceptance response and the bridge's queue event listing it.
    @Default([]) List<QueuedSessionSubmission> awaitingBridgeSubmissions,
    // Available agents and providers for selection.
    required List<AgentInfo> availableAgents,
    required List<ProviderInfo> availableProviders,
    required List<CommandInfo> availableCommands,

    // Currently selected agent and model (pre-populated from defaults, never null once loaded).
    required String selectedAgent,
    required AgentModel? selectedAgentModel,

    /// The user's fast-mode choice, reconciled from the bridge's prompt
    /// defaults. It only runs while the selected model's fast mode is
    /// available; see [SessionDetailLoadedX.runsFastMode].
    required bool fastMode,
    required CommandInfo? stagedCommand,
    required bool isRefreshing,
    @Default([]) List<SessionVariant> availableVariants,

    /// The connected bridge's YOLO setting, as last known by
    /// `BridgeSettingsService`. See [SessionDetailLoadedX.approvalControl].
    @Default(YoloSettingsResponse(enabled: false)) YoloSettingsResponse bridgeYolo,

    /// Whether a change to the session's approval mode awaits the bridge.
    @Default(false) bool isUpdatingApproval,
  }) = SessionDetailLoaded;

  /// The harness is blocked *and* the bridge's store holds nothing for this
  /// session, so the transcript only exists behind the harness the user has to
  /// enable. A blocked session with any stored history is an ordinary
  /// [SessionDetailLoaded] carrying a blocked interaction.
  const factory harnessUnavailable({
    required Session session,
    required SessionInteractionState interaction,
    @Default(false) bool isUpdatingAutoContinuation,
  }) = SessionDetailHarnessUnavailable;

  const factory failed({required RemoteFailureReason reason}) = SessionDetailFailed;
}

extension SessionDetailStateX on SessionDetailState {
  bool get autoContinuationUpdatePending => switch (this) {
    SessionDetailLoaded(:final isUpdatingAutoContinuation) ||
    SessionDetailHarnessUnavailable(:final isUpdatingAutoContinuation) => isUpdatingAutoContinuation,
    SessionDetailLoading() || SessionDetailFailed() => false,
  };

  /// The hydrated session, for the variants that have one.
  Session? get hydratedSession => switch (this) {
    SessionDetailLoaded(:final session) || SessionDetailHarnessUnavailable(:final session) => session,
    SessionDetailLoading() || SessionDetailFailed() => null,
  };
}

extension SessionDetailLoadedX on SessionDetailLoaded {
  static const SessionSelectionCalculator _selection = SessionSelectionCalculator();
  static const FastModeToggleCalculator _fastModeToggle = FastModeToggleCalculator();

  String? get retryErrorMessage => switch (sessionStatus) {
    SessionStatusRetry(:final message) => message,
    SessionStatusIdle() || SessionStatusBusy() => null,
  };

  /// The selected model's fast mode, or null when it has none.
  FastModeSupport? get fastModeSupport =>
      _selection.fastModeSupport(providers: availableProviders, model: selectedAgentModel);

  /// Whether the next prompt runs in fast mode.
  bool get runsFastMode =>
      _selection.resolvedFastMode(providers: availableProviders, model: selectedAgentModel, requested: fastMode);

  /// What the composer offers for this session's permission approval.
  SessionApprovalControl get approvalControl =>
      SessionApprovalControl.resolve(bridge: bridgeYolo, sessionOverride: session.approvalOverride);

  FastModeControl get fastModeControl => _fastModeToggle.control(support: fastModeSupport, fastMode: runsFastMode);
}
