import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

enum SupportChannel({required final String wireValue}) {
  email(wireValue: "email"),
  discord(wireValue: "discord"),
  x(wireValue: "x"),
}

enum OnboardingSurface({required final String wireValue}) {
  connectSetup(wireValue: "connect_setup"),
  bridgeOffline(wireValue: "bridge_offline"),
}

enum BridgeInstallMethod({required final String wireValue}) {
  curl(wireValue: "curl"),
  powershell(wireValue: "powershell"),
  npm(wireValue: "npm"),
  bun(wireValue: "bun"),
}

enum BridgeInstallOs({required final String wireValue}) {
  unix(wireValue: "unix"),
  windows(wireValue: "windows"),
}

enum AnalyticsScreen({required final String wireValue}) {
  login(wireValue: "login"),
  settings(wireValue: "settings"),
  settingsDefaultInput(wireValue: "settings_default_input"),
  settingsNotifications(wireValue: "settings_notifications"),
  settingsProfile(wireValue: "settings_profile"),
  sessions(wireValue: "sessions"),
  newSession(wireValue: "new_session"),
  sessionDetail(wireValue: "session_detail"),
  sessionDiffs(wireValue: "session_diffs"),
  scheduledTasks(wireValue: "scheduled_tasks"),
  scheduledTaskDetail(wireValue: "scheduled_task_detail"),
}

enum AnalyticsInputMode({required final String wireValue}) {
  typed(wireValue: "typed"),
  voiceAssisted(wireValue: "voice_assisted"),
}

enum AnalyticsInventoryState({required final String wireValue}) {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty"),
}

enum AnalyticsActivityState({required final String wireValue}) {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty"),
}

enum AnalyticsSubmissionKind({required final String wireValue}) {
  text(wireValue: "text"),
  command(wireValue: "command"),
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

/// The harness that ran an accepted message, so reporting can see which
/// harnesses accounts actually use. A plugin ID no built-in harness claims
/// reports [other]; the raw ID never reaches the wire.
enum AnalyticsHarness({required final String wireValue}) {
  opencode(wireValue: "opencode"),
  codex(wireValue: "codex"),
  githubCopilot(wireValue: "github_copilot"),
  cursor(wireValue: "cursor"),
  claudeCode(wireValue: "claude_code"),
  hermesAgent(wireValue: "hermes_agent"),
  pi(wireValue: "pi"),
  ohMyPi(wireValue: "oh_my_pi"),
  deepseek(wireValue: "deepseek"),
  grokBuild(wireValue: "grok_build"),
  antigravity(wireValue: "antigravity"),
  other(wireValue: "other");

