import "package:meta/meta.dart";

enum SupportChannel {
  email(wireValue: "email"),
  discord(wireValue: "discord"),
  x(wireValue: "x");

  final String wireValue;
  SupportChannel({required this.wireValue});
}

enum OnboardingSurface {
  connectSetup(wireValue: "connect_setup"),
  connectedEmpty(wireValue: "connected_empty"),
  bridgeOffline(wireValue: "bridge_offline");

  final String wireValue;
  OnboardingSurface({required this.wireValue});
}

enum BridgeInstallMethod {
  curl(wireValue: "curl"),
  powershell(wireValue: "powershell"),
  npm(wireValue: "npm"),
  bun(wireValue: "bun");

  final String wireValue;
  BridgeInstallMethod({required this.wireValue});
}

enum BridgeInstallOs {
  unix(wireValue: "unix"),
  windows(wireValue: "windows");

  final String wireValue;
  BridgeInstallOs({required this.wireValue});
}

enum AnalyticsScreen {
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
  AnalyticsScreen({required this.wireValue});
}

enum AnalyticsInputMode {
  typed(wireValue: "typed"),
  voiceAssisted(wireValue: "voice_assisted");

  final String wireValue;
  AnalyticsInputMode({required this.wireValue});
}

enum AnalyticsInventoryState {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty");

  final String wireValue;
  AnalyticsInventoryState({required this.wireValue});
}

enum AnalyticsActivityState {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty");

  final String wireValue;
  AnalyticsActivityState({required this.wireValue});
}

enum AnalyticsSubmissionKind {
  text(wireValue: "text"),
  command(wireValue: "command");

  final String wireValue;
  AnalyticsSubmissionKind({required this.wireValue});
}

@immutable
sealed class AnalyticsSubmission {
  const AnalyticsSubmission();

  const factory AnalyticsSubmission.text({required AnalyticsInputMode inputMode}) = AnalyticsTextSubmission;
  const factory AnalyticsSubmission.command() = AnalyticsCommandSubmission;

  AnalyticsSubmissionKind get kind;
  AnalyticsInputMode get inputMode;
}

final class AnalyticsTextSubmission extends AnalyticsSubmission {
  @override
  final AnalyticsInputMode inputMode;

  const AnalyticsTextSubmission({required this.inputMode});

  @override
  AnalyticsSubmissionKind get kind => AnalyticsSubmissionKind.text;
}

final class AnalyticsCommandSubmission extends AnalyticsSubmission {
  const AnalyticsCommandSubmission();

  @override
  AnalyticsSubmissionKind get kind => AnalyticsSubmissionKind.command;

  @override
  AnalyticsInputMode get inputMode => AnalyticsInputMode.typed;
}

enum AnalyticsWorkspaceKind {
  project(wireValue: "project"),
  dedicatedWorktree(wireValue: "dedicated_worktree");

  final String wireValue;
  AnalyticsWorkspaceKind({required this.wireValue});
}

enum AnalyticsSessionCreationFailureReason {
  notAuthenticated(wireValue: "not_authenticated"),
  serverRejected(wireValue: "server_rejected"),
  networkDown(wireValue: "network_down"),
  badResponse(wireValue: "bad_response"),
  unknown(wireValue: "unknown");

  final String wireValue;
  AnalyticsSessionCreationFailureReason({required this.wireValue});
}

enum AnalyticsPermissionDecision {
  once(wireValue: "once"),
  always(wireValue: "always"),
  reject(wireValue: "reject");

  final String wireValue;
  AnalyticsPermissionDecision({required this.wireValue});
}

/// Outcome of a phone-triggered managed harness runtime install. Bounded on
/// purpose: the harness identity and any failure text stay off the wire.
enum AnalyticsHarnessInstallOutcome {
  completed(wireValue: "completed"),
  failed(wireValue: "failed");

  final String wireValue;
  AnalyticsHarnessInstallOutcome({required this.wireValue});
}

enum AnalyticsChangeState {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty");

  final String wireValue;
  AnalyticsChangeState({required this.wireValue});
}

@immutable
sealed class ProductAnalyticsEvent {
  const ProductAnalyticsEvent();

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

final class AnalyticsSchemaReadyEvent extends ProductAnalyticsEvent {
  const AnalyticsSchemaReadyEvent();

  @override
  String get wireName => "analytics_schema_ready";

  @override
  Map<String, String> get parameters => const {};
}

final class AnalyticsActivationReadyEvent extends ProductAnalyticsEvent {
  const AnalyticsActivationReadyEvent();

  @override
  String get wireName => "analytics_activation_ready";

  @override
  Map<String, String> get parameters => const {"activation_schema_version": "1"};
}

final class ProjectInventoryLoadedEvent extends ProductAnalyticsEvent {
  final AnalyticsInventoryState inventoryState;
  const ProjectInventoryLoadedEvent({required this.inventoryState});

  @override
  String get wireName => "project_inventory_loaded";

  @override
  Map<String, String> get parameters => {"inventory_state": inventoryState.wireValue};
}

final class SessionActivityViewedEvent extends ProductAnalyticsEvent {
  final AnalyticsActivityState activityState;
  const SessionActivityViewedEvent({required this.activityState});

  @override
  String get wireName => "session_activity_viewed";

