import "package:meta/meta.dart";

enum SupportChannel({required final String wireValue}) {
  email(wireValue: "email"),
  discord(wireValue: "discord"),
  x(wireValue: "x");
}

enum OnboardingSurface({required final String wireValue}) {
  connectSetup(wireValue: "connect_setup"),
  connectedEmpty(wireValue: "connected_empty"),
  bridgeOffline(wireValue: "bridge_offline");
}

enum BridgeInstallMethod({required final String wireValue}) {
  curl(wireValue: "curl"),
  powershell(wireValue: "powershell"),
  npm(wireValue: "npm"),
  bun(wireValue: "bun");
}

enum BridgeInstallOs({required final String wireValue}) {
  unix(wireValue: "unix"),
  windows(wireValue: "windows");
}

enum AnalyticsScreen({required final String wireValue}) {
  login(wireValue: "login"),
  projects(wireValue: "projects"),
  settings(wireValue: "settings"),
  settingsNotifications(wireValue: "settings_notifications"),
  settingsProfile(wireValue: "settings_profile"),
  sessions(wireValue: "sessions"),
  newSession(wireValue: "new_session"),
  sessionDetail(wireValue: "session_detail"),
  sessionDiffs(wireValue: "session_diffs");
}

enum AnalyticsInputMode({required final String wireValue}) {
  typed(wireValue: "typed"),
  voiceAssisted(wireValue: "voice_assisted");
}

enum AnalyticsInventoryState({required final String wireValue}) {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty");
}

enum AnalyticsActivityState({required final String wireValue}) {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty");
}

enum AnalyticsSubmissionKind({required final String wireValue}) {
  text(wireValue: "text"),
  command(wireValue: "command");
}

@immutable
sealed class const AnalyticsSubmission() {
  const factory text({required AnalyticsInputMode inputMode}) = AnalyticsTextSubmission;
  const factory command() = AnalyticsCommandSubmission;

  AnalyticsSubmissionKind get kind;
  AnalyticsInputMode get inputMode;
}

final class const AnalyticsTextSubmission({@override required final AnalyticsInputMode inputMode})
    extends AnalyticsSubmission {
  @override
  AnalyticsSubmissionKind get kind => AnalyticsSubmissionKind.text;
}

final class const AnalyticsCommandSubmission() extends AnalyticsSubmission {
  @override
  AnalyticsSubmissionKind get kind => AnalyticsSubmissionKind.command;

  @override
  AnalyticsInputMode get inputMode => AnalyticsInputMode.typed;
}

enum AnalyticsWorkspaceKind({required final String wireValue}) {
  project(wireValue: "project"),
  dedicatedWorktree(wireValue: "dedicated_worktree");
}

enum AnalyticsSessionCreationFailureReason({required final String wireValue}) {
  notAuthenticated(wireValue: "not_authenticated"),
  serverRejected(wireValue: "server_rejected"),
  networkDown(wireValue: "network_down"),
  badResponse(wireValue: "bad_response"),
  unknown(wireValue: "unknown");
}

enum AnalyticsPermissionDecision({required final String wireValue}) {
  once(wireValue: "once"),
  always(wireValue: "always"),
  reject(wireValue: "reject");
}

/// Outcome of a phone-triggered managed harness runtime install. Bounded on
/// purpose: the harness identity and any failure text stay off the wire.
enum AnalyticsHarnessInstallOutcome({required final String wireValue}) {
  completed(wireValue: "completed"),
  failed(wireValue: "failed");
}

enum AnalyticsChangeState({required final String wireValue}) {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty");
}

