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
  String get connectErrorUnexpectedFormat => 'Unexpected response format';

  @override
  String get connectErrorUnknown => 'An unknown error occurred';

  @override
  String get apiErrorNotAuthenticated => 'Not authenticated — check your connection';

  @override
  String get apiErrorServerRejected => 'The server returned an error. Please try again.';

  @override
  String get apiErrorNetworkDown => 'Connection failed — check your network and try again.';

  @override
  String get projectListTitle => 'Projects';

  @override
  String get projectListLoadingSemantics => 'Loading projects';

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
  String projectListRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count running',
      one: 'Running',
    );
    return '$_temp0';
  }

  @override
  String get projectListNewActivity => 'New activity';

  @override
  String get projectsEmptyConnected => 'Connected';

  @override
  String get projectsEmptyMessage => 'You don\'t have any projects created or opened yet.';

  @override
  String get projectsEmptyAddProject => 'Add a new project to get started';

  @override
  String get projectsOnboardingPcStatusWhy => 'Why is this needed?';

  @override
  String get projectsOnboardingNeedHelp => 'Need help?';

  @override
  String get projectsOnboardingNeedHelpEmail => 'Email';

  @override
  String get projectsOnboardingNeedHelpDiscord => 'Discord';

  @override
  String get projectsOnboardingNeedHelpX => 'DM on X';

  @override
  String get projectsOnboardingInstallUnixLabel => 'macOS, Linux, WSL';

  @override
  String get projectsOnboardingInstallUnixMethod => 'curl';

  @override
  String get projectsOnboardingInstallWindowsLabel => 'Windows PowerShell';

  @override
  String get projectsOnboardingInstallWindowsMethod => 'native';

  @override
  String get projectsOnboardingInstallMethodNpm => 'npm';

  @override
  String get projectsOnboardingInstallMethodBun => 'bun';

  @override
  String get projectsOnboardingCommandCopied => 'Command copied to clipboard';

  @override
  String get projectsOnboardingCopyCommand => 'Copy command';

  @override
  String get projectsOnboardingShareCommand => 'Share command';

  @override
  String get projectsOnboardingWaitingForBridge => 'Waiting for the bridge...';

  @override
  String get projectsOnboardingRunOnComputer => 'Next, run on your computer:';

  @override
  String get projectsOnboardingInstallStepTitle => 'Install the bridge';

  @override
  String get projectsOnboardingInstallStepInfo => 'This adds the Sesori bridge command to your machine.';

  @override
  String get projectsOnboardingStartStepTitle => 'Start the bridge';

  @override
  String get projectsOnboardingStartStepInfo => 'Leave it running while you use Sesori from your phone.';

  @override
  String get projectsOnboardingStepInfoSemantics => 'More information';

  @override
  String get projectsBridgeOfflineDisconnected => 'Disconnected';

  @override
  String get projectsBridgeOfflineReconnect => 'Reconnect';

  @override
  String get projectsBridgeOfflineInstallCommands => 'Install commands';

  @override
  String get projectsBridgeOfflineStartBridge => 'Start your bridge';

  @override
  String get projectsBridgeOfflineStartBridgeInfo => 'Leave it running while you use Sesori from your phone.';

  @override
  String get connectionLostTitle => 'Connection Lost';

  @override
  String get connectionLostReconnect => 'Reconnect';

  @override
  String get bridgeDisconnectedTitle => 'Bridge disconnected';

  @override
  String get settingsTitle => 'Settings';

  @override
  String settingsAccountSignedInWith(String provider) {
    return 'Signed in with $provider';
  }

  @override
  String get settingsLogout => 'Log Out';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsNotificationsTitle => 'Notifications';

  @override
  String get settingsProfileTitle => 'Profile';

  @override
  String get settingsClose => 'Close settings';

  @override
  String get pluginSettingsTitle => 'Plugins';

  @override
  String get pluginSettingsDescription =>
      'Manage which coding tools Sesori can use and how long they stay running while idle.';

  @override
  String get pluginSettingsLoading => 'Loading coding tools';

  @override
  String get pluginSettingsUnsupportedTitle => 'Update your bridge to manage coding tools';

  @override
  String get pluginSettingsUnsupportedDescription =>
      'This older bridge still supports existing sessions, but it does not offer remote coding tool controls.';

  @override
  String get pluginSettingsLoadFailed => 'Could not load coding tools';

  @override
  String get pluginSettingsLoadFailedDescription => 'Check your bridge connection and try again.';

  @override
  String get pluginSettingsRetry => 'Retry';

  @override
  String get pluginSettingsIdleTimeoutSection => 'Idle timeout';

  @override
  String get pluginSettingsGlobalIdleTimeout => 'Global idle timeout';

  @override
  String get pluginSettingsGlobalIdleTimeoutDescription => 'Applies to every coding tool and clears custom overrides.';

  @override
  String get pluginSettingsRegistrationsSection => 'Registered coding tools';

  @override
  String get pluginSettingsDefaultBadge => 'Default';

  @override
  String get pluginSettingsSetupStatus => 'Setup';

  @override
  String get pluginSettingsRuntimeStatus => 'Runtime';

  @override
  String get pluginSettingsWorkStatus => 'Work';

  @override
  String get pluginSettingsEligibility => 'Eligibility';

  @override
  String get pluginSettingsEligible => 'Eligible';

  @override
  String get pluginSettingsNotEligible => 'Not eligible';

  @override
  String get pluginSettingsEffectiveIdleTimeout => 'Effective idle timeout';

  @override
  String get pluginSettingsCustomIdleTimeout => 'Custom override';

  @override
  String get pluginSettingsUsesGlobalIdleTimeout => 'Uses the global timeout';

  @override
  String pluginSettingsTimeoutMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get pluginSettingsRefreshSetup => 'Check setup';

  @override
  String get pluginSettingsRestart => 'Restart';

  @override
  String get pluginSettingsSetOverride => 'Set override';

  @override
  String get pluginSettingsClearOverride => 'Clear override';

  @override
  String get pluginSettingsGlobalTimeoutDialogTitle => 'Set the global idle timeout';

  @override
  String pluginSettingsOverrideDialogTitle(String pluginName) {
    return 'Set the idle timeout for $pluginName';
  }

  @override
  String get pluginSettingsIdleTimeoutField => 'Idle timeout';

  @override
  String get pluginSettingsMinutesUnit => 'minutes';

  @override
  String get pluginSettingsSave => 'Save';

  @override
  String get pluginSettingsCancel => 'Cancel';

  @override
  String get pluginSettingsActionFailedTitle => 'Coding tool action failed';

  @override
  String get pluginSettingsActionFailed => 'The request failed. Try again.';

  @override
  String get pluginSettingsInvalidIdleTimeout => 'Enter an idle timeout as a whole number.';

  @override
  String get pluginSettingsActionNotFound => 'This coding tool is no longer registered. Refresh and try again.';

  @override
  String get pluginSettingsActionConflict => 'The coding tool cannot perform that action in its current state.';

  @override
  String get pluginSettingsDismissError => 'Dismiss error';

  @override
  String get pluginSettingsForceDisableTitle => 'Force disable this coding tool?';

  @override
  String get pluginSettingsForceRestartTitle => 'Force restart this coding tool?';

  @override
  String get pluginSettingsForceDescription =>
      'The tool is busy or its work state is uncertain. Forcing this action may interrupt active work.';

  @override
  String get pluginSettingsForceAction => 'Force';

  @override
  String get pluginSettingsSetupNotInspected => 'Not checked';

  @override
  String get pluginSettingsSetupReady => 'Ready';

  @override
  String get pluginSettingsSetupRuntimeMissing => 'Runtime missing';

  @override
  String get pluginSettingsSetupAuthenticationRequired => 'Authentication required';

  @override
  String get pluginSettingsSetupUnavailable => 'Unavailable';

  @override
  String get pluginSettingsStatusDisabled => 'Disabled';

  @override
  String get pluginSettingsStatusBlocked => 'Blocked';

  @override
  String get pluginSettingsStatusDormant => 'Ready when needed';

  @override
  String get pluginSettingsStatusStarting => 'Starting';

  @override
  String get pluginSettingsStatusActive => 'Active';

  @override
  String get pluginSettingsStatusDegraded => 'Needs attention';

  @override
  String get pluginSettingsStatusStopping => 'Stopping';

  @override
  String get pluginSettingsStatusFailed => 'Failed';

  @override
  String get pluginSettingsStatusUnknown => 'Unknown';

  @override
  String get pluginSettingsWorkIdle => 'Idle';

  @override
  String get pluginSettingsWorkBusy => 'Busy';

  @override
  String settingsVersion(String version, String buildNumber) {
    return 'v$version ($buildNumber)';
  }

  @override
  String get notificationSectionAi => 'AI Notifications';

  @override
  String get notificationSectionSystem => 'System';

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
  String get sessionListRepoInfoSemantics => 'Show full repository name';

  @override
  String sessionListTitleWithName(String name) {
    return '$name — Sessions';
  }

  @override
  String get sessionListLoadingSemantics => 'Loading sessions';

  @override
  String get sessionListEmptyTitle => 'Start your first task';

  @override
  String get sessionListUntitled => 'Untitled session';

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
  String get sessionListNewTask => 'New task';

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
  String get sessionListMarkRead => 'Mark as read';

  @override
  String get sessionListMarkUnread => 'Mark as unread';

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
  String get loginTitle => 'Welcome to';

  @override
  String get loginSubtitle => 'Sesori';

  @override
  String get loginAgreementText =>
      'By signing in, you accept our [Terms of Use](https://sesori.com/terms) and [Privacy Policy](https://sesori.com/privacy).';

  @override
  String get loginWithGithub => 'Sign in with GitHub';

  @override
  String get appleIdTokenMissing => 'Apple Sign-In failed. Please try again.';

  @override
  String get loginWithApple => 'Sign in with Apple';

  @override
  String get loginWithGoogle => 'Sign in with Google';

  @override
  String get signInWithEmail => 'Sign in with Email';

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
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get signIn => 'Sign in';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get loginAuthenticationFailedTitle => 'Authentication failed';

  @override
  String get loginError => 'Sign in failed. Please try again.';

  @override
  String get loginAuthenticating => 'Signing in...';

  @override
  String get loginAwaitingCallback => 'Waiting for authorization...';

  @override
  String get loginPolling => 'Confirm the sign-in in your browser to continue.';

  @override
  String get loginTimeout => 'Authorization timed out. Please try again.';

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
  String get sessionListNewActivity => 'New activity';

  @override
  String get sessionListRunningRetrying => 'Running (retrying)';

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
  String get projectHideFailed => 'Failed to hide project';

  @override
  String get hideProject => 'Hide Project';

  @override
  String get hide => 'Hide';

  @override
  String get projectFolderMissing => 'Unavailable';

  @override
  String get projectFolderMissingMessage =>
      'This project\'s folder no longer exists — it may have been moved or deleted. Hide the project, or restore the folder to its original location.';

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
  String get addProjectEnableGitTitle => 'Enable Git tracking?';

  @override
  String get addProjectEnableGitBody =>
      'Sesori will commit all non-ignored files to enable history and parallel sessions with dedicated worktrees.';

  @override
  String get addProjectContinueWithoutGit => 'Continue Without Git';

  @override
  String get addProjectEnableGit => 'Enable Git';

  @override
  String get addProjectGitSetupIncompleteTitle => 'Project opened, Git setup incomplete';

  @override
  String get addProjectGitSetupIncompleteBody =>
      'The folder is open and ready for sessions, but Sesori could not finish Git setup. Git files may have been created. Dedicated worktrees stay unavailable until the repository has an initial commit.';

  @override
  String get addProjectGitSetupIncompleteAcknowledge => 'I understand';

  @override
  String get projectCreateFailed => 'Failed to create project';

  @override
  String get projectDiscoverFailed => 'Failed to discover project';

  @override
  String get fetchDirectoryPermissionDenied =>
      'The bridge can\'t access this folder. On macOS, grant Full Disk Access to the terminal running the bridge in System Settings → Privacy & Security → Full Disk Access, then retry.';

  @override
  String get addProjectPermissionDenied =>
      'The bridge can\'t access that folder. Grant the terminal running the bridge Full Disk Access on your Mac, then try again.';

  @override
  String get filesystemAccessDegradedTitle => 'Limited folder access';

  @override
  String get filesystemAccessDegradedBody =>
      'The bridge can\'t read some folders. On macOS, grant Full Disk Access to the terminal running the bridge in System Settings → Privacy & Security.';

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
  String get newSessionPluginChooserLabel => 'Coding tool';

  @override
  String get newSessionPluginDegraded => 'Needs attention';

  @override
  String get newSessionPluginUnavailable => 'Unavailable';

  @override
  String get newSessionPluginFailed => 'Failed';

  @override
  String get newSessionPluginLoading => 'Loading coding tool options';

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

  @override
  String get diffPermissionRequestTitle => 'Permission Request';

  @override
  String get diffPermissionReject => 'Reject';

  @override
  String get diffPermissionOnce => 'Once';

  @override
  String get diffPermissionAlwaysAllow => 'Always Allow';

  @override
  String get diffFileChangesTitle => 'File Changes';

  @override
  String diffFilesChangedCount(int count, int additions, int deletions) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count file$_temp0 changed  +$additions -$deletions';
  }

  @override
  String get diffNoFileChanges => 'No file changes in this session';

  @override
  String diffErrorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String get diffRetry => 'Retry';

  @override
  String get newSessionLoadingSemantics => 'Creating session';

  @override
  String get newSessionLoadingMessage1 => 'Warming up the engines…';

  @override
  String get newSessionLoadingMessage2 => 'Generating session telemetry…';

  @override
  String get newSessionLoadingMessage3 => 'Preparing for takeoff…';

  @override
  String get newSessionLaunchingInBackground => 'Your new session will appear in the list once it\'s launched';

  @override
  String get commandSourceCommand => 'Command';

  @override
  String get commandSourceMcp => 'MCP';

  @override
  String get commandSourceSkill => 'Skill';

  @override
  String get commandSourceCustom => 'Custom';

  @override
  String get sessionDetailFileChangesTooltip => 'File changes';

  @override
  String get diffBinaryFileChanged => 'Binary file changed';

  @override
  String get diffFileTooLarge => 'File diff too large to display';

  @override
  String get diffCouldNotReadFile => 'Could not read file';

  @override
  String get timestampJustNow => 'just now';

  @override
  String timestampMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timestampHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String timestampDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get sessionDetailModelFallback => 'Model';

  @override
  String get sessionDetailAgentFallback => 'Agent';

  @override
  String get sessionDetailRetryLabel => 'Retry';

  @override
  String get sessionDetailCopy => 'Copy';

  @override
  String get sessionDetailShowMore => 'Show more';

  @override
  String get sessionDetailShowLess => 'Show less';

  @override
  String get emptySessionDetailTitle => 'Select a session';

  @override
  String get emptySessionDetailSubtitle => 'Choose a session from the list to view details';

  @override
  String get projectsOnboardingWhyLede => 'Your LLM of choice runs on your computer.';

  @override
  String get projectsOnboardingWhyBody => 'The Bridge securely connects it to Sesori on your phone.';

  @override
  String get projectsOnboardingWhySecureTitle => 'Secure access';

  @override
  String get projectsOnboardingWhySecureSubtitle => 'Your sessions are end-to-end encrypted.';

  @override
  String get projectsOnboardingWhyAnywhereTitle => 'Connect from anywhere';

  @override
  String get projectsOnboardingWhyAnywhereSubtitle => 'No shared Wi-Fi required.';

  @override
  String get projectsOnboardingWhyNotifiedTitle => 'Get notified';

  @override
  String get projectsOnboardingWhyNotifiedSubtitle => 'Know when a task needs you.';

  @override
  String get projectsOnboardingWhyFaqHeader => 'FAQs';

  @override
  String get projectsOnboardingWhyFaqDirectQuestion => 'Why can\'t the app connect directly?';

  @override
  String get projectsOnboardingWhyFaqDirectAnswer =>
      'Your AI assistant runs on your computer, not our servers. The Bridge is the secure link that lets your phone reach it from anywhere.';

  @override
  String get projectsOnboardingWhyFaqPcOnQuestion => 'Does my PC stay on?';

  @override
  String get projectsOnboardingWhyFaqPcOnAnswer =>
      'Your computer needs to be on and running Sesori for live sessions. You can start or stop it whenever you like.';

  @override
  String get projectsOnboardingWhyFaqReadQuestion => 'Can Sesori read my sessions?';

  @override
  String get projectsOnboardingWhyFaqReadAnswer =>
      'No. Everything between your phone and computer is end-to-end encrypted — the relay only passes along sealed data it can\'t read.';
}
