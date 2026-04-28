// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sesori Mobile';

  @override
  String connectErrorNonSuccessCode(int errorCode) {
    return 'Server returned $errorCode';
  }

  @override
  String connectErrorNonSuccessCodeWithBody(int errorCode, String body) {
    return 'Server returned $errorCode: $body';
  }

  @override
  String connectErrorConnectionFailed(String detail) {
    return 'Connection failed: $detail';
  }

  @override
  String get connectErrorUnexpectedFormat => 'Unexpected response format';

  @override
  String get connectErrorUnknown => 'An unknown error occurred';

  @override
  String get apiErrorNotAuthenticated => 'Not authenticated — check your connection';

  @override
  String get projectListTitle => 'Projects';

  @override
  String get projectListEmpty => 'No projects found';

  @override
  String projectListUpdated(String timestamp) {
    return 'Updated $timestamp';
  }

  @override
  String get projectListDefaultName => 'Default Project';

  @override
  String get projectListRefreshSuccess => 'Projects updated';

  @override
  String get projectListRefreshFailed => 'Could not refresh projects';

  @override
  String get projectListErrorTitle => 'Failed to load projects';

  @override
  String get projectListRetry => 'Retry';

  @override
  String projectListActiveSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active sessions',
      one: '1 active session',
    );
    return '$_temp0';
  }

  @override
  String get connectionLostTitle => 'Connection Lost';

  @override
  String get connectionLostReconnect => 'Reconnect';

  @override
  String get connectionLostDisconnect => 'Disconnect';

  @override
  String get relayConnectionLost => 'Bridge went offline';

  @override
  String get relayReconnecting => 'Reconnecting to bridge...';

  @override
  String get bridgeOfflineTitle => 'Bridge Offline';

  @override
  String get bridgeOfflineMessage => 'Start sesori-bridge on your laptop';

  @override
  String get notificationSettingsTitle => 'Notification Settings';

  @override
  String get notificationCategoryAiInteraction => 'AI Interactions';

  @override
  String get notificationCategoryAiInteractionDescription =>
      'Questions and permission requests from active AI sessions';

  @override
  String get notificationCategorySessionMessage => 'Session Messages';

  @override
  String get notificationCategorySessionMessageDescription => 'New assistant messages from running sessions';

  @override
  String get notificationCategoryConnectionStatus => 'Connection Status';

  @override
  String get notificationCategoryConnectionStatusDescription => 'Bridge online and offline status changes';

  @override
  String get notificationCategorySystemUpdate => 'System Updates';

  @override
  String get notificationCategorySystemUpdateDescription => 'App and bridge updates or maintenance notices';

  @override
  String get sessionListTitle => 'Sessions';

  @override
  String sessionListTitleWithName(String name) {
    return '$name — Sessions';
  }

  @override
  String get sessionListEmpty => 'No sessions found';

  @override
  String get sessionListUntitled => 'Untitled session';

  @override
  String sessionListUpdated(String timestamp) {
    return 'Updated $timestamp';
  }

  @override
  String sessionListFilesChanged(int count) {
    return '$count files changed';
  }

  @override
  String get sessionListRefreshSuccess => 'Sessions updated';

  @override
  String get sessionListRefreshFailed => 'Could not refresh sessions';

  @override
  String get sessionListErrorTitle => 'Failed to load sessions';

  @override
  String get sessionListRetry => 'Retry';

  @override
  String get sessionListNewSession => 'New session';

  @override
  String get sessionDetailTitle => 'Session';

  @override
  String get sessionDetailEmpty => 'No messages yet';

  @override
  String get sessionDetailErrorTitle => 'Failed to load messages';

  @override
  String get sessionDetailRetry => 'Retry';

  @override
  String get sessionDetailPromptHint => 'Ask anything...';

  @override
  String get sessionDetailCommandArgumentsHint => 'Optional arguments';

  @override
  String get sessionDetailCommandPickerTitle => 'Slash commands';

  @override
  String get sessionDetailCommandSearch => 'Search commands...';

  @override
  String get sessionDetailNoCommands => 'No slash commands are available for this project.';

  @override
  String get sessionDetailSend => 'Send';

  @override
  String get sessionDetailAbort => 'Stop';

  @override
  String get sessionDetailThinking => 'Thinking...';

  @override
  String get sessionDetailThought => 'Thought';

  @override
  String get sessionDetailToolUnknown => 'Tool';

  @override
  String get sessionDetailToolPending => 'Pending';

  @override
  String get sessionDetailToolRunning => 'Running';

  @override
  String get sessionDetailToolCompleted => 'Done';

  @override
  String get sessionDetailToolError => 'Failed';

  @override
  String get sessionDetailFollowOutput => 'Follow';

  @override
  String get sessionDetailJumpToLatest => 'Jump to latest';

  @override
  String get questionModalTitle => 'Question';

  @override
  String get questionModalReject => 'Reject';

  @override
  String get questionModalCustomHint => 'Type your own answer';

  @override
  String get questionModalSubmit => 'Submit';

  @override
  String get questionModalNext => 'Next';

  @override
  String questionModalStepIndicator(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get questionBannerSingle => '1 pending question';

  @override
  String questionBannerMultiple(int count) {
    return '$count pending questions';
  }

  @override
  String get sessionDetailSubtaskUnnamed => 'Background task';

  @override
  String get sessionDetailQueuedMessage => 'Queued';

  @override
  String get sessionDetailQueuedCommand => 'Queued command';

  @override
  String get sessionDetailCancelQueued => 'Cancel';

  @override
  String get sessionDetailPickerAgent => 'Agent';

  @override
  String get sessionDetailPickerModel => 'Model';

  @override
  String get sessionDetailPickerVariant => 'Variant';

  @override
  String get sessionDetailVariantDefault => 'Default';

  @override
  String get sessionDetailSelectModel => 'Select Model';

  @override
  String get sessionDetailModelSearch => 'Search models...';

  @override
  String backgroundTasksRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tasks Running',
      one: '1 Task Running',
    );
    return '$_temp0';
  }

  @override
  String get backgroundTasksCompleted => 'All tasks completed';

  @override
  String get backgroundTasksTitle => 'Background Tasks';

  @override
  String get backgroundTaskStatusIdle => 'Completed';

  @override
  String get backgroundTaskStatusBusy => 'Running';

  @override
  String get backgroundTaskStatusRetry => 'Retrying';

  @override
  String backgroundTasksShowCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count completed tasks',
      one: 'Show 1 completed task',
    );
    return '$_temp0';
  }

  @override
  String get backgroundTasksHideCompleted => 'Hide completed';

  @override
  String get sessionListToggleArchived => 'Show archived';

  @override
  String get sessionListEmptyArchived => 'No archived sessions';

  @override
  String get sessionListArchive => 'Archive';

  @override
  String get sessionListUnarchive => 'Unarchive';

  @override
  String get sessionListDelete => 'Delete';

  @override
  String get sessionListArchived => 'Session archived';

  @override
  String get sessionListUnarchived => 'Session unarchived';

  @override
  String get sessionListDeleted => 'Session deleted';

  @override
  String get sessionListUndo => 'Undo';

  @override
  String get sessionListDeleteConfirmTitle => 'Delete session?';

  @override
  String get sessionListDeleteConfirmMessage =>
      'This will permanently remove the session and all its messages. This cannot be undone.';

  @override
  String get sessionListDeleteConfirmAction => 'Delete';

  @override
  String get sessionListDeleteConfirmCancel => 'Cancel';

  @override
  String get loginTitle => 'Sign In';

  @override
  String get loginSubtitle => 'Sign in to connect to your server';

  @override
  String get loginWithGithub => 'Sign in with GitHub';

  @override
  String get loginWithGoogle => 'Sign in with Google';

  @override
  String get continueWithEmail => 'Continue with Email';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get emailInvalid => 'Please enter a valid email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get signIn => 'Sign In';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get loginError => 'Sign in failed. Please try again.';

  @override
  String get loginAuthenticating => 'Signing in...';

  @override
  String get loginAwaitingCallback => 'Waiting for authorization...';

  @override
  String get loginBrowserOpenFailed => 'Could not open browser';

  @override
  String get loginCallbackTimeout => 'Authorization timed out. Please try again.';

  @override
  String get loginCallbackMissingParams => 'Invalid authorization callback. Please try again.';

  @override
  String get loginStateMismatch => 'Authorization state mismatch. Please try again.';

  @override
  String get loginPkceStateMissing => 'Login session expired. Please start again.';

  @override
  String get sessionListRunning => 'Running';

  @override
  String get sessionListAwaitingInput => 'Awaiting input';

  @override
  String sessionListBackgroundTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count background tasks',
      one: '1 background task',
    );
    return '$_temp0';
  }

  @override
  String get sessionListStaleProjectTitle => 'Project directory not found';

  @override
  String get sessionListStaleProjectMessage =>
      'The directory for this project no longer exists or has been renamed. Sessions cannot be loaded because the server can no longer resolve this project.';

  @override
  String get sessionListStaleProjectBack => 'Go back';

  @override
  String get voiceRecord => 'Record voice';

  @override
  String get voiceStopRecording => 'Stop recording';

  @override
  String get voiceCancelTranscription => 'Cancel transcription';

  @override
  String get voiceTranscribing => 'Transcribing...';

  @override
  String get voiceRecording => 'Recording...';

  @override
  String get voiceErrorPermission => 'Microphone permission is required for voice input';

  @override
  String get voiceErrorRecording => 'Recording failed. Please try again.';

  @override
  String get voiceErrorTranscription => 'Transcription failed. Please try again.';

  @override
  String get voiceErrorNetwork => 'Could not reach the server. Check your connection.';

  @override
  String get voiceErrorNotAuthenticated => 'Sign in to use voice input';

  @override
  String get voiceRecordingLimitReached => 'Recording limit reached (15 minutes)';

  @override
  String get addProject => 'Add Project';

  @override
  String get projectNameHint => 'Project name';

  @override
  String get createProjectButton => 'Create';

  @override
  String get openAsProject => 'Open as Project';

  @override
  String get emptyDirectory => 'This directory is empty';

  @override
  String get fetchDirectoryFailed => 'Could not load directory contents';

  @override
  String get fetchDirectoryRetry => 'Retry';

  @override
  String get fetchDirectoryGoBack => 'Go Back';

  @override
  String get gitRepoBadge => 'git';

  @override
  String get projectHidden => 'Project hidden';

  @override
  String get hideProject => 'Hide Project';

  @override
  String get noProjects => 'No projects';

  @override
  String get addProjectPrompt => 'Add a project to get started';

  @override
  String get creatingProject => 'Creating project...';

  @override
  String get discoveringProject => 'Discovering project...';

  @override
  String get projectCreated => 'Project created';

  @override
  String get projectDiscovered => 'Project discovered';

  @override
  String get projectCreateFailed => 'Failed to create project';

  @override
  String get projectDiscoverFailed => 'Failed to discover project';

  @override
  String get questionReplyFailed => 'Failed to send answer. Please try again.';

  @override
  String get questionRejectFailed => 'Failed to reject question. Please try again.';

  @override
  String get permissionReplyFailed => 'Failed to send permission response. Please try again.';

  @override
  String get permissionBannerSingle => '1 permission request pending';

  @override
  String permissionBannerMultiple(int count) {
    return '$count permission requests pending';
  }

  @override
  String get rename => 'Rename';

  @override
  String get renameSessionTitle => 'Rename Session';

  @override
  String get renameProjectTitle => 'Rename Project';

  @override
  String get renameSessionHint => 'Session title';

  @override
  String get renameProjectHint => 'Project name';

  @override
  String get renameSave => 'Save';

  @override
  String get renameSessionSuccess => 'Session renamed';

  @override
  String get renameProjectSuccess => 'Project renamed';

  @override
  String get renameSessionFailed => 'Failed to rename session';

  @override
  String get renameProjectFailed => 'Failed to rename project';

  @override
  String get newSessionDedicatedWorktree => 'Dedicated worktree';

  @override
  String get newSessionDedicatedWorktreeDescription => 'Creates a dedicated git worktree and branch for this session';

  @override
  String get sessionListDeleteWorktreeCheckbox => 'Delete worktree';

  @override
  String get sessionListDeleteBranchCheckbox => 'Delete branch';

  @override
  String get sessionListArchiveConfirmTitle => 'Archive session?';

  @override
  String get sessionListArchiveConfirmMessage => 'This session will be archived and hidden from the active list.';

  @override
  String get sessionListArchiveConfirmAction => 'Archive';

  @override
  String get sessionListForceDeleteTitle => 'Force delete?';

  @override
  String get sessionListForceArchiveTitle => 'Force archive?';

  @override
  String get sessionListForceMessage => 'The following issues were found:';

  @override
  String get sessionListForceDeleteAction => 'Force Delete';

  @override
  String get sessionListForceArchiveAction => 'Force Archive';

  @override
  String get sessionListCleanupIssueUnstagedChanges => 'Worktree has unstaged changes';

  @override
  String get sessionListCleanupIssueSharedWorktree => 'Another active session uses this worktree';

  @override
  String sessionListCleanupIssueBranchMismatch(String actual, String expected) {
    return 'Worktree is on branch \'$actual\' instead of expected \'$expected\'';
  }

  @override
  String get sessionListDeleteFailed => 'Failed to delete session';

  @override
  String get sessionListArchiveFailed => 'Failed to archive session';

  @override
  String prLabel(int number) {
    return 'PR #$number';
  }

  @override
  String get prStateOpen => 'Open';

  @override
  String get prStateMerged => 'Merged';

  @override
  String get prStateClosed => 'Closed';

  @override
  String get prReviewApproved => 'Approved';

  @override
  String get prReviewChangesRequested => 'Changes requested';

  @override
  String get prReviewRequired => 'Review required';

  @override
  String get prChecksSuccess => 'Checks passing';

  @override
  String get prChecksFailing => 'Checks failing';

  @override
  String get prChecksPending => 'Checks pending';

  @override
  String get prMergeable => 'Ready to merge';

  @override
  String get prConflicting => 'Has merge conflicts';
}