  static AnalyticsHarness fromPluginId({required String pluginId}) => switch (Harness.values.asNameMap()[pluginId]) {
    null => AnalyticsHarness.other,
    Harness.opencode => AnalyticsHarness.opencode,
    Harness.codex => AnalyticsHarness.codex,
    Harness.copilot => AnalyticsHarness.githubCopilot,
    Harness.cursor => AnalyticsHarness.cursor,
    Harness.claude => AnalyticsHarness.claudeCode,
    Harness.hermes => AnalyticsHarness.hermesAgent,
    Harness.pi => AnalyticsHarness.pi,
    Harness.omp => AnalyticsHarness.ohMyPi,
    Harness.deepseek => AnalyticsHarness.deepseek,
    Harness.grok => AnalyticsHarness.grokBuild,
    Harness.antigravity => AnalyticsHarness.antigravity,
  };
}

enum AnalyticsWorkspaceKind({required final String wireValue}) {
  project(wireValue: "project"),
  dedicatedWorktree(wireValue: "dedicated_worktree"),
  noProject(wireValue: "no_project"),
}

enum AnalyticsSessionCreationFailureReason({required final String wireValue}) {
  notAuthenticated(wireValue: "not_authenticated"),
  serverRejected(wireValue: "server_rejected"),
  networkDown(wireValue: "network_down"),
  badResponse(wireValue: "bad_response"),
  unknown(wireValue: "unknown"),
}

enum AnalyticsPermissionDecision({required final String wireValue}) {
  once(wireValue: "once"),
  always(wireValue: "always"),
  reject(wireValue: "reject"),
}

/// Outcome of a client-triggered managed harness runtime install. Bounded on
/// purpose: the harness identity and any failure text stay off the wire.
enum AnalyticsHarnessInstallOutcome({required final String wireValue}) {
  completed(wireValue: "completed"),
  failed(wireValue: "failed"),
}

enum AnalyticsChangeState({required final String wireValue}) {
  empty(wireValue: "empty"),
  nonEmpty(wireValue: "non_empty"),
}

/// What opened the Prompts screen.
enum AnalyticsPromptsEntry({required final String wireValue}) {
  sessionBar(wireValue: "session_bar"),
  pinch(wireValue: "pinch"),
}

enum AnalyticsFeedbackSource({required final String wireValue}) {
  automatic(wireValue: "automatic"),
  settings(wireValue: "settings"),
}

/// How one rating sheet ended. Both love values are a positive answer; they
/// differ in whether a store review was requested afterwards.
enum AnalyticsFeedbackAnswer({required final String wireValue}) {
  loveReviewRequested(wireValue: "love_review_requested"),
  loveNoReview(wireValue: "love_no_review"),
  couldBeBetter(wireValue: "could_be_better"),
  dismissed(wireValue: "dismissed"),
}

/// What private feedback carried: a message, typed or with a dictated
/// transcript inserted, else only ticked issues, else nothing.
enum AnalyticsFeedbackInput({required final String wireValue}) {
  typed(wireValue: "typed"),
  voiceAssisted(wireValue: "voice_assisted"),
  issuesOnly(wireValue: "issues_only"),
  empty(wireValue: "empty"),
}

/// Where a switch to another computer started.
enum ComputerSwitchSource({required final String wireValue}) {
  menu(wireValue: "menu"),
  offlineScreen(wireValue: "offline_screen"),
  settings(wireValue: "settings"),
  alert(wireValue: "alert"),
  notification(wireValue: "notification"),
  computersPage(wireValue: "computers_page"),
  commandPalette(wireValue: "command_palette"),
}

/// What the user did to a computer from the Computers page.
enum ComputerManageAction({required final String wireValue}) {
  renamed(wireValue: "renamed"),
  removed(wireValue: "removed"),
}

/// Where the CEO call invitation was shown or acted on.
enum FounderCallSurface({required final String wireValue}) {
  computerConnectedSheet(wireValue: "computer_connected_sheet"),
  settings(wireValue: "settings"),
}

/// What became of a dictation's words.
enum AnalyticsVoiceFinish({required final String wireValue}) {
  sent(wireValue: "sent"),
  edited(wireValue: "edited"),
  cutOff(wireValue: "cut_off"),
}

/// How a dictation actually ran, so a fallback reports [afterRecording].
enum AnalyticsVoiceMode({required final String wireValue}) {
  live(wireValue: "live"),
  afterRecording(wireValue: "after_recording"),

  /// The device's own engine, whether or not the words showed.
  onDevice(wireValue: "on_device"),
}

/// How many saved files an accepted prompt carried.
enum AnalyticsFileCountBucket({required final String wireValue}) {
  one(wireValue: "1"),
  twoToFour(wireValue: "2_4"),
  fivePlus(wireValue: "5_plus"),
}

/// How a prompt's saved files were added; [mixed] means more than one way.
enum AnalyticsFileSource({required final String wireValue}) {
  picker(wireValue: "picker"),
  drop(wireValue: "drop"),
  paste(wireValue: "paste"),
  mixed(wireValue: "mixed"),
}

/// How the bridge answered one fork of a session.
enum AnalyticsSessionForkOutcome({required final String wireValue}) {
  /// The bridge made the fork.
  succeeded(wireValue: "succeeded"),

  /// The harness cannot fork at that point, or no longer has the session.
  branchPointUnavailable(wireValue: "branch_point_unavailable"),

  /// The bridge refused the fork otherwise: nothing to fork yet, a removed
  /// worktree it could not bring back, or a reason this app doesn't know.
  refused(wireValue: "refused"),

  /// The request failed or timed out, so the fork may or may not exist.
  failed(wireValue: "failed"),
}

/// How the bridge answered one edit and resend of an earlier message.
enum AnalyticsMessageEditOutcome({required final String wireValue}) {
  /// The bridge removed the message and what followed it, and sent the edit.
  succeeded(wireValue: "succeeded"),

