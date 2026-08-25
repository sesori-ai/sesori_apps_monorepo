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

  /// Message under the folders graphic on the connected-but-empty Projects screen.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any projects created or opened yet.'**
  String get projectsEmptyMessage;

  /// Label of the button on the connected-but-empty Projects screen that opens the Add Project sheet.
  ///
  /// In en, this message translates to:
  /// **'Open new project'**
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

  /// Status caption under the machine name on the bridge-offline Projects screen, used when the bridge has never reported a last-seen time.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get projectsBridgeOfflineDisconnected;

  /// Status caption under the machine name on the bridge-offline Projects screen, pairing the disconnected state with when the bridge was last seen, e.g. 'Disconnected · 5h ago'. The placeholder is already-formatted text from the app's shared relative-time vocabulary (the same one the project rows use), which is compact for recent instants and becomes a plain date past the relative window.
  ///
  /// In en, this message translates to:
  /// **'Disconnected · {lastSeen}'**
  String projectsBridgeOfflineDisconnectedSince(String lastSeen);

  /// Label for the disclosure on the bridge-offline Projects screen that expands to reveal the bridge install commands.
  ///
  /// In en, this message translates to:
  /// **'Install commands'**
  String get projectsBridgeOfflineInstallCommands;

  /// Label above the command box on the bridge-offline Projects screen that shows the command to start an already-installed bridge; carries a trailing info icon.
  ///
  /// In en, this message translates to:
  /// **'Make sure the Bridge is running'**
  String get projectsBridgeOfflineStartBridge;

  /// Popover text explaining the start-the-bridge command on the bridge-offline Projects screen, opened from the info icon next to that label. Kept in the same untitled single-sentence style as the onboarding step popovers.
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

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsTitle;

  /// No description provided for @settingsHarnessesTitle.
  ///
  /// In en, this message translates to:
  /// **'Harnesses'**
  String get settingsHarnessesTitle;

  /// No description provided for @settingsSectionBridge.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get settingsSectionBridge;

  /// No description provided for @settingsYoloTitle.
  ///
  /// In en, this message translates to:
  /// **'YOLO mode'**
  String get settingsYoloTitle;

  /// No description provided for @settingsYoloWarning.
  ///
  /// In en, this message translates to:
  /// **'Automatically approves all permission requests. Use with caution.'**
  String get settingsYoloWarning;

  /// No description provided for @settingsYoloLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the bridge setting…'**
  String get settingsYoloLoading;

  /// No description provided for @settingsYoloDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Connect to a bridge to configure this setting.'**
  String get settingsYoloDisconnected;

  /// No description provided for @settingsYoloUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Update the connected bridge to configure this setting.'**
  String get settingsYoloUnsupported;

  /// No description provided for @settingsYoloLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the bridge setting. Check your connection and try again.'**
  String get settingsYoloLoadFailed;

  /// No description provided for @settingsYoloUncertain.
  ///
  /// In en, this message translates to:
  /// **'The update status is unknown. Refresh before trying again.'**
  String get settingsYoloUncertain;

  /// No description provided for @settingsYoloUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the bridge setting. Check your connection and try again.'**
  String get settingsYoloUpdateFailed;

  /// No description provided for @settingsYoloRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry YOLO setting'**
  String get settingsYoloRetry;

  /// No description provided for @settingsPullRequestRefreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull request refresh'**
  String get settingsPullRequestRefreshTitle;

  /// No description provided for @settingsPullRequestRefreshDescription.
  ///
  /// In en, this message translates to:
  /// **'How often viewed projects refresh pull request status.'**
  String get settingsPullRequestRefreshDescription;

  /// No description provided for @settingsPullRequestRefreshLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the bridge setting…'**
  String get settingsPullRequestRefreshLoading;

  /// No description provided for @settingsPullRequestRefreshDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Connect to a bridge to configure this setting.'**
  String get settingsPullRequestRefreshDisconnected;

  /// No description provided for @settingsPullRequestRefreshUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Update the connected bridge to configure this setting.'**
  String get settingsPullRequestRefreshUnsupported;

  /// No description provided for @settingsPullRequestRefreshLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the bridge setting. Check your connection and try again.'**
  String get settingsPullRequestRefreshLoadFailed;

  /// No description provided for @settingsPullRequestRefreshUncertain.
  ///
  /// In en, this message translates to:
  /// **'The update status is unknown. Refresh before trying again.'**
  String get settingsPullRequestRefreshUncertain;

  /// No description provided for @settingsPullRequestRefreshUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the bridge setting. Check your connection and try again.'**
  String get settingsPullRequestRefreshUpdateFailed;

  /// No description provided for @settingsPullRequestRefreshStateChanged.
  ///
  /// In en, this message translates to:
  /// **'The bridge setting changed while you were editing. Try again.'**
  String get settingsPullRequestRefreshStateChanged;

  /// No description provided for @settingsPullRequestRefreshUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get settingsPullRequestRefreshUnavailable;

  /// No description provided for @settingsPullRequestRefreshOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get settingsPullRequestRefreshOffline;

  /// No description provided for @settingsPullRequestRefreshRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry pull request refresh setting'**
  String get settingsPullRequestRefreshRetry;

  /// No description provided for @settingsPullRequestRefreshDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull request refresh interval'**
  String get settingsPullRequestRefreshDialogTitle;

  /// No description provided for @settingsPullRequestRefreshSecondsLabel.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get settingsPullRequestRefreshSecondsLabel;

  /// No description provided for @settingsPullRequestRefreshInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of seconds.'**
  String get settingsPullRequestRefreshInvalid;

  /// No description provided for @settingsPullRequestRefreshRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from {minimumSeconds} to {maximumSeconds}.'**
  String settingsPullRequestRefreshRangeInvalid(int minimumSeconds, int maximumSeconds);

  /// No description provided for @settingsPullRequestRefreshCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsPullRequestRefreshCancel;

  /// No description provided for @settingsPullRequestRefreshSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsPullRequestRefreshSave;

  /// No description provided for @settingsPullRequestRefreshSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second} other{{seconds} seconds}}'**
  String settingsPullRequestRefreshSeconds(int seconds);

  /// No description provided for @harnessManagementDescription.
  ///
  /// In en, this message translates to:
  /// **'Control the harnesses that support management through Sesori.'**
  String get harnessManagementDescription;

  /// No description provided for @harnessManagementDefaultsSection.
  ///
  /// In en, this message translates to:
  /// **'Bridge Default'**
  String get harnessManagementDefaultsSection;

  /// No description provided for @harnessManagementDefaultTimeout.
  ///
  /// In en, this message translates to:
  /// **'Default idle timeout'**
  String get harnessManagementDefaultTimeout;

  /// No description provided for @harnessManagementDefaultTimeoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Apply this timeout to every harness that supports idle-timeout control.'**
  String get harnessManagementDefaultTimeoutDescription;

  /// No description provided for @harnessManagementEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get harnessManagementEnabled;

  /// No description provided for @harnessManagementRefreshSetup.
  ///
  /// In en, this message translates to:
  /// **'Refresh setup'**
  String get harnessManagementRefreshSetup;

  /// No description provided for @harnessManagementInstall.
  ///
  /// In en, this message translates to:
  /// **'Install runtime'**
  String get harnessManagementInstall;

  /// No description provided for @harnessManagementInstallDescription.
  ///
  /// In en, this message translates to:
  /// **'Download this harness for Sesori only. Your system stays untouched.'**
  String get harnessManagementInstallDescription;

  /// No description provided for @harnessManagementInstallDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get harnessManagementInstallDownloading;

  /// No description provided for @harnessManagementInstallDownloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String harnessManagementInstallDownloadingPercent(int percent);

  /// No description provided for @harnessManagementInstallVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying download…'**
  String get harnessManagementInstallVerifying;

  /// No description provided for @harnessManagementInstallExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting…'**
  String get harnessManagementInstallExtracting;

  /// No description provided for @harnessManagementInstallFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing up…'**
  String get harnessManagementInstallFinishing;

  /// No description provided for @harnessManagementInstallInProgress.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get harnessManagementInstallInProgress;

  /// No description provided for @harnessManagementRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get harnessManagementRestart;

  /// No description provided for @harnessManagementIdleTimeout.
  ///
  /// In en, this message translates to:
  /// **'Idle timeout'**
  String get harnessManagementIdleTimeout;

  /// No description provided for @harnessManagementClearOverride.
  ///
  /// In en, this message translates to:
  /// **'Use bridge default'**
  String get harnessManagementClearOverride;

  /// No description provided for @harnessManagementExternalTitle.
  ///
  /// In en, this message translates to:
  /// **'Managed outside Sesori'**
  String get harnessManagementExternalTitle;

  /// No description provided for @harnessManagementExternalDescription.
  ///
  /// In en, this message translates to:
  /// **'This harness process is controlled externally. Sesori will not start, stop, restart, or suspend it.'**
  String get harnessManagementExternalDescription;

  /// No description provided for @harnessManagementDefaultTimeoutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set default idle timeout'**
  String get harnessManagementDefaultTimeoutDialogTitle;

  /// No description provided for @harnessManagementTimeoutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set {harnessName} idle timeout'**
  String harnessManagementTimeoutDialogTitle(String harnessName);

  /// No description provided for @harnessManagementTimeoutMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get harnessManagementTimeoutMinutesLabel;

  /// No description provided for @harnessManagementTimeoutUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use bridge default'**
  String get harnessManagementTimeoutUseDefault;

  /// No description provided for @harnessManagementTimeoutNoTimeout.
  ///
  /// In en, this message translates to:
  /// **'No timeout'**
  String get harnessManagementTimeoutNoTimeout;

  /// No description provided for @harnessManagementTimeoutCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get harnessManagementTimeoutCustom;

  /// No description provided for @harnessManagementTimeoutHelp.
  ///
  /// In en, this message translates to:
  /// **'Custom timeouts must be a whole number greater than zero.'**
  String get harnessManagementTimeoutHelp;

  /// No description provided for @harnessManagementCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get harnessManagementCancel;

  /// No description provided for @harnessManagementSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get harnessManagementSave;

  /// No description provided for @harnessManagementForceDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Force disable harness?'**
  String get harnessManagementForceDisableTitle;

  /// No description provided for @harnessManagementForceRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Force restart harness?'**
  String get harnessManagementForceRestartTitle;

  /// No description provided for @harnessManagementForceDescription.
  ///
  /// In en, this message translates to:
  /// **'Active work may be interrupted. This action is sent once and cannot be undone.'**
  String get harnessManagementForceDescription;

  /// No description provided for @harnessManagementForceAction.
  ///
  /// In en, this message translates to:
  /// **'Force action'**
  String get harnessManagementForceAction;

  /// No description provided for @harnessManagementActionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Harness action failed'**
  String get harnessManagementActionFailedTitle;

  /// No description provided for @harnessManagementDismissActionError.
  ///
  /// In en, this message translates to:
  /// **'Dismiss action error'**
  String get harnessManagementDismissActionError;

  /// No description provided for @harnessManagementInvalidTimeout.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number greater than zero.'**
  String get harnessManagementInvalidTimeout;

  /// No description provided for @harnessManagementNotFound.
  ///
  /// In en, this message translates to:
  /// **'The harness is no longer registered on this bridge.'**
  String get harnessManagementNotFound;

  /// No description provided for @harnessManagementConflict.
  ///
  /// In en, this message translates to:
  /// **'The bridge rejected the action because the harness state changed.'**
  String get harnessManagementConflict;

  /// No description provided for @harnessManagementUncertain.
  ///
  /// In en, this message translates to:
  /// **'The connection changed before the result could be confirmed. Refresh before trying again.'**
  String get harnessManagementUncertain;

  /// No description provided for @harnessManagementRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get harnessManagementRequestFailed;

  /// No description provided for @harnessAuthenticationLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get harnessAuthenticationLogIn;

  /// No description provided for @harnessAuthenticationContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue login'**
  String get harnessAuthenticationContinue;

  /// No description provided for @harnessAuthenticationDescription.
  ///
  /// In en, this message translates to:
  /// **'Authorize this harness from your phone.'**
  String get harnessAuthenticationDescription;

  /// No description provided for @harnessAuthenticationSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to harness'**
  String get harnessAuthenticationSheetTitle;

  /// No description provided for @harnessAuthenticationSecurityDescription.
  ///
  /// In en, this message translates to:
  /// **'Only continue if you started this login. Sesori will open the harness provider\'s secure website; verify the address before entering the code.'**
  String get harnessAuthenticationSecurityDescription;

  /// No description provided for @harnessAuthenticationSecuritySemantics.
  ///
  /// In en, this message translates to:
  /// **'Security notice. Only continue if you started this login. Verify the website address before entering the code.'**
  String get harnessAuthenticationSecuritySemantics;

  /// No description provided for @harnessAuthenticationCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'One-time code'**
  String get harnessAuthenticationCodeLabel;

  /// No description provided for @harnessAuthenticationCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy one-time code'**
  String get harnessAuthenticationCopyCode;

  /// No description provided for @harnessAuthenticationCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get harnessAuthenticationCodeCopied;

  /// No description provided for @harnessAuthenticationWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for authorization on the bridge…'**
  String get harnessAuthenticationWaiting;

  /// No description provided for @harnessAuthenticationOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open secure website'**
  String get harnessAuthenticationOpenBrowser;

  /// No description provided for @harnessAuthenticationCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel login'**
  String get harnessAuthenticationCancel;

  /// No description provided for @harnessAuthenticationCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get harnessAuthenticationCancelling;

  /// No description provided for @harnessAuthenticationCancellingUncertain.
  ///
  /// In en, this message translates to:
  /// **'Cancellation was sent, but the response was lost. Waiting for the bridge to confirm…'**
  String get harnessAuthenticationCancellingUncertain;

  /// No description provided for @harnessAuthenticationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Harness login failed'**
  String get harnessAuthenticationFailedTitle;

  /// No description provided for @harnessAuthenticationDismissError.
  ///
  /// In en, this message translates to:
  /// **'Dismiss login error'**
  String get harnessAuthenticationDismissError;

  /// No description provided for @harnessAuthenticationNotFound.
  ///
  /// In en, this message translates to:
  /// **'The harness is no longer registered on this bridge.'**
  String get harnessAuthenticationNotFound;

  /// No description provided for @harnessAuthenticationUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Update the connected bridge to log in from this device.'**
  String get harnessAuthenticationUnsupported;

  /// No description provided for @harnessAuthenticationConflict.
  ///
  /// In en, this message translates to:
  /// **'The harness is busy with another management action. Refresh before trying again.'**
  String get harnessAuthenticationConflict;

  /// No description provided for @harnessAuthenticationUncertain.
  ///
  /// In en, this message translates to:
  /// **'The connection changed before the result could be confirmed. Refresh before trying again.'**
  String get harnessAuthenticationUncertain;

  /// No description provided for @harnessAuthenticationInvalidChallenge.
  ///
  /// In en, this message translates to:
  /// **'The bridge returned an invalid login website. Check the bridge logs for details.'**
  String get harnessAuthenticationInvalidChallenge;

  /// No description provided for @harnessAuthenticationBrowserFailed.
  ///
  /// In en, this message translates to:
  /// **'The secure website could not be opened. Copy the code and try again.'**
  String get harnessAuthenticationBrowserFailed;

  /// No description provided for @harnessAuthenticationRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get harnessAuthenticationRequestFailed;

  /// No description provided for @harnessesRegisteredSection.
  ///
  /// In en, this message translates to:
  /// **'Registered Harnesses'**
  String get harnessesRegisteredSection;

  /// No description provided for @harnessesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No harnesses registered'**
  String get harnessesEmptyTitle;

  /// No description provided for @harnessesEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'The connected bridge hasn\'t registered any coding harnesses.'**
  String get harnessesEmptyDescription;

  /// No description provided for @harnessesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading harnesses'**
  String get harnessesLoading;

  /// No description provided for @harnessesUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Harnesses aren\'t supported'**
  String get harnessesUnsupportedTitle;

  /// No description provided for @harnessesUnsupportedDescription.
  ///
  /// In en, this message translates to:
  /// **'Update the connected bridge to view and manage its harnesses.'**
  String get harnessesUnsupportedDescription;

  /// No description provided for @harnessesLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load harnesses'**
  String get harnessesLoadFailedTitle;

  /// No description provided for @harnessesLoadFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get harnessesLoadFailedDescription;

  /// No description provided for @harnessesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get harnessesRetry;

  /// No description provided for @harnessesRefreshFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh harnesses'**
  String get harnessesRefreshFailedTitle;

  /// No description provided for @harnessesRefreshFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Showing the last information received from the bridge.'**
  String get harnessesRefreshFailedDescription;

  /// No description provided for @harnessesDismissRefreshError.
  ///
  /// In en, this message translates to:
  /// **'Dismiss refresh error'**
  String get harnessesDismissRefreshError;

  /// No description provided for @harnessesDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get harnessesDefaultBadge;

  /// No description provided for @harnessesSetupStatus.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get harnessesSetupStatus;

  /// No description provided for @harnessesRuntimeVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get harnessesRuntimeVersion;

  /// No description provided for @harnessesRuntimeStatus.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get harnessesRuntimeStatus;

  /// No description provided for @harnessesWorkStatus.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get harnessesWorkStatus;

  /// No description provided for @harnessesCustomIdleTimeout.
  ///
  /// In en, this message translates to:
  /// **'Custom for this harness'**
  String get harnessesCustomIdleTimeout;

  /// No description provided for @harnessesUsesDefaultIdleTimeout.
  ///
  /// In en, this message translates to:
  /// **'Uses the bridge default'**
  String get harnessesUsesDefaultIdleTimeout;

  /// No description provided for @harnessesNoIdleTimeout.
  ///
  /// In en, this message translates to:
  /// **'No timeout'**
  String get harnessesNoIdleTimeout;

  /// No description provided for @harnessesNoIdleTimeoutDescription.
  ///
  /// In en, this message translates to:
  /// **'This harness stays running'**
  String get harnessesNoIdleTimeoutDescription;

  /// No description provided for @harnessesIdleTimeoutMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String harnessesIdleTimeoutMinutes(int minutes);

  /// No description provided for @harnessesSetupNotInspected.
  ///
  /// In en, this message translates to:
  /// **'Not inspected'**
  String get harnessesSetupNotInspected;

  /// No description provided for @harnessesSetupReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get harnessesSetupReady;

  /// No description provided for @harnessesSetupRuntimeMissing.
  ///
  /// In en, this message translates to:
  /// **'Runtime missing'**
  String get harnessesSetupRuntimeMissing;

  /// No description provided for @harnessesSetupAuthenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get harnessesSetupAuthenticationRequired;

  /// No description provided for @harnessesSetupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get harnessesSetupUnavailable;

  /// No description provided for @harnessesStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get harnessesStatusDisabled;

  /// No description provided for @harnessesStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get harnessesStatusBlocked;

  /// No description provided for @harnessesStatusDormant.
  ///
  /// In en, this message translates to:
  /// **'Dormant'**
  String get harnessesStatusDormant;

  /// No description provided for @harnessesStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get harnessesStatusStarting;

  /// No description provided for @harnessesStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get harnessesStatusActive;

  /// No description provided for @harnessesStatusDegraded.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get harnessesStatusDegraded;

  /// No description provided for @harnessesStatusStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get harnessesStatusStopping;

  /// No description provided for @harnessesStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get harnessesStatusFailed;

  /// No description provided for @harnessesStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get harnessesStatusUnknown;

  /// No description provided for @harnessesWorkIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get harnessesWorkIdle;

  /// No description provided for @harnessesWorkBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get harnessesWorkBusy;

  /// No description provided for @settingsProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfileTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get settingsSectionAnalytics;

  /// No description provided for @settingsBasicUsageAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Basic Usage Analytics'**
  String get settingsBasicUsageAnalyticsTitle;

  /// No description provided for @settingsBasicUsageAnalyticsDescription.
  ///
  /// In en, this message translates to:
  /// **'Share basic feature usage — never your code or messages.'**
  String get settingsBasicUsageAnalyticsDescription;

  /// No description provided for @settingsBasicUsageAnalyticsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading preference…'**
  String get settingsBasicUsageAnalyticsLoading;

  /// No description provided for @settingsBasicUsageAnalyticsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving preference…'**
  String get settingsBasicUsageAnalyticsSaving;

  /// No description provided for @settingsBasicUsageAnalyticsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Analytics preference failed to load.'**
  String get settingsBasicUsageAnalyticsLoadFailed;

  /// No description provided for @settingsBasicUsageAnalyticsSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync preference.'**
  String get settingsBasicUsageAnalyticsSyncFailed;

  /// No description provided for @settingsBasicUsageAnalyticsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry preference sync'**
  String get settingsBasicUsageAnalyticsRetry;

  /// Theme option that always renders the app in the light theme
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceLight;

  /// Theme option that always renders the app in the dark theme
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsAppearanceDark;

  /// Theme option that follows the device appearance setting
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsAppearanceSystem;

  /// Settings entry and page title for choosing the default session composer input
  ///
  /// In en, this message translates to:
  /// **'Default input'**
  String get settingsDefaultInputTitle;

  /// Default input option that leads with voice dictation
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get settingsDefaultInputVoice;

  /// Default input option that leads with typed text
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get settingsDefaultInputText;

  /// Placeholder shown in the typed-input preview
  ///
  /// In en, this message translates to:
  /// **'Ask Sesori'**
  String get settingsDefaultInputTextPreview;

  /// No description provided for @settingsSectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSectionSupport;

  /// No description provided for @settingsSupportEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsSupportEmail;

  /// No description provided for @settingsSupportDiscord.
  ///
  /// In en, this message translates to:
  /// **'Discord'**
  String get settingsSupportDiscord;

  /// No description provided for @settingsSupportX.
  ///
  /// In en, this message translates to:
  /// **'DM on X'**
  String get settingsSupportX;

  /// No description provided for @settingsSectionLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsSectionLegal;

  /// No description provided for @settingsLegalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsLegalTerms;

  /// No description provided for @settingsLegalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsLegalPrivacy;

  /// Button that re-fetches a legal document after the load failed
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get legalDocumentRetry;

  /// No description provided for @settingsClose.
  ///
  /// In en, this message translates to:
  /// **'Close settings'**
  String get settingsClose;

  /// Product name shown under the app icon in the settings footer. Brand name; do not translate.
  ///
  /// In en, this message translates to:
  /// **'Sesori'**
  String get settingsAppName;

  /// App version footer at the bottom of the settings screen
  ///
  /// In en, this message translates to:
  /// **'v{version} ({buildNumber})'**
  String settingsVersion(String version, String buildNumber);

  /// No description provided for @notificationSectionAi.
  ///
  /// In en, this message translates to:
  /// **'AI Notifications'**
  String get notificationSectionAi;

  /// No description provided for @notificationSectionSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notificationSectionSystem;

  /// No description provided for @notificationPreferencesUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences unavailable'**
  String get notificationPreferencesUnavailableTitle;

  /// No description provided for @notificationPreferencesUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage notification preferences.'**
  String get notificationPreferencesUnavailableDescription;

  /// No description provided for @notificationPreferencesLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notification preferences'**
  String get notificationPreferencesLoadFailedTitle;

  /// No description provided for @notificationPreferencesLoadFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get notificationPreferencesLoadFailedDescription;

  /// No description provided for @notificationPreferencesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get notificationPreferencesRetry;

  /// No description provided for @notificationPreferenceUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating notification preference'**
  String get notificationPreferenceUpdating;

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

  /// No description provided for @sessionListTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionListTitle;

  /// Screen-reader label for the sessions-list bar subtitle row, which opens a popover with the untruncated repository name.
  ///
  /// In en, this message translates to:
  /// **'Show full repository name'**
  String get sessionListRepoInfoSemantics;

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

  /// No description provided for @sessionDetailLoadingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Loading session'**
  String get sessionDetailLoadingSemantics;

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

  /// Label centered in the fresh-session composer pill; holding it records a voice message that is transcribed into the field.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get sessionDetailHoldToTalk;

  /// Composer placeholder once the session already has messages.
  ///
  /// In en, this message translates to:
  /// **'Follow up...'**
  String get sessionDetailFollowUpHint;

  /// Label of the voice-first composer's hold-to-record area once the field already holds text; holding it appends more transcribed speech.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk more'**
  String get sessionDetailHoldToTalkMore;

  /// Accessibility label of the keyboard button that switches the composer from hold-to-talk to typing.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get sessionDetailTypeMessage;

  /// Accessibility label of the chevron that expands the composer's advanced-options drawer.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get sessionDetailMoreActions;

  /// Accessibility label of the chevron while the composer's advanced-options drawer is open and tapping it collapses the drawer.
  ///
  /// In en, this message translates to:
  /// **'Hide actions'**
  String get sessionDetailHideActions;

  /// Accessibility label of the advanced-options action that opens the gallery picker to attach an image to the next message.
  ///
  /// In en, this message translates to:
  /// **'Attach image'**
  String get sessionDetailAttachImage;

  /// Accessibility label of the badge on a staged attachment thumbnail that removes it from the composer.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get sessionDetailRemoveAttachment;

  /// Fallback accessibility label of a staged attachment thumbnail when the image has no filename.
  ///
  /// In en, this message translates to:
  /// **'Attached image'**
  String get sessionDetailAttachedImage;

  /// Byte size shown in a transcript attachment metadata overlay.
  ///
  /// In en, this message translates to:
  /// **'{count} bytes'**
  String sessionDetailAttachmentSizeBytes(int count);

  /// Snackbar shown when a picked image exceeds the inline attachment size limit.
  ///
  /// In en, this message translates to:
  /// **'That image is too large to attach.'**
  String get sessionDetailAttachmentTooLarge;

  /// Snackbar shown when the gallery picker fails for a reason other than the size limit.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t attach the image.'**
  String get sessionDetailAttachmentPickFailed;

  /// Snackbar shown when the picked file is not a recognized image format and cannot be attached.
  ///
  /// In en, this message translates to:
  /// **'That image format isn\'t supported.'**
  String get sessionDetailAttachmentUnsupported;

  /// Snackbar shown when adding another image would push the message's combined attachment size past the outbound composer limit.
  ///
  /// In en, this message translates to:
  /// **'Attached images are limited to 50 MB per message.'**
  String get sessionDetailAttachmentBudgetExceeded;

  /// Snackbar shown when sending while both a slash command and image attachments are staged; the backend command paths carry only text, so the send is refused instead of silently dropping the images.
  ///
  /// In en, this message translates to:
  /// **'Images can\'t be sent with slash commands.'**
  String get sessionDetailAttachmentsNotWithCommands;

  /// Body of a queued-message bubble whose submission has image attachments but no text, e.g. '1 image'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 image} other{{count} images}}'**
  String sessionDetailQueuedAttachmentCount(int count);

  /// Accessibility label of the button that opens the fullscreen message editor.
  ///
  /// In en, this message translates to:
  /// **'Expand editor'**
  String get sessionDetailExpandEditor;

  /// Title of the fullscreen message editor sheet.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get sessionDetailEditorTitle;

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

  /// No description provided for @sessionDetailImageOpen.
  ///
  /// In en, this message translates to:
  /// **'Open image'**
  String get sessionDetailImageOpen;

  /// No description provided for @sessionDetailImageClose.
  ///
  /// In en, this message translates to:
  /// **'Close image'**
  String get sessionDetailImageClose;

  /// No description provided for @sessionDetailImageShare.
  ///
  /// In en, this message translates to:
  /// **'Share image'**
  String get sessionDetailImageShare;

  /// No description provided for @sessionDetailImageCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy image'**
  String get sessionDetailImageCopy;

  /// No description provided for @sessionDetailImageSave.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get sessionDetailImageSave;

  /// No description provided for @sessionDetailImageOpenOriginal.
  ///
  /// In en, this message translates to:
  /// **'Open original'**
  String get sessionDetailImageOpenOriginal;

  /// Message shown over a stored image thumbnail when loading or decoding its full-resolution original fails or is rejected.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the original image.'**
  String get sessionDetailImageOriginalLoadFailed;

  /// Accessible button label that retries loading and decoding the full-resolution stored image.
  ///
  /// In en, this message translates to:
  /// **'Retry original'**
  String get sessionDetailRetryOriginal;

  /// No description provided for @sessionDetailImageSaved.
  ///
  /// In en, this message translates to:
  /// **'Image saved'**
  String get sessionDetailImageSaved;

  /// No description provided for @sessionDetailImageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save image'**
  String get sessionDetailImageSaveFailed;

  /// No description provided for @sessionDetailImageShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t share image'**
  String get sessionDetailImageShareFailed;

  /// No description provided for @sessionDetailImageCopied.
  ///
  /// In en, this message translates to:
  /// **'Image copied to clipboard'**
  String get sessionDetailImageCopied;

  /// No description provided for @sessionDetailImageCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t copy image'**
  String get sessionDetailImageCopyFailed;

  /// No description provided for @sessionDetailImageSaveAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied while saving this image'**
  String get sessionDetailImageSaveAccessDenied;

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

  /// No description provided for @questionModalDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get questionModalDecline;

  /// No description provided for @questionModalDeclineAll.
  ///
  /// In en, this message translates to:
  /// **'Decline all'**
  String get questionModalDeclineAll;

  /// No description provided for @questionModalDeclineQuestion.
  ///
  /// In en, this message translates to:
  /// **'Decline this question'**
  String get questionModalDeclineQuestion;

  /// No description provided for @questionModalDeclineQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'The assistant will see it as unanswered.'**
  String get questionModalDeclineQuestionHint;

  /// No description provided for @questionModalQuestionDeclined.
  ///
  /// In en, this message translates to:
  /// **'Question declined'**
  String get questionModalQuestionDeclined;

  /// No description provided for @questionModalQuestionDeclinedHint.
  ///
  /// In en, this message translates to:
  /// **'Choose an answer to undo.'**
  String get questionModalQuestionDeclinedHint;

  /// No description provided for @questionModalDeclineAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline all questions?'**
  String get questionModalDeclineAllTitle;

  /// No description provided for @questionModalDeclineAllMessage.
  ///
  /// In en, this message translates to:
  /// **'None of your draft answers will be sent. Your coding session will remain active.'**
  String get questionModalDeclineAllMessage;

  /// No description provided for @questionModalKeepAnswering.
  ///
  /// In en, this message translates to:
  /// **'Keep answering'**
  String get questionModalKeepAnswering;

  /// No description provided for @questionModalCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Type your own answer'**
  String get questionModalCustomHint;

  /// No description provided for @questionModalSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit answers'**
  String get questionModalSubmit;

  /// No description provided for @questionModalNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get questionModalNext;

  /// No description provided for @questionModalResolveAll.
  ///
  /// In en, this message translates to:
  /// **'Answer or decline every question to submit.'**
  String get questionModalResolveAll;

  /// No description provided for @questionModalResolveAllCompact.
  ///
  /// In en, this message translates to:
  /// **'Answer or decline all'**
  String get questionModalResolveAllCompact;

  /// No description provided for @questionModalStatusUnanswered.
  ///
  /// In en, this message translates to:
  /// **'unanswered'**
  String get questionModalStatusUnanswered;

  /// No description provided for @questionModalStatusAnswered.
  ///
  /// In en, this message translates to:
  /// **'answered'**
  String get questionModalStatusAnswered;

  /// No description provided for @questionModalStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'declined'**
  String get questionModalStatusDeclined;

  /// No description provided for @questionModalStepIndicator.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionModalStepIndicator(int current, int total);

  /// No description provided for @questionModalStepSemantics.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}, {status}'**
  String questionModalStepSemantics(int current, int total, String status);

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

  /// No description provided for @sessionDetailSendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sessionDetailSendingMessage;

  /// No description provided for @sessionDetailPromptOptionsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Prompt options changed. Updated settings and retrying your message.'**
  String get sessionDetailPromptOptionsUpdated;

  /// No description provided for @sessionDetailPromptOptionsRecoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t apply updated prompt options. Your message remains queued.'**
  String get sessionDetailPromptOptionsRecoveryFailed;

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

  /// No description provided for @sessionDetailPickerVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get sessionDetailPickerVariant;

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

  /// No description provided for @sessionListDeleted.
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get sessionListDeleted;

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

  /// Accessibility label for the reveal toggle inside the password field.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get passwordShow;

  /// Accessibility label for the toggle that re-masks the password field.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get passwordHide;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

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

  /// Screen-reader label for a session an agent is actively working in; the visual signal is the twinkling sparkle
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get sessionListRunning;

  /// Screen-reader label for a session with unopened agent activity; the visual signal is the resting sparkle
  ///
  /// In en, this message translates to:
  /// **'New activity'**
  String get sessionListNewActivity;

  /// Screen-reader label for the harness driving a session; the visual signal is the brand logo leading the row. The harness name is a brand and is not translated.
  ///
  /// In en, this message translates to:
  /// **'{harness} session'**
  String sessionListHarness(String harness);

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

  /// No description provided for @voiceCancelTranscription.
  ///
  /// In en, this message translates to:
  /// **'Cancel transcription'**
  String get voiceCancelTranscription;

  /// Accessibility label of the X button shown in the accordion's place while recording; releasing or tapping on it discards the recording.
  ///
  /// In en, this message translates to:
  /// **'Cancel recording'**
  String get voiceCancelRecording;

  /// Floating helper above the composer while a hold-to-talk recording is running.
  ///
  /// In en, this message translates to:
  /// **'Release to transcribe'**
  String get voiceReleaseToTranscribe;

  /// Floating helper above the composer while the recording hold hovers over the cancel button; releasing there discards the recording.
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get voiceReleaseToCancel;

  /// No description provided for @voiceTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing...'**
  String get voiceTranscribing;

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

  /// Primary action of the add-project sheet: registers the folder the browser is currently showing as a Sesori project.
  ///
  /// In en, this message translates to:
  /// **'Add as new project'**
  String get addAsNewProject;

  /// Secondary action of the add-project sheet: makes a new folder inside the one being browsed.
  ///
  /// In en, this message translates to:
  /// **'Create new folder'**
  String get createNewFolder;

  /// No description provided for @newFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolderTitle;

  /// No description provided for @newFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get newFolderHint;

  /// No description provided for @newFolderCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get newFolderCreate;

  /// No description provided for @newFolderExists.
  ///
  /// In en, this message translates to:
  /// **'A file or folder with that name already exists here'**
  String get newFolderExists;

  /// No description provided for @newFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the folder'**
  String get newFolderFailed;

  /// No description provided for @newFolderUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Update Sesori Bridge on your computer to create folders from here.'**
  String get newFolderUnsupported;

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

  /// Tag on a folder row in the add-project browser marking it as a git repository. Not necessarily hosted on GitHub — the bridge only reports that a repository is present.
  ///
  /// In en, this message translates to:
  /// **'Git'**
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

  /// Label on the swipe-revealed hide button of a project row. Kept short — the button is a compact pill.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

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

  /// No description provided for @projectDiscovered.
  ///
  /// In en, this message translates to:
  /// **'Project discovered'**
  String get projectDiscovered;

  /// No description provided for @addProjectEnableGitTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Git tracking?'**
  String get addProjectEnableGitTitle;

  /// No description provided for @addProjectEnableGitBody.
  ///
  /// In en, this message translates to:
  /// **'Sesori will commit all non-ignored files to enable history and parallel sessions with dedicated worktrees.'**
  String get addProjectEnableGitBody;

  /// No description provided for @addProjectContinueWithoutGit.
  ///
  /// In en, this message translates to:
  /// **'Continue Without Git'**
  String get addProjectContinueWithoutGit;

  /// No description provided for @addProjectEnableGit.
  ///
  /// In en, this message translates to:
  /// **'Enable Git'**
  String get addProjectEnableGit;

  /// No description provided for @addProjectGitSetupIncompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Project opened, Git setup incomplete'**
  String get addProjectGitSetupIncompleteTitle;

  /// No description provided for @addProjectGitSetupIncompleteBody.
  ///
  /// In en, this message translates to:
  /// **'The folder is open and ready for sessions, but Sesori could not finish Git setup. Git files may have been created. Dedicated worktrees stay unavailable until the repository has an initial commit.'**
  String get addProjectGitSetupIncompleteBody;

  /// No description provided for @addProjectGitSetupIncompleteAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get addProjectGitSetupIncompleteAcknowledge;

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

  /// No description provided for @newSessionDedicatedWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Dedicated workspace'**
  String get newSessionDedicatedWorkspace;

  /// No description provided for @newSessionPluginChooserLabel.
  ///
  /// In en, this message translates to:
  /// **'Coding tool'**
  String get newSessionPluginChooserLabel;

  /// No description provided for @newSessionPluginDegraded.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get newSessionPluginDegraded;

  /// No description provided for @newSessionPluginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get newSessionPluginUnavailable;

  /// No description provided for @newSessionPluginFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get newSessionPluginFailed;

  /// No description provided for @newSessionHarnessSettings.
  ///
  /// In en, this message translates to:
  /// **'Harness settings'**
  String get newSessionHarnessSettings;

  /// No description provided for @newSessionNoHarnessTitle.
  ///
  /// In en, this message translates to:
  /// **'No coding harness installed'**
  String get newSessionNoHarnessTitle;

  /// No description provided for @newSessionNoHarnessDescription.
  ///
  /// In en, this message translates to:
  /// **'The connected bridge has no coding harness it can run. Install one from Harness settings.'**
  String get newSessionNoHarnessDescription;

  /// No description provided for @newSessionOptionsLoadingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Loading session options'**
  String get newSessionOptionsLoadingSemantics;

  /// No description provided for @newSessionOptionsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh the model list'**
  String get newSessionOptionsRefresh;

  /// No description provided for @newSessionProjectUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t verify whether this project supports dedicated workspaces. Try again before creating the session.'**
  String get newSessionProjectUnavailable;

  /// No description provided for @newSessionOptionsCached.
  ///
  /// In en, this message translates to:
  /// **'Using cached coding tool options.'**
  String get newSessionOptionsCached;

  /// No description provided for @newSessionOptionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No cached options are available. You can create with defaults or refresh now.'**
  String get newSessionOptionsUnavailable;

  /// No description provided for @newSessionOptionsLoadFailedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load options. You can create with defaults or try again.'**
  String get newSessionOptionsLoadFailedUnavailable;

  /// No description provided for @newSessionOptionsLegacyBridge.
  ///
  /// In en, this message translates to:
  /// **'This bridge can load options only by starting the selected coding tool. You can create with defaults or refresh now.'**
  String get newSessionOptionsLegacyBridge;

  /// No description provided for @newSessionOptionsUpdateFailedRetained.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update options. Previously cached options are still available.'**
  String get newSessionOptionsUpdateFailedRetained;

  /// No description provided for @newSessionOptionsRefreshFailedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed and no valid cached options remain. You can create with defaults.'**
  String get newSessionOptionsRefreshFailedUnavailable;

  /// No description provided for @sessionListDeleteWorktreeCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Delete worktree'**
  String get sessionListDeleteWorktreeCheckbox;

  /// No description provided for @sessionDetailArchivedNotice.
  ///
  /// In en, this message translates to:
  /// **'This session is archived and read-only.'**
  String get sessionDetailArchivedNotice;

  /// No description provided for @sessionListArchiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive session?'**
  String get sessionListArchiveConfirmTitle;

  /// No description provided for @sessionListArchiveConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Archiving is permanent. This session becomes read-only — you can still read it, but you cannot reopen it, send prompts, or unarchive it.'**
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
  /// **'Getting everything ready…'**
  String get newSessionLoadingMessage1;

  /// No description provided for @newSessionLoadingMessage2.
  ///
  /// In en, this message translates to:
  /// **'Connecting the pieces…'**
  String get newSessionLoadingMessage2;

  /// No description provided for @newSessionLoadingMessage3.
  ///
  /// In en, this message translates to:
  /// **'Almost ready…'**
  String get newSessionLoadingMessage3;

  /// No description provided for @newSessionCreationDuplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'Sesori couldn\'t confirm whether a session was created. It may still appear in the session list, and sending again may create a duplicate.'**
  String get newSessionCreationDuplicateWarning;

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

  /// Shortest form of 'just now', for the few characters a session row's trailing slot can hold.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timestampCompactNow;

  /// Shortest form of '{minutes}m ago', for the few characters a session row's trailing slot can hold.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String timestampCompactMinutes(int minutes);

  /// Shortest form of '{hours}h ago', for the few characters a session row's trailing slot can hold.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String timestampCompactHours(int hours);

  /// Shortest form of '{days}d ago', for the few characters a session row's trailing slot can hold.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String timestampCompactDays(int days);

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

  /// Caption under the pull-to-refresh spinner once the pull has passed the ordinary trigger, inviting the user to keep pulling to start a full catalog scan.
  ///
  /// In en, this message translates to:
  /// **'Keep pulling to scan all harnesses'**
  String get catalogScanPullCaption;

  /// Title of the row above a list while a catalog scan is in flight across every enabled harness.
  ///
  /// In en, this message translates to:
  /// **'Scanning all harnesses'**
  String get catalogScanRunningTitle;

  /// Supporting line on the scan row between dispatch and the first progress event, when no harness has reported yet. Holds the line's place so the row does not change height when the real detail arrives.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get catalogScanStartingDetail;

  /// Supporting line on the running scan row: the harness currently being scanned and how many sessions it has reported so far.
  ///
  /// In en, this message translates to:
  /// **'{harness} — {sessions, plural, =1{1 session} other{{sessions} sessions}}'**
  String catalogScanRunningDetail(String harness, int sessions);

  /// Action on the running scan row that stops the catalog scan in flight.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get catalogScanCancel;

  /// Title of the scan row once every harness finished scanning successfully.
  ///
  /// In en, this message translates to:
  /// **'Scan complete'**
  String get catalogScanCompleteTitle;

  /// Whole result line of a finished scan that turned up neither a new session nor a new project. A standalone sentence, unlike the count clauses, which are noun phrases meant to be joined.
  ///
  /// In en, this message translates to:
  /// **'No new sessions'**
  String get catalogScanNothingNew;

  /// Sessions clause of a finished scan's result, counting only sessions the scan had not imported before. Never rendered for a count of zero; that clause is dropped so the line reads as a noun phrase either way.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new session} other{{count} new sessions}}'**
  String catalogScanNewSessionCount(int count);

  /// Projects clause of a finished scan's result, counting only projects the scan had not imported before.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new project} other{{count} new projects}}'**
  String catalogScanNewProjectCount(int count);

  /// Sessions clause used when a harness did not report what was new, so the row can only name the totals it published.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String catalogScanSessionCount(int count);

  /// Projects clause used when a harness did not report what was new, so the row can only name the totals it published.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 project} other{{count} projects}}'**
  String catalogScanProjectCount(int count);

  /// Joins the sessions and projects clauses of a finished scan's result into one line.
  ///
  /// In en, this message translates to:
  /// **'{sessions} in {projects}'**
  String catalogScanCountsJoined(String sessions, String projects);

  /// Title of the scan row when some harnesses scanned successfully and others did not.
  ///
  /// In en, this message translates to:
  /// **'Scan finished'**
  String get catalogScanPartlyFailedTitle;

  /// Supporting line on a partly failed scan row. Both harnesses counts are at least one, so the total is always plural.
  ///
  /// In en, this message translates to:
  /// **'{failed} of {total} harnesses could not be scanned'**
  String catalogScanPartlyFailedDetail(int failed, int total);

  /// Title of the scan row when no harness could be scanned.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get catalogScanFailedTitle;

  /// Supporting line on a failed scan row. The bridge's own error text is never shown here, so the row points at the log that has it.
  ///
  /// In en, this message translates to:
  /// **'Check the bridge log for details'**
  String get catalogScanFailedDetail;

  /// Title of the scan row when the connected bridge is too old to scan harness catalogs on request.
  ///
  /// In en, this message translates to:
  /// **'Scanning needs a newer bridge'**
  String get catalogScanUnsupportedTitle;

  /// Supporting line on the unsupported scan row, naming what would make scanning available.
  ///
  /// In en, this message translates to:
  /// **'Update the bridge to scan from here'**
  String get catalogScanUnsupportedDetail;

  /// Title of the scan row when no harness could be scanned: none is connected and ready, or the bridge has not reported its harnesses yet.
  ///
  /// In en, this message translates to:
  /// **'No harness to scan'**
  String get catalogScanNoHarnessTitle;

  /// Supporting line on the no-harness scan row, naming where the user can see and fix their harness setup.
  ///
  /// In en, this message translates to:
  /// **'Check your harnesses in Settings'**
  String get catalogScanNoHarnessDetail;

  /// Settings action on a harness card that re-imports that one harness's catalog, the pointer-and-keyboard equivalent of the lists' deep pull.
  ///
  /// In en, this message translates to:
  /// **'Scan for sessions'**
  String get harnessManagementScan;

  /// Supporting line under the per-harness scan action, saying what scanning does.
  ///
  /// In en, this message translates to:
  /// **'Import projects and sessions this harness has on disk'**
  String get harnessManagementScanDescription;

  /// Replaces the scan action's description when the bridge refused to import from this harness, usually because it is not running or its setup is incomplete.
  ///
  /// In en, this message translates to:
  /// **'This harness cannot be scanned right now'**
  String get harnessManagementScanNotReady;

  /// Replaces the scan action's description when the connected bridge is too old to import catalogs on request.
  ///
  /// In en, this message translates to:
  /// **'Update the bridge to scan from here'**
  String get harnessManagementScanUnsupported;

  /// Replaces the scan action's description when the request itself failed. Names no log, because the request may never have reached the bridge, and the client-side cause it is recorded against has no user-facing viewer.
  ///
  /// In en, this message translates to:
  /// **'Could not start the scan. Try again in a moment'**
  String get harnessManagementScanFailed;

  /// Action on a finished scan row that clears it once the user has read the result.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get catalogScanDismiss;
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