@immutable
sealed class const ProductAnalyticsEvent() {
  const factory analyticsSchemaReady() = AnalyticsSchemaReadyEvent;
  const factory analyticsActivationReady() = AnalyticsActivationReadyEvent;
  const factory projectInventoryLoaded({
    required AnalyticsInventoryState inventoryState,
  }) = ProjectInventoryLoadedEvent;
  const factory sessionActivityViewed({
    required AnalyticsActivityState activityState,
  }) = SessionActivityViewedEvent;
  const factory sessionMessageSent({
    required AnalyticsSubmission submission,
  }) = SessionMessageSentEvent;
  const factory sessionCreatedWithMessage({
    required AnalyticsSubmission submission,
    required AnalyticsWorkspaceKind workspaceKind,
  }) = SessionCreatedWithMessageEvent;
  const factory sessionCreationFailed({
    required AnalyticsSessionCreationFailureReason failureReason,
    required AnalyticsWorkspaceKind workspaceKind,
  }) = SessionCreationFailedEvent;
  const factory voiceTranscriptionCompleted() = VoiceTranscriptionCompletedEvent;
  const factory sessionQuestionAnswered() = SessionQuestionAnsweredEvent;
  const factory sessionQuestionRejected() = SessionQuestionRejectedEvent;
  const factory sessionPermissionAnswered({
    required AnalyticsPermissionDecision decision,
  }) = SessionPermissionAnsweredEvent;
  const factory sessionAbortSucceeded() = SessionAbortSucceededEvent;
  const factory harnessInstallFinished({
    required AnalyticsHarnessInstallOutcome outcome,
  }) = HarnessInstallFinishedEvent;
  const factory sessionDiffViewed({
    required AnalyticsChangeState changeState,
  }) = SessionDiffViewedEvent;
  const factory needHelpMenuOpened({required OnboardingSurface surface}) = NeedHelpMenuOpenedEvent;
  const factory supportLinkOpened({
    required SupportChannel channel,
    required OnboardingSurface surface,
  }) = SupportLinkOpenedEvent;
  const factory whyBridgeOpened({required OnboardingSurface surface}) = WhyBridgeOpenedEvent;
  const factory installCommandCopied({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) = InstallCommandCopiedEvent;
  const factory installCommandShared({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) = InstallCommandSharedEvent;
  const factory runCommandCopied({required OnboardingSurface surface}) = RunCommandCopiedEvent;
  const factory runCommandShared({required OnboardingSurface surface}) = RunCommandSharedEvent;
  const factory screenViewed({required AnalyticsScreen screen}) = ProductScreenViewedEvent;

  String get wireName;
  Map<String, String> get parameters;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAnalyticsEvent &&
          wireName == other.wireName &&
          parameters.length == other.parameters.length &&
          parameters.entries.every((entry) => other.parameters[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(
    wireName,
    Object.hashAllUnordered(parameters.entries.map((entry) => Object.hash(entry.key, entry.value))),
  );
}

final class const AnalyticsSchemaReadyEvent() extends ProductAnalyticsEvent {
  @override
  String get wireName => "analytics_schema_ready";

  @override
  Map<String, String> get parameters => const {};
}

final class const AnalyticsActivationReadyEvent() extends ProductAnalyticsEvent {
  @override
  String get wireName => "analytics_activation_ready";

  @override
  Map<String, String> get parameters => const {"activation_schema_version": "1"};
}

final class const ProjectInventoryLoadedEvent({required final AnalyticsInventoryState inventoryState})
    extends ProductAnalyticsEvent {
  @override
  String get wireName => "project_inventory_loaded";

  @override
  Map<String, String> get parameters => {"inventory_state": inventoryState.wireValue};
}

final class const SessionActivityViewedEvent({required final AnalyticsActivityState activityState})
    extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_activity_viewed";

  @override
  Map<String, String> get parameters => {"activity_state": activityState.wireValue};
}

final class const SessionMessageSentEvent({required final AnalyticsSubmission submission})
    extends ProductAnalyticsEvent {
  AnalyticsSubmissionKind get submissionKind => submission.kind;
  AnalyticsInputMode get inputMode => submission.inputMode;

  @override
  String get wireName => "session_message_sent";

  @override
  Map<String, String> get parameters => {
    "submission_kind": submissionKind.wireValue,
    "input_mode": inputMode.wireValue,
  };
}

final class const SessionCreatedWithMessageEvent({
  required final AnalyticsSubmission submission,
  required final AnalyticsWorkspaceKind workspaceKind,
}) extends ProductAnalyticsEvent {
  AnalyticsSubmissionKind get submissionKind => submission.kind;
  AnalyticsInputMode get inputMode => submission.inputMode;

  @override
  String get wireName => "session_created_with_message";

  @override
  Map<String, String> get parameters => {
    "submission_kind": submissionKind.wireValue,
    "input_mode": inputMode.wireValue,
    "workspace_kind": workspaceKind.wireValue,
  };
}

final class const SessionCreationFailedEvent({
  required final AnalyticsSessionCreationFailureReason failureReason,
  required final AnalyticsWorkspaceKind workspaceKind,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_creation_failed";

  @override
  Map<String, String> get parameters => {
    "failure_reason": failureReason.wireValue,
    "workspace_kind": workspaceKind.wireValue,
  };
}

final class const VoiceTranscriptionCompletedEvent() extends ProductAnalyticsEvent {
  @override
  String get wireName => "voice_transcription_completed";

  @override
  Map<String, String> get parameters => const {};
}

final class const SessionQuestionAnsweredEvent() extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_question_answered";

  @override
  Map<String, String> get parameters => const {};
}

final class const SessionQuestionRejectedEvent() extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_question_rejected";

  @override
  Map<String, String> get parameters => const {};
}

final class const SessionPermissionAnsweredEvent({required final AnalyticsPermissionDecision decision})
    extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_permission_answered";

  @override
  Map<String, String> get parameters => {"decision": decision.wireValue};
}

final class const SessionAbortSucceededEvent() extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_abort_succeeded";

