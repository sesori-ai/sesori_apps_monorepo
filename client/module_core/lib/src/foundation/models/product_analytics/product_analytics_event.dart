import "package:meta/meta.dart";

enum SupportChannel({required this.wireValue}) {
  email(wireValue: "email"),
  discord(wireValue: "discord"),
  x(wireValue: "x");

  final String wireValue;
}

enum OnboardingSurface({required this.wireValue}) {
  connectSetup(wireValue: "connect_setup"),
  connectedEmpty(wireValue: "connected_empty"),
  bridgeOffline(wireValue: "bridge_offline");

  final String wireValue;
}

enum BridgeInstallMethod({required this.wireValue}) {
  curl(wireValue: "curl"),
  powershell(wireValue: "powershell"),
  npm(wireValue: "npm"),
  bun(wireValue: "bun");

  final String wireValue;
}

enum BridgeInstallOs({required this.wireValue}) {
  unix(wireValue: "unix"),
  windows(wireValue: "windows");

  final String wireValue;
}

enum AnalyticsScreen({required this.wireValue}) {
  login(wireValue: "login"),
  projects(wireValue: "projects"),
  settings(wireValue: "settings"),
  settingsNotifications(wireValue: "settings_notifications"),
  settingsProfile(wireValue: "settings_profile"),
  sessions(wireValue: "sessions"),
  newSession(wireValue: "new_session"),
  sessionDetail(wireValue: "session_detail"),
  sessionDiffs(wireValue: "session_diffs");

  final String wireValue;
}

enum AnalyticsInputMode({required this.wireValue}) {
  typed(wireValue: "typed"),
  voiceAssisted(wireValue: "voice_assisted");

  final String wireValue;
}

enum AnalyticsInventoryState({required this.wireValue}) {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty");

  final String wireValue;
}

enum AnalyticsActivityState({required this.wireValue}) {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty");

  final String wireValue;
}

enum AnalyticsSubmissionKind({required this.wireValue}) {
  text(wireValue: "text"),
  command(wireValue: "command");

  final String wireValue;
}

@immutable
sealed class const AnalyticsSubmission() {
  const factory AnalyticsSubmission.text({required AnalyticsInputMode inputMode}) = AnalyticsTextSubmission;
  const factory AnalyticsSubmission.command() = AnalyticsCommandSubmission;

  AnalyticsSubmissionKind get kind;
  AnalyticsInputMode get inputMode;
}

final class const AnalyticsTextSubmission({required this.inputMode}) extends AnalyticsSubmission {
  @override
  final AnalyticsInputMode inputMode;

  @override
  AnalyticsSubmissionKind get kind => AnalyticsSubmissionKind.text;
}

final class const AnalyticsCommandSubmission() extends AnalyticsSubmission {
  @override
  AnalyticsSubmissionKind get kind => AnalyticsSubmissionKind.command;

  @override
  AnalyticsInputMode get inputMode => AnalyticsInputMode.typed;
}

enum AnalyticsWorkspaceKind({required this.wireValue}) {
  project(wireValue: "project"),
  dedicatedWorktree(wireValue: "dedicated_worktree");

  final String wireValue;
}

enum AnalyticsSessionCreationFailureReason({required this.wireValue}) {
  notAuthenticated(wireValue: "not_authenticated"),
  serverRejected(wireValue: "server_rejected"),
  networkDown(wireValue: "network_down"),
  badResponse(wireValue: "bad_response"),
  unknown(wireValue: "unknown");

  final String wireValue;
}

enum AnalyticsPermissionDecision({required this.wireValue}) {
  once(wireValue: "once"),
  always(wireValue: "always"),
  reject(wireValue: "reject");

  final String wireValue;
}

/// Outcome of a phone-triggered managed harness runtime install. Bounded on
/// purpose: the harness identity and any failure text stay off the wire.
enum AnalyticsHarnessInstallOutcome({required this.wireValue}) {
  completed(wireValue: "completed"),
  failed(wireValue: "failed");