  /// The session was running a turn.
  refusedBusy(wireValue: "refused_busy"),

  /// The harness cannot cut the conversation at the message, such as before
  /// Claude Code's latest compaction.
  branchPointUnavailable(wireValue: "branch_point_unavailable"),

  /// The bridge refused the edit otherwise: the selected options changed, the
  /// harness refused the prompt, or a reason this app doesn't know.
  refused(wireValue: "refused"),

  /// The request failed or timed out, so the edit may or may not have run.
  failed(wireValue: "failed"),
}

/// How the bridge answered one send of a session into another.
enum AnalyticsSessionSendOutcome({required final String wireValue}) {
  /// The target accepted the handoff with the source's summary.
  sent(wireValue: "sent"),

  /// The source was running, or waiting for the user's answer, so nothing
  /// was sent.
  refusedBusy(wireValue: "refused_busy"),

  /// The bridge did not send for another reason: the summary or transcript
  /// failed, a harness no longer offers the session's options, the target
  /// refused, or a reason this app doesn't know.
  refusedOther(wireValue: "refused_other"),

  /// The request failed before the bridge could send, or with an answer that
  /// is not a refusal.
  failed(wireValue: "failed"),

  /// The bridge predates sending sessions.
  unsupported(wireValue: "unsupported"),

  /// The answer never arrived, so the send may or may not have finished.
  unconfirmed(wireValue: "unconfirmed"),
}

/// How one side question ended.
enum AnalyticsSideQuestionOutcome({required final String wireValue}) {
  /// The bridge stored an answer.
  answered(wireValue: "answered"),

  /// The model gave no usable answer.
  noAnswer(wireValue: "no_answer"),

  /// The bridge refused before the model answered: the harness can't, the
  /// session has no turn yet, the question was too long, or a reason this app
  /// doesn't know.
  unavailable(wireValue: "unavailable"),

