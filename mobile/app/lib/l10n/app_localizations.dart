import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sesori Mobile'**
  String get appTitle;

  /// No description provided for @connectErrorNonSuccessCode.
  ///
  /// In en, this message translates to:
  /// **'Server returned {errorCode}'**
  String connectErrorNonSuccessCode(int errorCode);

  /// No description provided for @connectErrorNonSuccessCodeWithBody.
  ///
  /// In en, this message translates to:
  /// **'Server returned {errorCode}: {body}'**
  String connectErrorNonSuccessCodeWithBody(int errorCode, String body);

  /// No description provided for @connectErrorConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {detail}'**
  String connectErrorConnectionFailed(String detail);

  /// No description provided for @connectErrorUnexpectedFormat.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response format'**
  String get connectErrorUnexpectedFormat;

  /// No description provided for @connectErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get connectErrorUnknown;

  /// No description provided for @apiErrorNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated — check your connection'**
  String get apiErrorNotAuthenticated;

  /// No description provided for @projectListTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectListTitle;

  /// No description provided for @projectListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No projects found'**
  String get projectListEmpty;

  /// No description provided for @projectListUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {timestamp}'**
  String projectListUpdated(String timestamp);

  /// No description provided for @projectListDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Default Project'**
  String get projectListDefaultName;

  /// No description provided for @projectListRefreshSuccess.
  ///
  /// In en, this message translates to:
  /// **'Projects updated'**
  String get projectListRefreshSuccess;

  /// No description provided for @projectListRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh projects'**
  String get projectListRefreshFailed;

  /// No description provided for @projectListErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load projects'**
  String get projectListErrorTitle;

  /// No description provided for @projectListRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get projectListRetry;

  /// No description provided for @projectListActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active session} other{{count} active sessions}}'**
  String projectListActiveSessions(int count);

  /// No description provided for @connectionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Lost'**
  String get connectionLostTitle;

  /// No description provided for @connectionLostReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get connectionLostReconnect;

  /// No description provided for @connectionLostDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get connectionLostDisconnect;

  /// No description provided for @relayConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Bridge went offline'**
  String get relayConnectionLost;

  /// No description provided for @relayReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to bridge...'**
  String get relayReconnecting;

  /// No description provided for @bridgeOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Bridge Offline'**
  String get bridgeOfflineTitle;

  /// No description provided for @bridgeOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Start sesori-bridge on your laptop'**
  String get bridgeOfflineMessage;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationCategoryAiInteraction.
  ///
  /// In en, this message translates to:
  /// **'AI Interactions'**
  String get notificationCategoryAiInteraction;

  /// No description provided for @notificationCategoryAiInteractionDescription.
  ///
  /// In en, this message translates to:
  /// **'Questions and permission requests from active AI sessions'**
  String get notificationCategoryAiInteractionDescription;

  /// No description provided for @notificationCategorySessionMessage.
  ///
  /// In en, this message translates to:
  /// **'Session Messages'**
  String get notificationCategorySessionMessage;

  /// No description provided for @notificationCategorySessionMessageDescription.
  ///
  /// In en, this message translates to:
  /// **'New assistant messages from running sessions'**
  String get notificationCategorySessionMessageDescription;

  /// No description provided for @notificationCategoryConnectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get notificationCategoryConnectionStatus;

  /// No description provided for @notificationCategoryConnectionStatusDescription.
  ///
  /// In en, this message translates to:
  /// **'Bridge online and offline status changes'**
  String get notificationCategoryConnectionStatusDescription;

  /// No description provided for @notificationCategorySystemUpdate.
  ///
  /// In en, this message translates to:
  /// **'System Updates'**
  String get notificationCategorySystemUpdate;

  /// No description provided for @notificationCategorySystemUpdateDescription.
  ///
  /// In en, this message translates to:
  /// **'App and bridge updates or maintenance notices'**
  String get notificationCategorySystemUpdateDescription;

  /// No description provided for @sessionListTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionListTitle;

  /// No description provided for @sessionListTitleWithName.
  ///
  /// In en, this message translates to:
  /// **'{name} — Sessions'**
  String sessionListTitleWithName(String name);

  /// No description provided for @sessionListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sessions found'**
  String get sessionListEmpty;

  /// No description provided for @sessionListUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled session'**
  String get sessionListUntitled;

  /// No description provided for @sessionListUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {timestamp}'**
  String sessionListUpdated(String timestamp);

  /// No description provided for @sessionListFilesChanged.
  ///
  /// In en, this message translates to:
  /// **'{count} files changed'**
  String sessionListFilesChanged(int count);

  /// No description provided for @sessionListRefreshSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sessions updated'**
  String get sessionListRefreshSuccess;

  /// No description provided for @sessionListRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh sessions'**
  String get sessionListRefreshFailed;

  /// No description provided for @sessionListErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sessions'**
  String get sessionListErrorTitle;

  /// No description provided for @sessionListRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sessionListRetry;

  /// No description provided for @sessionListNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get sessionListNewSession;

  /// No description provided for @sessionDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sessionDetailTitle;

  /// No description provided for @sessionDetailEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get sessionDetailEmpty;

  /// No description provided for @sessionDetailErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages'**
  String get sessionDetailErrorTitle;

  /// No description provided for @sessionDetailRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sessionDetailRetry;

  /// No description provided for @sessionDetailPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Ask anything...'**
  String get sessionDetailPromptHint;

  /// No description provided for @sessionDetailSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sessionDetailSend;

  /// No description provided for @sessionDetailAbort.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get sessionDetailAbort;

  /// No description provided for @sessionDetailThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get sessionDetailThinking;

  /// No description provided for @sessionDetailThought.
  ///
  /// In en, this message translates to:
  /// **'Thought'**
  String get sessionDetailThought;

  /// No description provided for @sessionDetailToolUnknown.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get sessionDetailToolUnknown;

  /// No description provided for @sessionDetailToolPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get sessionDetailToolPending;

  /// No description provided for @sessionDetailToolRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get sessionDetailToolRunning;

  /// No description provided for @sessionDetailToolCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get sessionDetailToolCompleted;

  /// No description provided for @sessionDetailToolError.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get sessionDetailToolError;

  /// No description provided for @sessionDetailFollowOutput.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get sessionDetailFollowOutput;

  /// No description provided for @questionModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get questionModalTitle;

  /// No description provided for @questionModalReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get questionModalReject;

  /// No description provided for @questionModalCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Type your own answer'**
  String get questionModalCustomHint;

  /// No description provided for @questionModalSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get questionModalSubmit;

  /// No description provided for @questionModalNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get questionModalNext;

  /// No description provided for @questionModalStepIndicator.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionModalStepIndicator(int current, int total);

  /// No description provided for @questionBannerSingle.
  ///
  /// In en, this message translates to:
  /// **'1 pending question'**
  String get questionBannerSingle;

  /// No description provided for @questionBannerMultiple.
  ///
  /// In en, this message translates to:
  /// **'{count} pending questions'**
  String questionBannerMultiple(int count);

  /// No description provided for @sessionDetailSubtaskUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Background task'**
  String get sessionDetailSubtaskUnnamed;

  /// No description provided for @sessionDetailQueuedMessage.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get sessionDetailQueuedMessage;

  /// No description provided for @sessionDetailCancelQueued.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sessionDetailCancelQueued;

  /// No description provided for @sessionDetailPickerAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get sessionDetailPickerAgent;

  /// No description provided for @sessionDetailPickerModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get sessionDetailPickerModel;

  /// No description provided for @sessionDetailSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get sessionDetailSelectModel;

  /// No description provided for @sessionDetailModelSearch.
  ///
  /// In en, this message translates to:
  /// **'Search models...'**
  String get sessionDetailModelSearch;

  /// No description provided for @backgroundTasksRunning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Task Running} other{{count} Tasks Running}}'**
  String backgroundTasksRunning(int count);

  /// No description provided for @backgroundTasksCompleted.
  ///
  /// In en, this message translates to:
  /// **'All tasks completed'**
  String get backgroundTasksCompleted;

  /// No description provided for @backgroundTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Background Tasks'**
  String get backgroundTasksTitle;

  /// No description provided for @backgroundTaskStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get backgroundTaskStatusIdle;

  /// No description provided for @backgroundTaskStatusBusy.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get backgroundTaskStatusBusy;

  /// No description provided for @backgroundTaskStatusRetry.
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get backgroundTaskStatusRetry;

  /// No description provided for @backgroundTasksShowCompleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 completed task} other{Show {count} completed tasks}}'**
  String backgroundTasksShowCompleted(int count);

  /// No description provided for @backgroundTasksHideCompleted.
  ///
  /// In en, this message translates to:
  /// **'Hide completed'**
  String get backgroundTasksHideCompleted;

  /// No description provided for @sessionListToggleArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get sessionListToggleArchived;

  /// No description provided for @sessionListEmptyArchived.
  ///
  /// In en, this message translates to:
  /// **'No archived sessions'**
  String get sessionListEmptyArchived;

  /// No description provided for @sessionListArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get sessionListArchive;

  /// No description provided for @sessionListUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get sessionListUnarchive;

  /// No description provided for @sessionListDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sessionListDelete;

  /// No description provided for @sessionListArchived.
  ///
  /// In en, this message translates to:
  /// **'Session archived'**
  String get sessionListArchived;

  /// No description provided for @sessionListUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Session unarchived'**
  String get sessionListUnarchived;

  /// No description provided for @sessionListDeleted.
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get sessionListDeleted;

  /// No description provided for @sessionListUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get sessionListUndo;

  /// No description provided for @sessionListDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session?'**
  String get sessionListDeleteConfirmTitle;

  /// No description provided for @sessionListDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove the session and all its messages. This cannot be undone.'**
  String get sessionListDeleteConfirmMessage;

  /// No description provided for @sessionListDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sessionListDeleteConfirmAction;

  /// No description provided for @sessionListDeleteConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sessionListDeleteConfirmCancel;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to connect to your server'**
  String get loginSubtitle;

  /// No description provided for @loginWithGithub.
  ///
  /// In en, this message translates to:
  /// **'Sign in with GitHub'**
  String get loginWithGithub;

  /// No description provided for @loginWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get loginWithGoogle;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed. Please try again.'**
  String get loginError;

  /// No description provided for @loginAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get loginAuthenticating;

  /// No description provided for @loginAwaitingCallback.
  ///
  /// In en, this message translates to:
  /// **'Waiting for authorization...'**
  String get loginAwaitingCallback;

  /// No description provided for @loginBrowserOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open browser'**
  String get loginBrowserOpenFailed;

  /// No description provided for @loginCallbackTimeout.
  ///
  /// In en, this message translates to:
  /// **'Authorization timed out. Please try again.'**
  String get loginCallbackTimeout;

  /// No description provided for @loginCallbackMissingParams.
  ///
  /// In en, this message translates to:
  /// **'Invalid authorization callback. Please try again.'**
  String get loginCallbackMissingParams;

  /// No description provided for @loginStateMismatch.
  ///
  /// In en, this message translates to:
  /// **'Authorization state mismatch. Please try again.'**
  String get loginStateMismatch;

  /// No description provided for @loginPkceStateMissing.
  ///
  /// In en, this message translates to:
  /// **'Login session expired. Please start again.'**
  String get loginPkceStateMissing;

  /// Label shown next to the green dot for sessions that are currently active
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get sessionListRunning;

  /// Label showing the number of active background tasks for a session
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 background task} other{{count} background tasks}}'**
  String sessionListBackgroundTasks(int count);

  /// No description provided for @sessionListStaleProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Project directory not found'**
  String get sessionListStaleProjectTitle;

  /// No description provided for @sessionListStaleProjectMessage.
  ///
  /// In en, this message translates to:
  /// **'The directory for this project no longer exists or has been renamed. Sessions cannot be loaded because the server can no longer resolve this project.'**
  String get sessionListStaleProjectMessage;

  /// No description provided for @sessionListStaleProjectBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get sessionListStaleProjectBack;

  /// No description provided for @voiceRecord.
  ///
  /// In en, this message translates to:
  /// **'Record voice'**
  String get voiceRecord;

  /// No description provided for @voiceStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get voiceStopRecording;

  /// No description provided for @voiceCancelTranscription.
  ///
  /// In en, this message translates to:
  /// **'Cancel transcription'**
  String get voiceCancelTranscription;

  /// No description provided for @voiceTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing...'**
  String get voiceTranscribing;

  /// No description provided for @voiceRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get voiceRecording;

  /// No description provided for @voiceErrorPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for voice input'**
  String get voiceErrorPermission;

  /// No description provided for @voiceErrorRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording failed. Please try again.'**
  String get voiceErrorRecording;

  /// No description provided for @voiceErrorTranscription.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed. Please try again.'**
  String get voiceErrorTranscription;

  /// No description provided for @voiceErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection.'**
  String get voiceErrorNetwork;

  /// No description provided for @voiceErrorNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use voice input'**
  String get voiceErrorNotAuthenticated;

  /// No description provided for @voiceRecordingLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Recording limit reached (15 minutes)'**
  String get voiceRecordingLimitReached;

  /// No description provided for @addProject.
  ///
  /// In en, this message translates to:
  /// **'Add Project'**
  String get addProject;

  /// No description provided for @projectNameHint.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectNameHint;

  /// No description provided for @createProjectButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createProjectButton;

  /// No description provided for @openAsProject.
  ///
  /// In en, this message translates to:
  /// **'Open as Project'**
  String get openAsProject;

  /// No description provided for @emptyDirectory.
  ///
  /// In en, this message translates to:
  /// **'This directory is empty'**
  String get emptyDirectory;

  /// No description provided for @fetchDirectoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load directory contents'**
  String get fetchDirectoryFailed;

  /// No description provided for @gitRepoBadge.
  ///
  /// In en, this message translates to:
  /// **'git'**
  String get gitRepoBadge;

  /// No description provided for @projectHidden.
  ///
  /// In en, this message translates to:
  /// **'Project hidden'**
  String get projectHidden;

  /// No description provided for @hideProject.
  ///
  /// In en, this message translates to:
  /// **'Hide Project'**
  String get hideProject;

  /// No description provided for @noProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects'**
  String get noProjects;

  /// No description provided for @addProjectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add a project to get started'**
  String get addProjectPrompt;

  /// No description provided for @creatingProject.
  ///
  /// In en, this message translates to:
  /// **'Creating project...'**
  String get creatingProject;

  /// No description provided for @discoveringProject.
  ///
  /// In en, this message translates to:
  /// **'Discovering project...'**
  String get discoveringProject;

  /// No description provided for @projectCreated.
  ///
  /// In en, this message translates to:
  /// **'Project created'**
  String get projectCreated;

  /// No description provided for @projectDiscovered.
  ///
  /// In en, this message translates to:
  /// **'Project discovered'**
  String get projectDiscovered;

  /// No description provided for @projectCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create project'**
  String get projectCreateFailed;

  /// No description provided for @projectDiscoverFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to discover project'**
  String get projectDiscoverFailed;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