  @override
  Map<String, String> get parameters => {"activity_state": activityState.wireValue};
}

final class SessionMessageSentEvent extends ProductAnalyticsEvent {
  final AnalyticsSubmission submission;
  const SessionMessageSentEvent({required this.submission});

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

final class SessionCreatedWithMessageEvent extends ProductAnalyticsEvent {
  final AnalyticsSubmission submission;
  final AnalyticsWorkspaceKind workspaceKind;
  const SessionCreatedWithMessageEvent({
    required this.submission,
    required this.workspaceKind,
  });

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

final class SessionCreationFailedEvent extends ProductAnalyticsEvent {
  final AnalyticsSessionCreationFailureReason failureReason;
  final AnalyticsWorkspaceKind workspaceKind;
  const SessionCreationFailedEvent({required this.failureReason, required this.workspaceKind});

  @override
  String get wireName => "session_creation_failed";

  @override
  Map<String, String> get parameters => {
    "failure_reason": failureReason.wireValue,
    "workspace_kind": workspaceKind.wireValue,
  };
}

final class VoiceTranscriptionCompletedEvent extends ProductAnalyticsEvent {
  const VoiceTranscriptionCompletedEvent();

  @override
  String get wireName => "voice_transcription_completed";

  @override
  Map<String, String> get parameters => const {};
}

final class SessionQuestionAnsweredEvent extends ProductAnalyticsEvent {
  const SessionQuestionAnsweredEvent();

  @override
  String get wireName => "session_question_answered";

  @override
  Map<String, String> get parameters => const {};
}

final class SessionQuestionRejectedEvent extends ProductAnalyticsEvent {
  const SessionQuestionRejectedEvent();

  @override
  String get wireName => "session_question_rejected";

  @override
  Map<String, String> get parameters => const {};
}

final class SessionPermissionAnsweredEvent extends ProductAnalyticsEvent {
  final AnalyticsPermissionDecision decision;
  const SessionPermissionAnsweredEvent({required this.decision});

  @override
  String get wireName => "session_permission_answered";

  @override
  Map<String, String> get parameters => {"decision": decision.wireValue};
}

final class SessionAbortSucceededEvent extends ProductAnalyticsEvent {
  const SessionAbortSucceededEvent();

  @override
  String get wireName => "session_abort_succeeded";

  @override
  Map<String, String> get parameters => const {};
}

/// Whether a phone-triggered harness runtime install actually succeeded — the
/// adoption signal for install-from-phone. Reported at the bridge's terminal
/// install event, not at the tap.
final class HarnessInstallFinishedEvent extends ProductAnalyticsEvent {
  final AnalyticsHarnessInstallOutcome outcome;
  const HarnessInstallFinishedEvent({required this.outcome});

  @override
  String get wireName => "harness_install_finished";

  @override
  Map<String, String> get parameters => {"outcome": outcome.wireValue};
}

final class SessionDiffViewedEvent extends ProductAnalyticsEvent {
  final AnalyticsChangeState changeState;
  const SessionDiffViewedEvent({required this.changeState});

  @override
  String get wireName => "session_diff_viewed";

  @override
  Map<String, String> get parameters => {"change_state": changeState.wireValue};
}

final class NeedHelpMenuOpenedEvent extends ProductAnalyticsEvent {
  final OnboardingSurface surface;
  const NeedHelpMenuOpenedEvent({required this.surface});

  @override
  String get wireName => "onboarding_need_help_opened";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class SupportLinkOpenedEvent extends ProductAnalyticsEvent {
  final SupportChannel channel;
  final OnboardingSurface surface;
  const SupportLinkOpenedEvent({required this.channel, required this.surface});

  @override
  String get wireName => "onboarding_support_link_opened";

  @override
  Map<String, String> get parameters => {"channel": channel.wireValue, "surface": surface.wireValue};
}

final class WhyBridgeOpenedEvent extends ProductAnalyticsEvent {
  final OnboardingSurface surface;
  const WhyBridgeOpenedEvent({required this.surface});

  @override
  String get wireName => "onboarding_why_bridge_opened";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class InstallCommandCopiedEvent extends ProductAnalyticsEvent {
  final BridgeInstallMethod method;
  final BridgeInstallOs os;
  final OnboardingSurface surface;
  const InstallCommandCopiedEvent({required this.method, required this.os, required this.surface});

  @override
  String get wireName => "bridge_install_command_copied";

  @override
  Map<String, String> get parameters => {
    "method": method.wireValue,
    "os": os.wireValue,
    "surface": surface.wireValue,
  };
}

final class InstallCommandSharedEvent extends ProductAnalyticsEvent {
  final BridgeInstallMethod method;
  final BridgeInstallOs os;
  final OnboardingSurface surface;
  const InstallCommandSharedEvent({required this.method, required this.os, required this.surface});

  @override
  String get wireName => "bridge_install_command_shared";

  @override
  Map<String, String> get parameters => {
    "method": method.wireValue,
    "os": os.wireValue,
    "surface": surface.wireValue,
  };
}

final class RunCommandCopiedEvent extends ProductAnalyticsEvent {
  final OnboardingSurface surface;
  const RunCommandCopiedEvent({required this.surface});

  @override
  String get wireName => "bridge_run_command_copied";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class RunCommandSharedEvent extends ProductAnalyticsEvent {
  final OnboardingSurface surface;
  const RunCommandSharedEvent({required this.surface});

  @override
  String get wireName => "bridge_run_command_shared";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class ProductScreenViewedEvent extends ProductAnalyticsEvent {
  final AnalyticsScreen screen;
  const ProductScreenViewedEvent({required this.screen});

  @override
  String get wireName => "product_screen_viewed";

  @override
  Map<String, String> get parameters => {"screen": screen.wireValue};
}

final class ProductAnalyticsEnvelope {
  final ProductAnalyticsEvent event;
  final DateTime occurredAtUtc;

  ProductAnalyticsEnvelope({required this.event, required DateTime occurredAtUtc})
    : occurredAtUtc = occurredAtUtc.toUtc();
}