  /// The request failed or timed out, or the bridge sent a response this app
  /// doesn't know.
  failed(wireValue: "failed"),
}

/// Whether a saved scheduled task was new or an edit.
enum AnalyticsScheduledTaskAction({required final String wireValue}) {
  created(wireValue: "created"),
  edited(wireValue: "edited"),
}

/// A scheduled task's repeat preset.
enum AnalyticsScheduledTaskRepeat({required final String wireValue}) {
  once(wireValue: "once"),
  daily(wireValue: "daily"),
  weekdays(wireValue: "weekdays"),
  weekly(wireValue: "weekly"),
  everyHours(wireValue: "every_hours"),
}

enum AnalyticsScheduledTaskRunMode({required final String wireValue}) {
  newSession(wireValue: "new_session"),
  sameSession(wireValue: "same_session"),
}

enum AnalyticsScheduledTaskApprovalMode({required final String wireValue}) {
  ask(wireValue: "ask"),
  approveAll(wireValue: "approve_all"),
}

enum AnalyticsScheduledTaskMissedRunPolicy({required final String wireValue}) {
  runWhenBack(wireValue: "run_when_back"),
  waitForNext(wireValue: "wait_for_next"),
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
    required AnalyticsHarness harness,
  }) = SessionMessageSentEvent;
  const factory sessionCreatedWithMessage({
    required AnalyticsSubmission submission,
    required AnalyticsWorkspaceKind workspaceKind,
    required AnalyticsHarness harness,
  }) = SessionCreatedWithMessageEvent;
  const factory promptFilesSent({
    required AnalyticsFileCountBucket fileCount,
    required AnalyticsFileSource source,
  }) = PromptFilesSentEvent;
  const factory sessionCreationFailed({
    required AnalyticsSessionCreationFailureReason failureReason,
    required AnalyticsWorkspaceKind workspaceKind,
  }) = SessionCreationFailedEvent;
  const factory voiceTranscriptionCompleted({
    required AnalyticsVoiceFinish finish,
    required AnalyticsVoiceMode mode,
  }) = VoiceTranscriptionCompletedEvent;
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
  const factory transcriptPromptsOpened({
    required AnalyticsPromptsEntry entry,
  }) = TranscriptPromptsOpenedEvent;
  const factory feedbackPromptAnswered({
    required AnalyticsFeedbackAnswer answer,
    required AnalyticsFeedbackSource source,
  }) = FeedbackPromptAnsweredEvent;
  const factory privateFeedbackSent({
    required AnalyticsFeedbackInput input,
    required AnalyticsFeedbackSource source,
  }) = PrivateFeedbackSentEvent;
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
  const factory desktopLinkCopied({required OnboardingSurface surface}) = DesktopLinkCopiedEvent;
  const factory desktopLinkShared({required OnboardingSurface surface}) = DesktopLinkSharedEvent;
  const factory screenViewed({required AnalyticsScreen screen}) = ProductScreenViewedEvent;
  const factory computerSwitched({
    required ComputerSwitchSource source,
    required bool targetOnline,
  }) = ComputerSwitchedEvent;
  const factory computerManaged({required ComputerManageAction action}) = ComputerManagedEvent;
  const factory sessionPinChanged({required bool pinned}) = SessionPinChangedEvent;
  const factory founderCallShown({required FounderCallSurface surface}) = FounderCallShownEvent;
  const factory founderCallLinkOpened({required FounderCallSurface surface}) = FounderCallLinkOpenedEvent;
  const factory founderCallDeclined({required FounderCallSurface surface}) = FounderCallDeclinedEvent;
  const factory sideQuestionAsked({
    required AnalyticsHarness harness,
    required AnalyticsSideQuestionOutcome outcome,
  }) = SideQuestionAskedEvent;
  const factory scheduledTaskSaved({
    required AnalyticsScheduledTaskAction action,
    required AnalyticsScheduledTaskRepeat repeat,
    required AnalyticsScheduledTaskRunMode runMode,
    required AnalyticsScheduledTaskApprovalMode approvalMode,
    required AnalyticsScheduledTaskMissedRunPolicy? missedRunPolicy,
    required bool? autoCompact,
  }) = ScheduledTaskSavedEvent;
  const factory sessionMessageEdited({
    required AnalyticsHarness harness,
    required AnalyticsMessageEditOutcome outcome,
  }) = SessionMessageEditedEvent;
  const factory sessionForked({
    required AnalyticsHarness harness,
    required AnalyticsSessionForkOutcome outcome,
  }) = SessionForkedEvent;
  const factory sessionSentToSession({
    required AnalyticsHarness harness,
    required AnalyticsSessionSendOutcome outcome,
  }) = SessionSentToSessionEvent;

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

final class const SessionMessageSentEvent({
  required final AnalyticsSubmission submission,
  required final AnalyticsHarness harness,
}) extends ProductAnalyticsEvent {
  AnalyticsSubmissionKind get submissionKind => submission.kind;
  AnalyticsInputMode get inputMode => submission.inputMode;

  @override
  String get wireName => "session_message_sent";

  @override
  Map<String, String> get parameters => {
    "submission_kind": submissionKind.wireValue,
    "input_mode": inputMode.wireValue,
    "harness": harness.wireValue,
  };
}

final class const SessionCreatedWithMessageEvent({
  required final AnalyticsSubmission submission,
  required final AnalyticsWorkspaceKind workspaceKind,
  required final AnalyticsHarness harness,
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
    "harness": harness.wireValue,
  };
}

