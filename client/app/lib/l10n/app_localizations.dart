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

  /// No description provided for @apiErrorServerRejected.
  ///
  /// In en, this message translates to:
  /// **'The server returned an error. Please try again.'**
  String get apiErrorServerRejected;

  /// No description provided for @apiErrorNetworkDown.
  ///
  /// In en, this message translates to:
  /// **'Connection failed — check your network and try again.'**
  String get apiErrorNetworkDown;

  /// No description provided for @projectListTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectListTitle;

  /// App-bar title shown in place of 'Projects' while the connect-your-computer onboarding is visible (no bridge has ever been registered and none is connected).
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get projectListConnectTitle;

  /// No description provided for @projectListLoadingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Loading projects'**
  String get projectListLoadingSemantics;

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

  /// Status shown beside the animated sparkle on a project row that has at least one session an agent is currently working in.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Running} other{{count} running}}'**
  String projectListRunning(int count);

  /// Status shown beside a static sparkle on a project row with unseen agent activity the user hasn't opened yet.
  ///
  /// In en, this message translates to:
  /// **'New activity'**
  String get projectListNewActivity;

  /// Status caption under the connection graphic on the connected-but-empty Projects screen, rendered in the success color with a check icon.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get projectsEmptyConnected;

  /// Message above the add-project button on the connected-but-empty Projects screen.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any projects created or opened yet.'**
  String get projectsEmptyMessage;

  /// Label of the button on the connected-but-empty Projects screen that opens the Add Project sheet.
  ///
  /// In en, this message translates to:
  /// **'Add a new project to get started'**
  String get projectsEmptyAddProject;

  /// Label for the button below the PC status line that opens the bridge explainer bottom sheet; also used as that sheet's title.
  ///
  /// In en, this message translates to:
  /// **'Why is this needed?'**
  String get projectsOnboardingPcStatusWhy;

  /// Label for the glass pill button below the PC status line that opens a menu of support channels.
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get projectsOnboardingNeedHelp;

  /// Need-help menu item that opens the user's mail app to contact support.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get projectsOnboardingNeedHelpEmail;

  /// Need-help menu item that opens the Sesori Discord. 'Discord' is a brand name; do not translate.
  ///
  /// In en, this message translates to:
  /// **'Discord'**
  String get projectsOnboardingNeedHelpDiscord;

  /// Need-help menu item that opens the Sesori profile on X (formerly Twitter), where users can send a direct message. 'X' is a brand name; do not translate.
  ///
  /// In en, this message translates to:
  /// **'DM on X'**
  String get projectsOnboardingNeedHelpX;

  /// Segmented-control label that selects the macOS/Linux/WSL install commands, shown both in the onboarding and in the bridge-offline install-commands disclosure.
  ///
  /// In en, this message translates to:
  /// **'macOS, Linux, WSL'**
  String get projectsOnboardingInstallUnixLabel;

  /// Install-method tab label for the macOS/Linux/WSL box. Literal command name 'curl'; do not translate.
  ///
  /// In en, this message translates to:
  /// **'curl'**
  String get projectsOnboardingInstallUnixMethod;

  /// Segmented-control label that selects the Windows PowerShell install commands, shown both in the onboarding and in the bridge-offline install-commands disclosure.
  ///
  /// In en, this message translates to:
  /// **'Windows PowerShell'**
  String get projectsOnboardingInstallWindowsLabel;

  /// Install-method tab label for the Windows PowerShell box (native installer).
  ///
  /// In en, this message translates to:
  /// **'native'**
  String get projectsOnboardingInstallWindowsMethod;

  /// Install-method tab label shared by both boxes (npm runner). Literal tool name 'npm'; do not translate.
  ///
  /// In en, this message translates to:
  /// **'npm'**
  String get projectsOnboardingInstallMethodNpm;

  /// Install-method tab label shared by both boxes (bun runner). Literal tool name 'bun'; do not translate.
  ///
  /// In en, this message translates to:
  /// **'bun'**
  String get projectsOnboardingInstallMethodBun;

  /// No description provided for @projectsOnboardingCommandCopied.
  ///
  /// In en, this message translates to:
  /// **'Command copied to clipboard'**
  String get projectsOnboardingCommandCopied;

  /// No description provided for @projectsOnboardingCopyCommand.
  ///
  /// In en, this message translates to:
  /// **'Copy command'**
  String get projectsOnboardingCopyCommand;

  /// Accessibility label for the button that opens the native share sheet with the selected install command.
  ///
  /// In en, this message translates to:
  /// **'Share command'**
  String get projectsOnboardingShareCommand;

  /// Caption shown beneath the connection graphic on the disconnected onboarding while the app waits for the bridge to come online.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the bridge...'**
  String get projectsOnboardingWaitingForBridge;

  /// Heading above the numbered install/start command steps on the disconnected onboarding, introducing the commands to run on the user's computer.
  ///
  /// In en, this message translates to:
  /// **'Next, run on your computer:'**
  String get projectsOnboardingRunOnComputer;

  /// Title of the first numbered onboarding step, rendered as '1. Install the bridge' above the install-command box.
  ///
  /// In en, this message translates to:
  /// **'Install the bridge'**
  String get projectsOnboardingInstallStepTitle;

  /// Popover text explaining what the 'Install the bridge' step does, opened from the info icon next to that step.
  ///
  /// In en, this message translates to:
  /// **'This adds the Sesori bridge command to your machine.'**
  String get projectsOnboardingInstallStepInfo;

  /// Title of the second numbered onboarding step, rendered as '2. Start the bridge' above the start-command box.
  ///
  /// In en, this message translates to:
  /// **'Start the bridge'**
  String get projectsOnboardingStartStepTitle;

  /// Popover text explaining the 'Start the bridge' step, opened from the info icon next to that step.
  ///
  /// In en, this message translates to:
  /// **'Leave it running while you use Sesori from your phone.'**
  String get projectsOnboardingStartStepInfo;

  /// Accessibility label for the info icon button next to an onboarding step title, which opens a popover explaining that step.
  ///
  /// In en, this message translates to:
  /// **'More information'**
  String get projectsOnboardingStepInfoSemantics;

  /// Status caption under the connection graphic on the bridge-offline Projects screen, rendered with a trailing crossed-circle icon.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get projectsBridgeOfflineDisconnected;

  /// No description provided for @projectsBridgeOfflineReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get projectsBridgeOfflineReconnect;

  /// Label for the disclosure on the bridge-offline Projects screen that expands to reveal the bridge install commands.
  ///
  /// In en, this message translates to:
  /// **'Install commands'**
  String get projectsBridgeOfflineInstallCommands;

  /// Label above the command box on the bridge-offline Projects screen that shows the command to start an already-installed bridge; carries a trailing info icon.
  ///
  /// In en, this message translates to:
  /// **'Start your bridge'**
  String get projectsBridgeOfflineStartBridge;

  /// Popover text explaining the 'Start your bridge' command on the bridge-offline Projects screen, opened from the info icon next to that label. Kept in the same untitled single-sentence style as the onboarding step popovers.
  ///
  /// In en, this message translates to:
  /// **'Leave it running while you use Sesori from your phone.'**
  String get projectsBridgeOfflineStartBridgeInfo;

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

  /// No description provided for @bridgeDisconnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Bridge disconnected'**
  String get bridgeDisconnectedTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccountSignedInWith.
  ///
  /// In en, this message translates to:
  /// **'Signed in with {provider}'**
  String settingsAccountSignedInWith(String provider);

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get settingsLogout;

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

  /// No description provided for @sessionListLoadingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Loading sessions'**
  String get sessionListLoadingSemantics;

  /// Headline on the sessions list when a project has no active sessions yet, inviting the user to begin.
  ///
  /// In en, this message translates to:
  /// **'Start your first task'**
  String get sessionListEmptyTitle;

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

  /// Label of the primary button on the sessions list that starts a new task (session).
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get sessionListNewTask;

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

  /// No description provided for @sessionDetailCommandArgumentsHint.
  ///
  /// In en, this message translates to:
  /// **'Optional arguments'**
  String get sessionDetailCommandArgumentsHint;

  /// No description provided for @sessionDetailCommandPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Slash commands'**
  String get sessionDetailCommandPickerTitle;

  /// No description provided for @sessionDetailCommandSearch.
  ///
  /// In en, this message translates to:
  /// **'Search commands...'**
  String get sessionDetailCommandSearch;

  /// No description provided for @sessionDetailNoCommands.
  ///
  /// In en, this message translates to:
  /// **'No slash commands are available for this project.'**
  String get sessionDetailNoCommands;

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

  /// Text for the floating pill button that appears when the user scrolls up in the message list, allowing them to jump back to the newest messages.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get sessionDetailJumpToLatest;

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

  /// No description provided for @sessionDetailQueuedCommand.
  ///
  /// In en, this message translates to:
  /// **'Queued command'**
  String get sessionDetailQueuedCommand;

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

  /// No description provided for @sessionDetailPickerVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get sessionDetailPickerVariant;

  /// No description provided for @sessionDetailVariantDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get sessionDetailVariantDefault;

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

  /// No description provided for @sessionListMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get sessionListMarkRead;

  /// No description provided for @sessionListMarkUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark as unread'**
  String get sessionListMarkUnread;

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
  /// **'Welcome to'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sesori'**
  String get loginSubtitle;

  /// No description provided for @loginAgreementText.
  ///
  /// In en, this message translates to:
  /// **'By signing in, you accept our [Terms of Use](https://sesori.com/terms) and [Privacy Policy](https://sesori.com/privacy).'**
  String get loginAgreementText;

  /// No description provided for @loginWithGithub.
  ///
  /// In en, this message translates to:
  /// **'Sign in with GitHub'**
  String get loginWithGithub;

  /// No description provided for @appleIdTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'Apple Sign-In failed. Please try again.'**
  String get appleIdTokenMissing;

  /// No description provided for @loginWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get loginWithApple;

  /// No description provided for @loginWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get loginWithGoogle;

  /// No description provided for @signInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Email'**
  String get signInWithEmail;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get emailInvalid;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @loginAuthenticationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get loginAuthenticationFailedTitle;

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

  /// No description provided for @loginPolling.
  ///
  /// In en, this message translates to:
  /// **'Confirm the sign-in in your browser to continue.'**
  String get loginPolling;

  /// No description provided for @loginTimeout.
  ///
  /// In en, this message translates to:
  /// **'Authorization timed out. Please try again.'**
  String get loginTimeout;

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

  /// Label shown next to the red dot for sessions that are active but in a retry/error state
  ///
  /// In en, this message translates to:
  /// **'Running (retrying)'**
  String get sessionListRunningRetrying;

  /// Label shown next to the amber dot for sessions that are waiting for user input (question or permission)
  ///
  /// In en, this message translates to:
  /// **'Awaiting input'**
  String get sessionListAwaitingInput;

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

  /// No description provided for @fetchDirectoryRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get fetchDirectoryRetry;

  /// No description provided for @fetchDirectoryGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get fetchDirectoryGoBack;

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

  /// No description provided for @projectHideFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to hide project'**
  String get projectHideFailed;

  /// No description provided for @hideProject.
  ///
  /// In en, this message translates to:
  /// **'Hide Project'**
  String get hideProject;

  /// Status shown on a project row whose folder no longer exists on disk. The row is greyed out and cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get projectFolderMissing;

  /// No description provided for @projectFolderMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'This project\'s folder no longer exists — it may have been moved or deleted. Hide the project, or restore the folder to its original location.'**
  String get projectFolderMissingMessage;

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

  /// No description provided for @fetchDirectoryPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'The bridge can\'t access this folder. On macOS, grant Full Disk Access to the terminal running the bridge in System Settings → Privacy & Security → Full Disk Access, then retry.'**
  String get fetchDirectoryPermissionDenied;

  /// No description provided for @addProjectPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'The bridge can\'t access that folder. Grant the terminal running the bridge Full Disk Access on your Mac, then try again.'**
  String get addProjectPermissionDenied;

  /// No description provided for @filesystemAccessDegradedTitle.
  ///
  /// In en, this message translates to:
  /// **'Limited folder access'**
  String get filesystemAccessDegradedTitle;

  /// No description provided for @filesystemAccessDegradedBody.
  ///
  /// In en, this message translates to:
  /// **'The bridge can\'t read some folders. On macOS, grant Full Disk Access to the terminal running the bridge in System Settings → Privacy & Security.'**
  String get filesystemAccessDegradedBody;

  /// No description provided for @questionReplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send answer. Please try again.'**
  String get questionReplyFailed;

  /// No description provided for @questionRejectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject question. Please try again.'**
  String get questionRejectFailed;

  /// No description provided for @permissionReplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send permission response. Please try again.'**
  String get permissionReplyFailed;

  /// No description provided for @permissionBannerSingle.
  ///
  /// In en, this message translates to:
  /// **'1 permission request pending'**
  String get permissionBannerSingle;

  /// No description provided for @permissionBannerMultiple.
  ///
  /// In en, this message translates to:
  /// **'{count} permission requests pending'**
  String permissionBannerMultiple(int count);

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Session'**
  String get renameSessionTitle;

  /// No description provided for @renameProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Project'**
  String get renameProjectTitle;

  /// No description provided for @renameSessionHint.
  ///
  /// In en, this message translates to:
  /// **'Session title'**
  String get renameSessionHint;

  /// No description provided for @renameProjectHint.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get renameProjectHint;

  /// No description provided for @renameSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get renameSave;

  /// No description provided for @renameSessionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Session renamed'**
  String get renameSessionSuccess;

  /// No description provided for @renameProjectSuccess.
  ///
  /// In en, this message translates to:
  /// **'Project renamed'**
  String get renameProjectSuccess;

  /// No description provided for @renameSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename session'**
  String get renameSessionFailed;

  /// No description provided for @renameProjectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename project'**
  String get renameProjectFailed;

  /// No description provided for @newSessionDedicatedWorktree.
  ///
  /// In en, this message translates to:
  /// **'Dedicated worktree'**
  String get newSessionDedicatedWorktree;

  /// No description provided for @newSessionDedicatedWorktreeDescription.
  ///
  /// In en, this message translates to:
  /// **'Creates a dedicated git worktree and branch for this session'**
  String get newSessionDedicatedWorktreeDescription;

  /// No description provided for @sessionListDeleteWorktreeCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Delete worktree'**
  String get sessionListDeleteWorktreeCheckbox;

  /// No description provided for @sessionListDeleteBranchCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Delete branch'**
  String get sessionListDeleteBranchCheckbox;

  /// No description provided for @sessionListArchiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive session?'**
  String get sessionListArchiveConfirmTitle;

  /// No description provided for @sessionListArchiveConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This session will be archived and hidden from the active list.'**
  String get sessionListArchiveConfirmMessage;

  /// No description provided for @sessionListArchiveConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get sessionListArchiveConfirmAction;

  /// No description provided for @sessionListForceDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Force delete?'**
  String get sessionListForceDeleteTitle;

  /// No description provided for @sessionListForceArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Force archive?'**
  String get sessionListForceArchiveTitle;

  /// No description provided for @sessionListForceMessage.
  ///
  /// In en, this message translates to:
  /// **'The following issues were found:'**
  String get sessionListForceMessage;

  /// No description provided for @sessionListForceDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Force Delete'**
  String get sessionListForceDeleteAction;

  /// No description provided for @sessionListForceArchiveAction.
  ///
  /// In en, this message translates to:
  /// **'Force Archive'**
  String get sessionListForceArchiveAction;

  /// No description provided for @sessionListCleanupIssueUnstagedChanges.
  ///
  /// In en, this message translates to:
  /// **'Worktree has unstaged changes'**
  String get sessionListCleanupIssueUnstagedChanges;

  /// No description provided for @sessionListCleanupIssueSharedWorktree.
  ///
  /// In en, this message translates to:
  /// **'Another active session uses this worktree'**
  String get sessionListCleanupIssueSharedWorktree;

  /// No description provided for @sessionListCleanupIssueBranchMismatch.
  ///
  /// In en, this message translates to:
  /// **'Worktree is on branch \'{actual}\' instead of expected \'{expected}\''**
  String sessionListCleanupIssueBranchMismatch(String actual, String expected);

  /// No description provided for @sessionListDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete session'**
  String get sessionListDeleteFailed;

  /// No description provided for @sessionListArchiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to archive session'**
  String get sessionListArchiveFailed;

  /// No description provided for @prLabel.
  ///
  /// In en, this message translates to:
  /// **'PR #{number}'**
  String prLabel(int number);

  /// No description provided for @prStateOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get prStateOpen;

  /// No description provided for @prStateMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get prStateMerged;

  /// No description provided for @prStateClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get prStateClosed;

  /// No description provided for @prReviewApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get prReviewApproved;

  /// No description provided for @prReviewChangesRequested.
  ///
  /// In en, this message translates to:
  /// **'Changes requested'**
  String get prReviewChangesRequested;

  /// No description provided for @prReviewRequired.
  ///
  /// In en, this message translates to:
  /// **'Review required'**
  String get prReviewRequired;

  /// No description provided for @prChecksSuccess.
  ///
  /// In en, this message translates to:
  /// **'Checks passing'**
  String get prChecksSuccess;

  /// No description provided for @prChecksFailing.
  ///
  /// In en, this message translates to:
  /// **'Checks failing'**
  String get prChecksFailing;

  /// No description provided for @prChecksPending.
  ///
  /// In en, this message translates to:
  /// **'Checks pending'**
  String get prChecksPending;

  /// No description provided for @prMergeable.
  ///
  /// In en, this message translates to:
  /// **'Ready to merge'**
  String get prMergeable;

  /// No description provided for @prConflicting.
  ///
  /// In en, this message translates to:
  /// **'Has merge conflicts'**
  String get prConflicting;

  /// No description provided for @diffPermissionRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Request'**
  String get diffPermissionRequestTitle;

  /// No description provided for @diffPermissionReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get diffPermissionReject;

  /// No description provided for @diffPermissionOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get diffPermissionOnce;

  /// No description provided for @diffPermissionAlwaysAllow.
  ///
  /// In en, this message translates to:
  /// **'Always Allow'**
  String get diffPermissionAlwaysAllow;

  /// No description provided for @diffFileChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'File Changes'**
  String get diffFileChangesTitle;

  /// No description provided for @diffFilesChangedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} file{count, plural, =1{} other{s}} changed  +{additions} -{deletions}'**
  String diffFilesChangedCount(int count, int additions, int deletions);

  /// No description provided for @diffNoFileChanges.
  ///
  /// In en, this message translates to:
  /// **'No file changes in this session'**
  String get diffNoFileChanges;

  /// No description provided for @diffErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String diffErrorPrefix(String message);

  /// No description provided for @diffRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get diffRetry;

  /// No description provided for @newSessionLoadingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Creating session'**
  String get newSessionLoadingSemantics;

  /// No description provided for @newSessionLoadingMessage1.
  ///
  /// In en, this message translates to:
  /// **'Warming up the engines…'**
  String get newSessionLoadingMessage1;

  /// No description provided for @newSessionLoadingMessage2.
  ///
  /// In en, this message translates to:
  /// **'Generating session telemetry…'**
  String get newSessionLoadingMessage2;

  /// No description provided for @newSessionLoadingMessage3.
  ///
  /// In en, this message translates to:
  /// **'Preparing for takeoff…'**
  String get newSessionLoadingMessage3;

  /// No description provided for @newSessionLaunchingInBackground.
  ///
  /// In en, this message translates to:
  /// **'Your new session will appear in the list once it\'s launched'**
  String get newSessionLaunchingInBackground;

  /// No description provided for @commandSourceCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get commandSourceCommand;

  /// No description provided for @commandSourceMcp.
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get commandSourceMcp;

  /// No description provided for @commandSourceSkill.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get commandSourceSkill;

  /// No description provided for @commandSourceCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get commandSourceCustom;

  /// No description provided for @sessionDetailFileChangesTooltip.
  ///
  /// In en, this message translates to:
  /// **'File changes'**
  String get sessionDetailFileChangesTooltip;

  /// No description provided for @diffBinaryFileChanged.
  ///
  /// In en, this message translates to:
  /// **'Binary file changed'**
  String get diffBinaryFileChanged;

  /// No description provided for @diffFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File diff too large to display'**
  String get diffFileTooLarge;

  /// No description provided for @diffCouldNotReadFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read file'**
  String get diffCouldNotReadFile;

  /// No description provided for @timestampJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timestampJustNow;

  /// No description provided for @timestampMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timestampMinutesAgo(int minutes);

  /// No description provided for @timestampHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timestampHoursAgo(int hours);

  /// No description provided for @timestampDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timestampDaysAgo(int days);

  /// No description provided for @sessionDetailModelFallback.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get sessionDetailModelFallback;

  /// No description provided for @sessionDetailAgentFallback.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get sessionDetailAgentFallback;

  /// No description provided for @sessionDetailRetryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sessionDetailRetryLabel;

  /// No description provided for @sessionDetailCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get sessionDetailCopy;

  /// No description provided for @sessionDetailShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get sessionDetailShowMore;

  /// No description provided for @sessionDetailShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get sessionDetailShowLess;

  /// No description provided for @emptySessionDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a session'**
  String get emptySessionDetailTitle;

  /// No description provided for @emptySessionDetailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a session from the list to view details'**
  String get emptySessionDetailSubtitle;

  /// Headline line of the onboarding 'Why is this needed?' sheet, explaining that the AI model runs on the developer's own machine.
  ///
  /// In en, this message translates to:
  /// **'Your LLM of choice runs on your computer.'**
  String get projectsOnboardingWhyLede;

  /// Supporting line under the 'Why is this needed?' headline, explaining the Bridge's role.
  ///
  /// In en, this message translates to:
  /// **'The Bridge securely connects it to Sesori on your phone.'**
  String get projectsOnboardingWhyBody;

  /// Title of the 'secure access' reassurance row in the 'Why is this needed?' sheet.
  ///
  /// In en, this message translates to:
  /// **'Secure access'**
  String get projectsOnboardingWhySecureTitle;

  /// Subtitle of the 'secure access' reassurance row.
  ///
  /// In en, this message translates to:
  /// **'Your sessions are end-to-end encrypted.'**
  String get projectsOnboardingWhySecureSubtitle;

  /// Title of the 'connect from anywhere' reassurance row in the 'Why is this needed?' sheet.
  ///
  /// In en, this message translates to:
  /// **'Connect from anywhere'**
  String get projectsOnboardingWhyAnywhereTitle;

  /// Subtitle of the 'connect from anywhere' reassurance row.
  ///
  /// In en, this message translates to:
  /// **'No shared Wi-Fi required.'**
  String get projectsOnboardingWhyAnywhereSubtitle;

  /// Title of the 'get notified' reassurance row in the 'Why is this needed?' sheet.
  ///
  /// In en, this message translates to:
  /// **'Get notified'**
  String get projectsOnboardingWhyNotifiedTitle;

  /// Subtitle of the 'get notified' reassurance row.
  ///
  /// In en, this message translates to:
  /// **'Know when a task needs you.'**
  String get projectsOnboardingWhyNotifiedSubtitle;

  /// Section header above the FAQ list in the 'Why is this needed?' sheet.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get projectsOnboardingWhyFaqHeader;

  /// FAQ question about why the phone cannot reach the computer without the Bridge.
  ///
  /// In en, this message translates to:
  /// **'Why can\'t the app connect directly?'**
  String get projectsOnboardingWhyFaqDirectQuestion;

  /// DRAFT copy pending final wording. Answer to the 'connect directly' FAQ question.
  ///
  /// In en, this message translates to:
  /// **'Your AI assistant runs on your computer, not our servers. The Bridge is the secure link that lets your phone reach it from anywhere.'**
  String get projectsOnboardingWhyFaqDirectAnswer;

  /// FAQ question about whether the developer's computer must stay powered on.
  ///
  /// In en, this message translates to:
  /// **'Does my PC stay on?'**
  String get projectsOnboardingWhyFaqPcOnQuestion;

  /// DRAFT copy pending final wording. Answer to the 'does my PC stay on' FAQ question.
  ///
  /// In en, this message translates to:
  /// **'Your computer needs to be on and running Sesori for live sessions. You can start or stop it whenever you like.'**
  String get projectsOnboardingWhyFaqPcOnAnswer;

  /// FAQ question about whether Sesori can read the developer's session data.
  ///
  /// In en, this message translates to:
  /// **'Can Sesori read my sessions?'**
  String get projectsOnboardingWhyFaqReadQuestion;

  /// DRAFT copy pending final wording. Answer to the 'can Sesori read my sessions' FAQ question.
  ///
  /// In en, this message translates to:
  /// **'No. Everything between your phone and computer is end-to-end encrypted — the relay only passes along sealed data it can\'t read.'**
  String get projectsOnboardingWhyFaqReadAnswer;
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