  final String wireValue;
}

enum AnalyticsChangeState({required this.wireValue}) {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty");

  final String wireValue;
}

@immutable
sealed class const ProductAnalyticsEvent() {
  const factory ProductAnalyticsEvent.analyticsSchemaReady() = AnalyticsSchemaReadyEvent;
  const factory ProductAnalyticsEvent.analyticsActivationReady() = AnalyticsActivationReadyEvent;
  const factory ProductAnalyticsEvent.projectInventoryLoaded({
    required AnalyticsInventoryState inventoryState,
  }) = ProjectInventoryLoadedEvent;
  const factory ProductAnalyticsEvent.sessionActivityViewed({
    required AnalyticsActivityState activityState,
  }) = SessionActivityViewedEvent;
  const factory ProductAnalyticsEvent.sessionMessageSent({
    required AnalyticsSubmission submission,
  }) = SessionMessageSentEvent;
  const factory ProductAnalyticsEvent.sessionCreatedWithMessage({
    required AnalyticsSubmission submission,
    required AnalyticsWorkspaceKind workspaceKind,
  }) = SessionCreatedWithMessageEvent;
  const factory ProductAnalyticsEvent.sessionCreationFailed({
    required AnalyticsSessionCreationFailureReason failureReason,
    required AnalyticsWorkspaceKind workspaceKind,
  }) = SessionCreationFailedEvent;
  const factory ProductAnalyticsEvent.voiceTranscriptionCompleted() = VoiceTranscriptionCompletedEvent;
  const factory ProductAnalyticsEvent.sessionQuestionAnswered() = SessionQuestionAnsweredEvent;
  const factory ProductAnalyticsEvent.sessionQuestionRejected() = SessionQuestionRejectedEvent;
  const factory ProductAnalyticsEvent.sessionPermissionAnswered({
    required AnalyticsPermissionDecision decision,
  }) = SessionPermissionAnsweredEvent;
  const factory ProductAnalyticsEvent.sessionAbortSucceeded() = SessionAbortSucceededEvent;
  const factory ProductAnalyticsEvent.harnessInstallFinished({
    required AnalyticsHarnessInstallOutcome outcome,
  }) = HarnessInstallFinishedEvent;
  const factory ProductAnalyticsEvent.sessionDiffViewed({
    required AnalyticsChangeState changeState,
  }) = SessionDiffViewedEvent;
  const factory ProductAnalyticsEvent.needHelpMenuOpened({required OnboardingSurface surface}) =
      NeedHelpMenuOpenedEvent;
  const factory ProductAnalyticsEvent.supportLinkOpened({
    required SupportChannel channel,
    required OnboardingSurface surface,
  }) = SupportLinkOpenedEvent;
  const factory ProductAnalyticsEvent.whyBridgeOpened({required OnboardingSurface surface}) = WhyBridgeOpenedEvent;
  const factory ProductAnalyticsEvent.installCommandCopied({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) = InstallCommandCopiedEvent;
  const factory ProductAnalyticsEvent.installCommandShared({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) = InstallCommandSharedEvent;
  const factory ProductAnalyticsEvent.runCommandCopied({required OnboardingSurface surface}) = RunCommandCopiedEvent;
  const factory ProductAnalyticsEvent.runCommandShared({required OnboardingSurface surface}) = RunCommandSharedEvent;
  const factory ProductAnalyticsEvent.screenViewed({required AnalyticsScreen screen}) = ProductScreenViewedEvent;

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

final class const ProjectInventoryLoadedEvent({required this.inventoryState}) extends ProductAnalyticsEvent {
  final AnalyticsInventoryState inventoryState;

  @override
  String get wireName => "project_inventory_loaded";

  @override
  Map<String, String> get parameters => {"inventory_state": inventoryState.wireValue};
}

final class const SessionActivityViewedEvent({required this.activityState}) extends ProductAnalyticsEvent {
  final AnalyticsActivityState activityState;

  @override
  String get wireName => "session_activity_viewed";

  @override
  Map<String, String> get parameters => {"activity_state": activityState.wireValue};
}

final class const SessionMessageSentEvent({required this.submission}) extends ProductAnalyticsEvent {
  final AnalyticsSubmission submission;

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
    required this.submission,
    required this.workspaceKind,
  }) extends ProductAnalyticsEvent {
  final AnalyticsSubmission submission;
  final AnalyticsWorkspaceKind workspaceKind;

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

final class const SessionCreationFailedEvent({required this.failureReason, required this.workspaceKind}) extends ProductAnalyticsEvent {
  final AnalyticsSessionCreationFailureReason failureReason;
  final AnalyticsWorkspaceKind workspaceKind;

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

final class const SessionPermissionAnsweredEvent({required this.decision}) extends ProductAnalyticsEvent {
  final AnalyticsPermissionDecision decision;

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
final class const HarnessInstallFinishedEvent({required this.outcome}) extends ProductAnalyticsEvent {
  final AnalyticsHarnessInstallOutcome outcome;

  @override
  String get wireName => "harness_install_finished";

  @override
  Map<String, String> get parameters => {"outcome": outcome.wireValue};
}

final class const SessionDiffViewedEvent({required this.changeState}) extends ProductAnalyticsEvent {
  final AnalyticsChangeState changeState;

  @override
  String get wireName => "session_diff_viewed";

  @override
  Map<String, String> get parameters => {"change_state": changeState.wireValue};
}

final class const NeedHelpMenuOpenedEvent({required this.surface}) extends ProductAnalyticsEvent {
  final OnboardingSurface surface;

  @override
  String get wireName => "onboarding_need_help_opened";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class const SupportLinkOpenedEvent({required this.channel, required this.surface}) extends ProductAnalyticsEvent {
  final SupportChannel channel;
  final OnboardingSurface surface;

  @override
  String get wireName => "onboarding_support_link_opened";

  @override
  Map<String, String> get parameters => {"channel": channel.wireValue, "surface": surface.wireValue};
}

final class const WhyBridgeOpenedEvent({required this.surface}) extends ProductAnalyticsEvent {
  final OnboardingSurface surface;

  @override
  String get wireName => "onboarding_why_bridge_opened";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class const InstallCommandCopiedEvent({required this.method, required this.os, required this.surface}) extends ProductAnalyticsEvent {
  final BridgeInstallMethod method;
  final BridgeInstallOs os;
  final OnboardingSurface surface;

  @override
  String get wireName => "bridge_install_command_copied";

  @override
  Map<String, String> get parameters => {
    "method": method.wireValue,
    "os": os.wireValue,
    "surface": surface.wireValue,
  };
}

final class const InstallCommandSharedEvent({required this.method, required this.os, required this.surface}) extends ProductAnalyticsEvent {
  final BridgeInstallMethod method;
  final BridgeInstallOs os;
  final OnboardingSurface surface;

  @override
  String get wireName => "bridge_install_command_shared";

  @override
  Map<String, String> get parameters => {
    "method": method.wireValue,
    "os": os.wireValue,
    "surface": surface.wireValue,
  };
}

final class const RunCommandCopiedEvent({required this.surface}) extends ProductAnalyticsEvent {
  final OnboardingSurface surface;

  @override
  String get wireName => "bridge_run_command_copied";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class const RunCommandSharedEvent({required this.surface}) extends ProductAnalyticsEvent {
  final OnboardingSurface surface;

  @override
  String get wireName => "bridge_run_command_shared";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class const ProductScreenViewedEvent({required this.screen}) extends ProductAnalyticsEvent {
  final AnalyticsScreen screen;

  @override
  String get wireName => "product_screen_viewed";

  @override
  Map<String, String> get parameters => {"screen": screen.wireValue};
}

final class ProductAnalyticsEnvelope({required this.event, required DateTime occurredAtUtc}) {
  final ProductAnalyticsEvent event;
  final DateTime occurredAtUtc;

  this
    : occurredAtUtc = occurredAtUtc.toUtc();
}