/// A prompt carrying at least one file the bridge saves was accepted, reported
/// beside its `session_message_sent` or `session_created_with_message`. Inline
/// images don't count, and the files' names, types, sizes and paths stay off
/// the wire.
final class const PromptFilesSentEvent({
  required final AnalyticsFileCountBucket fileCount,
  required final AnalyticsFileSource source,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "prompt_files_sent";

  @override
  Map<String, String> get parameters => {"file_count": fileCount.wireValue, "source": source.wireValue};
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

final class const VoiceTranscriptionCompletedEvent({
  required final AnalyticsVoiceFinish finish,
  required final AnalyticsVoiceMode mode,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "voice_transcription_completed";

  @override
  Map<String, String> get parameters => {"finish": finish.wireValue, "mode": mode.wireValue};
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

/// Whether a client-triggered harness runtime install actually succeeded — the
/// managed-install adoption signal. Reported at the bridge's terminal install
/// event, not at the tap.
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

/// The Prompts screen opened: reported once per opening, with what opened it.
final class const TranscriptPromptsOpenedEvent({required final AnalyticsPromptsEntry entry})
    extends ProductAnalyticsEvent {
  @override
  String get wireName => "transcript_prompts_opened";

  @override
  Map<String, String> get parameters => {"entry": entry.wireValue};
}

/// A rating sheet closed: reported once per presentation, after its route has
/// closed, with the answer it ended with.
final class const FeedbackPromptAnsweredEvent({
  required final AnalyticsFeedbackAnswer answer,
  required final AnalyticsFeedbackSource source,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "feedback_prompt_answered";

  @override
  Map<String, String> get parameters => {"answer": answer.wireValue, "source": source.wireValue};
}

/// The auth server accepted private feedback. Its text and issues stay off
/// the wire.
final class const PrivateFeedbackSentEvent({
  required final AnalyticsFeedbackInput input,
  required final AnalyticsFeedbackSource source,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "private_feedback_sent";

  @override
  Map<String, String> get parameters => {"input": input.wireValue, "source": source.wireValue};
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

/// The Sesori Desktop download link reached the clipboard from an onboarding
/// surface.
final class const DesktopLinkCopiedEvent({required final OnboardingSurface surface}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "desktop_link_copied";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

/// The native share sheet confirmed handing off the Sesori Desktop download
/// link from an onboarding surface.
final class const DesktopLinkSharedEvent({required final OnboardingSurface surface}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "desktop_link_shared";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class const ProductScreenViewedEvent({required final AnalyticsScreen screen}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "product_screen_viewed";

  @override
  Map<String, String> get parameters => {"screen": screen.wireValue};
}

/// The app switched to another computer. Which computers were involved stays
/// off the wire; only where the switch started and whether the computer picked
/// was online.
final class const ComputerSwitchedEvent({
  required final ComputerSwitchSource source,
  required final bool targetOnline,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "computer_switched";

  @override
  Map<String, String> get parameters => {"source": source.wireValue, "target_online": targetOnline.toString()};
}

/// The user renamed or removed a computer. Which computer, and any name, stays
/// off the wire.
final class const ComputerManagedEvent({required final ComputerManageAction action}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "computer_managed";

  @override
  Map<String, String> get parameters => {"action": action.wireValue};
}

/// The user pinned or unpinned a session, once the bridge confirmed it. Which
/// session, and its title, stays off the wire.
final class const SessionPinChangedEvent({required final bool pinned}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_pin_changed";

  @override
  Map<String, String> get parameters => {"pinned": pinned.toString()};
}

/// The CEO call invitation appeared by itself; the A/B test's activation event.
final class const FounderCallShownEvent({required final FounderCallSurface surface}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "founder_call_shown";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

/// The booking page opened; the A/B test's goal event.
final class const FounderCallLinkOpenedEvent({required final FounderCallSurface surface})
    extends ProductAnalyticsEvent {
  @override
  String get wireName => "founder_call_link_opened";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

/// The invitation closed without opening the booking page.
final class const FounderCallDeclinedEvent({required final FounderCallSurface surface}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "founder_call_declined";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

/// A side question got its result from the bridge. The question, the answer,
/// the session and the side chat stay off the wire.
final class const SideQuestionAskedEvent({
  required final AnalyticsHarness harness,
  required final AnalyticsSideQuestionOutcome outcome,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "side_question_asked";

  @override
  Map<String, String> get parameters => {"harness": harness.wireValue, "outcome": outcome.wireValue};
}

/// The bridge accepted a new or edited scheduled task. The prompt, name,
/// project, harness and times stay off the wire.
final class const ScheduledTaskSavedEvent({
  required final AnalyticsScheduledTaskAction action,
  required final AnalyticsScheduledTaskRepeat repeat,
  required final AnalyticsScheduledTaskRunMode runMode,
  required final AnalyticsScheduledTaskApprovalMode approvalMode,

  /// Null for a one-off task, which runs when the bridge is back whatever
  /// its policy.
  required final AnalyticsScheduledTaskMissedRunPolicy? missedRunPolicy,

  /// Null for a new-session task, which has nothing to compact.
  required final bool? autoCompact,
}) extends ProductAnalyticsEvent {
  /// The event for [definition], or null when it holds a part from a newer
  /// peer, which this app never saves.
  static ScheduledTaskSavedEvent? of({
    required AnalyticsScheduledTaskAction action,
    required ScheduledTaskDefinition definition,
  }) {
    final repeat = switch (definition.schedule) {
      TaskScheduleOnce() => AnalyticsScheduledTaskRepeat.once,
      TaskScheduleDaily() => AnalyticsScheduledTaskRepeat.daily,
      TaskScheduleWeekdays() => AnalyticsScheduledTaskRepeat.weekdays,
      TaskScheduleWeekly() => AnalyticsScheduledTaskRepeat.weekly,
      TaskScheduleEveryHours() => AnalyticsScheduledTaskRepeat.everyHours,
      TaskScheduleUnknown() => null,
    };
    final approvalMode = switch (definition.approvalMode) {
      TaskApprovalMode.ask => AnalyticsScheduledTaskApprovalMode.ask,
      TaskApprovalMode.approveAll => AnalyticsScheduledTaskApprovalMode.approveAll,
      TaskApprovalMode.unknown => null,
    };
    final missedRunPolicy = switch (definition.missedRunPolicy) {
      TaskMissedRunPolicy.runWhenBack => AnalyticsScheduledTaskMissedRunPolicy.runWhenBack,
      TaskMissedRunPolicy.waitForNext => AnalyticsScheduledTaskMissedRunPolicy.waitForNext,
      TaskMissedRunPolicy.unknown => null,
    };
    final (runMode, autoCompact) = switch (definition.runMode) {
      TaskRunModeNewSession() => (AnalyticsScheduledTaskRunMode.newSession, null),
      TaskRunModeSameSession(:final autoCompact) => (AnalyticsScheduledTaskRunMode.sameSession, autoCompact),
      TaskRunModeUnknown() => (null, null),
    };
    if (repeat == null || approvalMode == null || missedRunPolicy == null || runMode == null) return null;
    return ScheduledTaskSavedEvent(
      action: action,
      repeat: repeat,
      runMode: runMode,
      approvalMode: approvalMode,
      missedRunPolicy: repeat == AnalyticsScheduledTaskRepeat.once ? null : missedRunPolicy,
      autoCompact: autoCompact,
    );
  }

  @override
  String get wireName => "scheduled_task_saved";

  @override
  Map<String, String> get parameters => {
    "action": action.wireValue,
    "repeat_kind": repeat.wireValue,
    "run_mode": runMode.wireValue,
    "approval_mode": approvalMode.wireValue,
    if (missedRunPolicy case final missedRunPolicy?) "missed_run_policy": missedRunPolicy.wireValue,
    if (autoCompact case final autoCompact?) "auto_compact": autoCompact.toString(),
  };
}

/// The bridge answered an edit and resend of an earlier message. The text,
/// the attachments, the session and the message stay off the wire.
final class const SessionMessageEditedEvent({
  required final AnalyticsHarness harness,
  required final AnalyticsMessageEditOutcome outcome,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_message_edited";

  @override
  Map<String, String> get parameters => {"harness": harness.wireValue, "outcome": outcome.wireValue};
}

/// The bridge answered a fork of a session. The session, its title and where
/// it was cut stay off the wire.
final class const SessionForkedEvent({
  required final AnalyticsHarness harness,
  required final AnalyticsSessionForkOutcome outcome,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_forked";

  @override
  Map<String, String> get parameters => {"harness": harness.wireValue, "outcome": outcome.wireValue};
}

/// The bridge answered a send of one session into another. [harness] is the
/// source's. The sessions, their titles and the summary stay off the wire.
final class const SessionSentToSessionEvent({
  required final AnalyticsHarness harness,
  required final AnalyticsSessionSendOutcome outcome,
}) extends ProductAnalyticsEvent {
  @override
  String get wireName => "session_sent_to_session";

  @override
  Map<String, String> get parameters => {"harness": harness.wireValue, "outcome": outcome.wireValue};
}

final class ProductAnalyticsEnvelope({required final ProductAnalyticsEvent event, required DateTime occurredAtUtc}) {
  final DateTime occurredAtUtc = occurredAtUtc.toUtc();
}