  @override
  Map<String, String> get parameters => const {};
}

/// Whether a phone-triggered harness runtime install actually succeeded — the
/// adoption signal for install-from-phone. Reported at the bridge's terminal
/// install event, not at the tap.
final class const HarnessInstallFinishedEvent({required final AnalyticsHarnessInstallOutcome outcome})
    extends ProductAnalyticsEvent {
  @override
  String get wireName => "harness_install_finished";

  @override
  Map<String, String> get parameters => {"outcome": outcome.wireValue};
}

final class const SessionDiffViewedEvent({required final AnalyticsChangeState changeState})
    extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_diff_viewed";

  @override
  Map<String, String> get parameters => {"change_state": changeState.wireValue};
}

final class const NeedHelpMenuOpenedEvent({required final OnboardingSurface surface}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "onboarding_need_help_opened";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class const SupportLinkOpenedEvent({
  required final SupportChannel channel,
  required final OnboardingSurface surface,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "onboarding_support_link_opened";

  @override
  Map<String, String> get parameters => {"channel": channel.wireValue, "surface": surface.wireValue};
}

final class const WhyBridgeOpenedEvent({required final OnboardingSurface surface}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "onboarding_why_bridge_opened";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class const InstallCommandCopiedEvent({
  required final BridgeInstallMethod method,
  required final BridgeInstallOs os,
  required final OnboardingSurface surface,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "bridge_install_command_copied";

  @override
  Map<String, String> get parameters => {
    "method": method.wireValue,
    "os": os.wireValue,
    "surface": surface.wireValue,
  };
}

final class const InstallCommandSharedEvent({
  required final BridgeInstallMethod method,
  required final BridgeInstallOs os,
  required final OnboardingSurface surface,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "bridge_install_command_shared";

  @override
  Map<String, String> get parameters => {
    "method": method.wireValue,
    "os": os.wireValue,
    "surface": surface.wireValue,
  };
}

final class const RunCommandCopiedEvent({required final OnboardingSurface surface}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "bridge_run_command_copied";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class const RunCommandSharedEvent({required final OnboardingSurface surface}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "bridge_run_command_shared";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class const ProductScreenViewedEvent({required final AnalyticsScreen screen}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "product_screen_viewed";

  @override
  Map<String, String> get parameters => {"screen": screen.wireValue};
}

final class ProductAnalyticsEnvelope({required final ProductAnalyticsEvent event, required DateTime occurredAtUtc}) {
  final DateTime occurredAtUtc = occurredAtUtc.toUtc();
}
