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
  String get projectsEmptyMessage => 'You don\'t have any projects created or opened yet.';

  @override
  String get projectsEmptyAddProject => 'Open new project';

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
  String projectsBridgeOfflineDisconnectedSince(String lastSeen) {
    return 'Disconnected · $lastSeen';
  }

  @override
  String get projectsBridgeOfflineInstallCommands => 'Install commands';

  @override
  String get projectsBridgeOfflineStartBridge => 'Make sure the Bridge is running';

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
  String get settingsHarnessesTitle => 'Harnesses';

  @override
  String get settingsSectionBridge => 'Bridge';

  @override
  String get settingsYoloTitle => 'YOLO mode';

  @override
  String get settingsYoloWarning => 'Automatically approves all permission requests. Use with caution.';

  @override
  String get settingsYoloLoading => 'Loading the bridge setting…';

  @override
  String get settingsYoloDisconnected => 'Connect to a bridge to configure this setting.';

  @override
  String get settingsYoloUnsupported => 'Update the connected bridge to configure this setting.';

  @override
  String get settingsYoloLoadFailed => 'Couldn\'t load the bridge setting. Check your connection and try again.';

  @override
  String get settingsYoloUncertain => 'The update status is unknown. Refresh before trying again.';

  @override
  String get settingsYoloUpdateFailed => 'Couldn\'t update the bridge setting. Check your connection and try again.';

  @override
  String get settingsYoloRetry => 'Retry YOLO setting';

  @override
  String get settingsPullRequestRefreshTitle => 'Pull request refresh';

  @override
  String get settingsPullRequestRefreshDescription => 'How often viewed projects refresh pull request status.';

  @override
  String get settingsPullRequestRefreshLoading => 'Loading the bridge setting…';

  @override
  String get settingsPullRequestRefreshDisconnected => 'Connect to a bridge to configure this setting.';

  @override
  String get settingsPullRequestRefreshUnsupported => 'Update the connected bridge to configure this setting.';

  @override
  String get settingsPullRequestRefreshLoadFailed =>
      'Couldn\'t load the bridge setting. Check your connection and try again.';

  @override
  String get settingsPullRequestRefreshUncertain => 'The update status is unknown. Refresh before trying again.';

  @override
  String get settingsPullRequestRefreshUpdateFailed =>
      'Couldn\'t update the bridge setting. Check your connection and try again.';

  @override
  String get settingsPullRequestRefreshStateChanged => 'The bridge setting changed while you were editing. Try again.';

  @override
  String get settingsPullRequestRefreshUnavailable => 'Unavailable';

  @override
  String get settingsPullRequestRefreshOffline => 'Offline';

  @override
  String get settingsPullRequestRefreshRetry => 'Retry pull request refresh setting';

  @override
  String get settingsPullRequestRefreshDialogTitle => 'Pull request refresh interval';

  @override
  String get settingsPullRequestRefreshSecondsLabel => 'Seconds';

  @override
  String get settingsPullRequestRefreshInvalid => 'Enter a whole number of seconds.';

  @override
  String settingsPullRequestRefreshRangeInvalid(int minimumSeconds, int maximumSeconds) {
    final intl.NumberFormat minimumSecondsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumSecondsString = minimumSecondsNumberFormat.format(minimumSeconds);
    final intl.NumberFormat maximumSecondsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumSecondsString = maximumSecondsNumberFormat.format(maximumSeconds);

    return 'Enter a whole number from $minimumSecondsString to $maximumSecondsString.';
  }

  @override
  String get settingsPullRequestRefreshCancel => 'Cancel';

  @override
  String get settingsPullRequestRefreshSave => 'Save';

  @override
  String settingsPullRequestRefreshSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get harnessManagementDescription => 'Control the harnesses that support management through Sesori.';

  @override
  String get harnessManagementDefaultsSection => 'Bridge Default';

  @override
  String get harnessManagementDefaultTimeout => 'Default idle timeout';

  @override
  String get harnessManagementDefaultTimeoutDescription =>
      'Apply this timeout to every harness that supports idle-timeout control.';

  @override
  String get harnessManagementEnabled => 'Enabled';

  @override
  String get harnessManagementRefreshSetup => 'Refresh setup';

  @override
  String get harnessManagementInstall => 'Install runtime';

  @override
  String get harnessManagementInstallDescription =>
      'Download this harness for Sesori only. Your system stays untouched.';

  @override
  String get harnessManagementInstallDownloading => 'Downloading…';

  @override
  String harnessManagementInstallDownloadingPercent(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get harnessManagementInstallVerifying => 'Verifying download…';

  @override
  String get harnessManagementInstallExtracting => 'Extracting…';

  @override
  String get harnessManagementInstallFinishing => 'Finishing up…';

  @override
  String get harnessManagementInstallInProgress => 'Installing…';

  @override
  String get harnessManagementRestart => 'Restart';

  @override
  String get harnessManagementIdleTimeout => 'Idle timeout';

  @override
  String get harnessManagementClearOverride => 'Use bridge default';

  @override
  String get harnessManagementExternalTitle => 'Managed outside Sesori';

  @override
  String get harnessManagementExternalDescription =>
      'This harness process is controlled externally. Sesori will not start, stop, restart, or suspend it.';

  @override
  String get harnessManagementDefaultTimeoutDialogTitle => 'Set default idle timeout';

  @override
  String harnessManagementTimeoutDialogTitle(String harnessName) {
    return 'Set $harnessName idle timeout';
  }

  @override
  String get harnessManagementTimeoutMinutesLabel => 'Minutes';

  @override
  String get harnessManagementTimeoutUseDefault => 'Use bridge default';

  @override
  String get harnessManagementTimeoutNoTimeout => 'No timeout';

  @override
  String get harnessManagementTimeoutCustom => 'Custom';

  @override
  String get harnessManagementTimeoutHelp => 'Custom timeouts must be a whole number greater than zero.';

  @override
  String get harnessManagementCancel => 'Cancel';

  @override
  String get harnessManagementSave => 'Save';

  @override
  String get harnessManagementForceDisableTitle => 'Force disable harness?';

  @override
  String get harnessManagementForceRestartTitle => 'Force restart harness?';

  @override
  String get harnessManagementForceDescription =>
      'Active work may be interrupted. This action is sent once and cannot be undone.';

  @override
  String get harnessManagementForceAction => 'Force action';

  @override
  String get harnessManagementActionFailedTitle => 'Harness action failed';

  @override
  String get harnessManagementDismissActionError => 'Dismiss action error';

  @override
  String get harnessManagementInvalidTimeout => 'Enter a whole number greater than zero.';

  @override
  String get harnessManagementNotFound => 'The harness is no longer registered on this bridge.';

  @override
  String get harnessManagementConflict => 'The bridge rejected the action because the harness state changed.';

  @override
  String get harnessManagementUncertain =>
      'The connection changed before the result could be confirmed. Refresh before trying again.';

  @override
  String get harnessManagementRequestFailed => 'Check your connection and try again.';

  @override
  String get harnessAuthenticationLogIn => 'Log in';

  @override
  String get harnessAuthenticationContinue => 'Continue login';

  @override
  String get harnessAuthenticationDescription => 'Authorize this harness from your phone.';

  @override
  String get harnessAuthenticationSheetTitle => 'Log in to harness';

  @override
  String get harnessAuthenticationSecurityDescription =>
      'Only continue if you started this login. Sesori will open the harness provider\'s secure website; verify the address before entering the code.';

  @override
  String get harnessAuthenticationSecuritySemantics =>
      'Security notice. Only continue if you started this login. Verify the website address before entering the code.';

  @override
  String get harnessAuthenticationCodeLabel => 'One-time code';

  @override
  String get harnessAuthenticationCopyCode => 'Copy one-time code';

  @override
  String get harnessAuthenticationCodeCopied => 'Code copied';

  @override
  String get harnessAuthenticationWaiting => 'Waiting for authorization on the bridge…';

  @override
  String get harnessAuthenticationOpenBrowser => 'Open secure website';

  @override
  String get harnessAuthenticationCancel => 'Cancel login';

  @override
  String get harnessAuthenticationCancelling => 'Cancelling…';

  @override
  String get harnessAuthenticationCancellingUncertain =>
      'Cancellation was sent, but the response was lost. Waiting for the bridge to confirm…';

  @override
  String get harnessAuthenticationFailedTitle => 'Harness login failed';

  @override
  String get harnessAuthenticationDismissError => 'Dismiss login error';

  @override
  String get harnessAuthenticationNotFound => 'The harness is no longer registered on this bridge.';

  @override
  String get harnessAuthenticationUnsupported => 'Update the connected bridge to log in from this device.';

  @override
  String get harnessAuthenticationConflict =>
      'The harness is busy with another management action. Refresh before trying again.';

  @override
  String get harnessAuthenticationUncertain =>
      'The connection changed before the result could be confirmed. Refresh before trying again.';

  @override
  String get harnessAuthenticationInvalidChallenge =>
      'The bridge returned an invalid login website. Check the bridge logs for details.';

  @override
  String get harnessAuthenticationBrowserFailed =>
      'The secure website could not be opened. Copy the code and try again.';

  @override
  String get harnessAuthenticationRequestFailed => 'Check your connection and try again.';

  @override
  String get harnessesRegisteredSection => 'Registered Harnesses';

  @override
  String get harnessesEmptyTitle => 'No harnesses registered';

  @override
  String get harnessesEmptyDescription => 'The connected bridge hasn\'t registered any coding harnesses.';

  @override
  String get harnessesLoading => 'Loading harnesses';

  @override
  String get harnessesUnsupportedTitle => 'Harnesses aren\'t supported';

  @override
  String get harnessesUnsupportedDescription => 'Update the connected bridge to view and manage its harnesses.';

  @override
  String get harnessesLoadFailedTitle => 'Failed to load harnesses';

  @override
  String get harnessesLoadFailedDescription => 'Check your connection and try again.';

  @override
  String get harnessesRetry => 'Retry';

  @override
  String get harnessesRefreshFailedTitle => 'Could not refresh harnesses';

  @override
  String get harnessesRefreshFailedDescription => 'Showing the last information received from the bridge.';

  @override
  String get harnessesDismissRefreshError => 'Dismiss refresh error';

  @override
  String get harnessesDefaultBadge => 'Default';

  @override
  String get harnessesSetupStatus => 'Setup';

  @override
  String get harnessesRuntimeStatus => 'Runtime';

  @override
  String get harnessesWorkStatus => 'Work';

  @override
  String get harnessesCustomIdleTimeout => 'Custom for this harness';

  @override
  String get harnessesUsesDefaultIdleTimeout => 'Uses the bridge default';

  @override
  String get harnessesNoIdleTimeout => 'No timeout';

  @override
  String get harnessesNoIdleTimeoutDescription => 'This harness stays running';

  @override
  String harnessesIdleTimeoutMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get harnessesSetupNotInspected => 'Not inspected';

  @override
  String get harnessesSetupReady => 'Ready';

  @override
  String get harnessesSetupRuntimeMissing => 'Runtime missing';

  @override
  String get harnessesSetupAuthenticationRequired => 'Authentication required';

  @override
  String get harnessesSetupUnavailable => 'Unavailable';

  @override
  String get harnessesStatusDisabled => 'Disabled';

  @override
  String get harnessesStatusBlocked => 'Blocked';

  @override
  String get harnessesStatusDormant => 'Dormant';

  @override
  String get harnessesStatusStarting => 'Starting';

  @override
  String get harnessesStatusActive => 'Active';

  @override
  String get harnessesStatusDegraded => 'Needs attention';

  @override
  String get harnessesStatusStopping => 'Stopping';

  @override
  String get harnessesStatusFailed => 'Failed';

  @override
  String get harnessesStatusUnknown => 'Unknown';

  @override
  String get harnessesWorkIdle => 'Idle';

  @override
  String get harnessesWorkBusy => 'Busy';

  @override
  String get settingsProfileTitle => 'Profile';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionAnalytics => 'Analytics';

  @override
  String get settingsBasicUsageAnalyticsTitle => 'Basic Usage Analytics';

  @override
  String get settingsBasicUsageAnalyticsDescription => 'Share basic feature usage — never your code or messages.';

  @override
  String get settingsBasicUsageAnalyticsLoading => 'Loading preference…';

  @override
  String get settingsBasicUsageAnalyticsSaving => 'Saving preference…';

  @override
  String get settingsBasicUsageAnalyticsLoadFailed => 'Analytics preference failed to load.';

  @override
  String get settingsBasicUsageAnalyticsSyncFailed => 'Couldn\'t sync preference.';

  @override
  String get settingsBasicUsageAnalyticsRetry => 'Retry preference sync';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get settingsAppearanceSystem => 'System';

  @override
  String get settingsDefaultInputTitle => 'Default input';

  @override
  String get settingsDefaultInputVoice => 'Voice';

  @override
  String get settingsDefaultInputText => 'Text';

  @override
  String get settingsDefaultInputTextPreview => 'Ask Sesori';

  @override
  String get settingsSectionSupport => 'Support';

  @override
  String get settingsSupportEmail => 'Email';

  @override
  String get settingsSupportDiscord => 'Discord';

  @override
  String get settingsSupportX => 'DM on X';

  @override
  String get settingsSectionLegal => 'Legal';

  @override
  String get settingsLegalTerms => 'Terms of Service';

  @override
  String get settingsLegalPrivacy => 'Privacy Policy';

  @override
  String get legalDocumentRetry => 'Retry';

  @override
  String get settingsClose => 'Close settings';

  @override
  String get settingsAppName => 'Sesori';

  @override
  String settingsVersion(String version, String buildNumber) {
    return 'v$version ($buildNumber)';
  }

  @override
  String get notificationSectionAi => 'AI Notifications';

  @override
  String get notificationSectionSystem => 'System';

  @override
  String get notificationPreferencesUnavailableTitle => 'Notification preferences unavailable';

  @override
  String get notificationPreferencesUnavailableDescription => 'Sign in to manage notification preferences.';

  @override
  String get notificationPreferencesLoadFailedTitle => 'Couldn\'t load notification preferences';

  @override
  String get notificationPreferencesLoadFailedDescription => 'Check your connection and try again.';

  @override
  String get notificationPreferencesRetry => 'Retry';

  @override
  String get notificationPreferenceUpdating => 'Updating notification preference';

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
  String get sessionDetailHoldToTalk => 'Hold to talk';

  @override
  String get sessionDetailFollowUpHint => 'Follow up...';

  @override
  String get sessionDetailHoldToTalkMore => 'Hold to talk more';

  @override
  String get sessionDetailTypeMessage => 'Type a message';

  @override
  String get sessionDetailMoreActions => 'More actions';

  @override
  String get sessionDetailHideActions => 'Hide actions';

  @override
  String get sessionDetailAttachImage => 'Attach image';

  @override
  String get sessionDetailRemoveAttachment => 'Remove attachment';

  @override
  String get sessionDetailAttachedImage => 'Attached image';

  @override
  String sessionDetailAttachmentSizeBytes(int count) {
    return '$count bytes';
  }

  @override
  String get sessionDetailAttachmentTooLarge => 'That image is too large to attach.';

  @override
  String get sessionDetailAttachmentPickFailed => 'Couldn\'t attach the image.';

  @override
  String get sessionDetailAttachmentUnsupported => 'That image format isn\'t supported.';

  @override
  String get sessionDetailAttachmentBudgetExceeded => 'Attached images are limited to 50 MB per message.';

  @override
  String get sessionDetailAttachmentsNotWithCommands => 'Images can\'t be sent with slash commands.';

  @override
  String sessionDetailQueuedAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
    );
    return '$_temp0';
  }

  @override
  String get sessionDetailExpandEditor => 'Expand editor';

  @override
  String get sessionDetailEditorTitle => 'Message';

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
  String get sessionDetailImageOpen => 'Open image';

  @override
  String get sessionDetailImageClose => 'Close image';

  @override
  String get sessionDetailImageShare => 'Share image';

  @override
  String get sessionDetailImageCopy => 'Copy image';

  @override
  String get sessionDetailImageSave => 'Save image';

  @override
  String get sessionDetailImageOpenOriginal => 'Open original';

  @override
  String get sessionDetailImageOriginalLoadFailed => 'Couldn’t load the original image.';

  @override
  String get sessionDetailRetryOriginal => 'Retry original';

  @override
  String get sessionDetailImageSaved => 'Image saved';

  @override
  String get sessionDetailImageSaveFailed => 'Couldn’t save image';

  @override
  String get sessionDetailImageShareFailed => 'Couldn’t share image';

  @override
  String get sessionDetailImageCopied => 'Image copied to clipboard';

  @override
  String get sessionDetailImageCopyFailed => 'Couldn’t copy image';

  @override
  String get sessionDetailImageSaveAccessDenied => 'Permission denied while saving this image';

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
  String get questionModalDecline => 'Decline';

  @override
  String get questionModalDeclineAll => 'Decline all';

  @override
  String get questionModalDeclineQuestion => 'Decline this question';

  @override
  String get questionModalDeclineQuestionHint => 'The assistant will see it as unanswered.';

  @override
  String get questionModalQuestionDeclined => 'Question declined';

  @override
  String get questionModalQuestionDeclinedHint => 'Choose an answer to undo.';

  @override
  String get questionModalDeclineAllTitle => 'Decline all questions?';

  @override
  String get questionModalDeclineAllMessage =>
      'None of your draft answers will be sent. Your coding session will remain active.';

  @override
  String get questionModalKeepAnswering => 'Keep answering';

  @override
  String get questionModalCustomHint => 'Type your own answer';

  @override
  String get questionModalSubmit => 'Submit answers';

  @override
  String get questionModalNext => 'Next';

  @override
  String get questionModalResolveAll => 'Answer or decline every question to submit.';

  @override
  String get questionModalResolveAllCompact => 'Answer or decline all';

  @override
  String get questionModalStatusUnanswered => 'unanswered';

  @override
  String get questionModalStatusAnswered => 'answered';

  @override
  String get questionModalStatusDeclined => 'declined';

  @override
  String questionModalStepIndicator(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String questionModalStepSemantics(int current, int total, String status) {
    return 'Question $current of $total, $status';
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
  String get sessionDetailSendingMessage => 'Sending';

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
  String get sessionListMarkRead => 'Mark as read';

  @override
  String get sessionListMarkUnread => 'Mark as unread';

  @override
  String get sessionListDelete => 'Delete';

  @override
  String get sessionListArchived => 'Session archived';

  @override
  String get sessionListDeleted => 'Session deleted';

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
  String sessionListHarness(String harness) {
    return '$harness session';
  }

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
  String get voiceCancelRecording => 'Cancel recording';

  @override
  String get voiceReleaseToTranscribe => 'Release to transcribe';

  @override
  String get voiceReleaseToCancel => 'Release to cancel';

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
  String get voiceErrorRealtimeQuota => 'Voice input quota reached. Try again later.';

  @override
  String get voiceErrorRealtimeTemporaryUnavailable => 'Voice input is temporarily unavailable. Try again in a moment.';

  @override
  String get voiceErrorRealtimeInterrupted => 'Voice connection was interrupted. Try again.';

  @override
  String get voiceErrorContract => 'Voice input needs an app update. Update Sesori and try again.';

  @override
  String get voiceErrorNetwork => 'Could not reach the server. Check your connection.';

  @override
  String get voiceErrorNotAuthenticated => 'Sign in to use voice input';

  @override
  String get voiceRecordingLimitReached => 'Recording limit reached (15 minutes)';

  @override
  String get addProject => 'Add Project';

  @override
  String get addAsNewProject => 'Add as new project';

  @override
  String get createNewFolder => 'Create new folder';

  @override
  String get newFolderTitle => 'New folder';

  @override
  String get newFolderHint => 'Folder name';

  @override
  String get newFolderCreate => 'Create';

  @override
  String get newFolderExists => 'A file or folder with that name already exists here';

  @override
  String get newFolderFailed => 'Could not create the folder';

  @override
  String get newFolderUnsupported => 'Update Sesori Bridge on your computer to create folders from here.';

  @override
  String get emptyDirectory => 'This directory is empty';

  @override
  String get fetchDirectoryFailed => 'Could not load directory contents';

  @override
  String get fetchDirectoryRetry => 'Retry';

  @override
  String get fetchDirectoryGoBack => 'Go Back';

  @override
  String get gitRepoBadge => 'Git';

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
  String get newSessionDedicatedWorkspace => 'Dedicated workspace';

  @override
  String get newSessionPluginChooserLabel => 'Coding tool';

  @override
  String get newSessionPluginDegraded => 'Needs attention';

  @override
  String get newSessionPluginUnavailable => 'Unavailable';

  @override
  String get newSessionPluginFailed => 'Failed';

  @override
  String get newSessionHarnessSettings => 'Harness settings';

  @override
  String get newSessionNoHarnessTitle => 'No coding harness installed';

  @override
  String get newSessionNoHarnessDescription =>
      'The connected bridge has no coding harness it can run. Install one from Harness settings.';

  @override
  String get newSessionHarnessesRefresh => 'Check for harnesses';

  @override
  String get newSessionOptionsLoadingSemantics => 'Loading session options';

  @override
  String get newSessionOptionsRefresh => 'Refresh the model list';

  @override
  String get newSessionOptionsCached => 'Using cached coding tool options.';

  @override
  String get newSessionOptionsUnavailable =>
      'No cached options are available. You can create with defaults or refresh now.';

  @override
  String get newSessionOptionsLoadFailedUnavailable =>
      'Couldn’t load options. You can create with defaults or try again.';

  @override
  String get newSessionOptionsLegacyBridge =>
      'This bridge can load options only by starting the selected coding tool. You can create with defaults or refresh now.';

  @override
  String get newSessionOptionsUpdateFailedRetained =>
      'Couldn’t update options. Previously cached options are still available.';

  @override
  String get newSessionOptionsRefreshFailedUnavailable =>
      'Refresh failed and no valid cached options remain. You can create with defaults.';

  @override
  String get sessionListDeleteWorktreeCheckbox => 'Delete worktree';

  @override
  String get sessionDetailArchivedNotice => 'This session is archived and read-only.';

  @override
  String get sessionListArchiveConfirmTitle => 'Archive session?';

  @override
  String get sessionListArchiveConfirmMessage =>
      'Archiving is permanent. This session becomes read-only — you can still read it, but you cannot reopen it, send prompts, or unarchive it.';

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
  String get timestampCompactNow => 'now';

  @override
  String timestampCompactMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String timestampCompactHours(int hours) {
    return '${hours}h';
  }

  @override
  String timestampCompactDays(int days) {
    return '${days}d';
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
