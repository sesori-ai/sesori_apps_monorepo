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

  /// No description provided for @sessionDetailHarnessLegacyWarning.
  ///
  /// In en, this message translates to:
  /// **'Update your bridge to check harness availability.'**
  String get sessionDetailHarnessLegacyWarning;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sesori Mobile'**
  String get appTitle;

  /// No description provided for @persistenceStartupFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage upgrade paused'**
  String get persistenceStartupFailureTitle;

  /// No description provided for @persistenceStartupFailureDescription.
  ///
  /// In en, this message translates to:
  /// **'Sesori couldn’t finish upgrading your local storage. Close and reopen Sesori to try again.'**
  String get persistenceStartupFailureDescription;

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

  /// macOS protected-file access for this computer, not a remote bridge.
  ///
  /// In en, this message translates to:
  /// **'Full Disk Access'**
  String get desktopFileAccessTitle;

  /// Explains the optional broader permission and the agent benefit before opening macOS settings.
  ///
  /// In en, this message translates to:
  /// **'Sesori runs coding agents on your behalf. macOS folder prompts can pause them while you\'re away. Full Disk Access lets Sesori and its agents access protected files without those prompts. This is optional; restart the local bridge after granting access.'**
  String get desktopFileAccessDescription;

  /// No description provided for @desktopFileAccessOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get desktopFileAccessOpenSettings;

  /// No description provided for @desktopFileAccessNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get desktopFileAccessNotNow;

  /// No description provided for @desktopFileAccessGranted.
  ///
  /// In en, this message translates to:
  /// **'Protected files are accessible'**
  String get desktopFileAccessGranted;

  /// No description provided for @desktopFileAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Not granted — folder prompts may pause agents'**
  String get desktopFileAccessDenied;

  /// No description provided for @desktopFileAccessUnknown.
  ///
  /// In en, this message translates to:
  /// **'Access could not be confirmed'**
  String get desktopFileAccessUnknown;

  /// Desktop home section heading for sessions waiting on the user's answer.
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get desktopHomeNeedsYou;

  /// Desktop home section heading for the latest sessions across projects that are neither running nor waiting.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get desktopHomeRecent;

  /// Tooltip and label for the small desktop sidebar action that opens the add-project dialog.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get desktopSidebarNewProject;

  /// Sidebar button that reveals up to {count} more of a project's sessions in place.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more'**
  String desktopSidebarShowMore(int count);

  /// Collapsible desktop sidebar section of sessions in motion across every project, with how many.
  ///
  /// In en, this message translates to:
  /// **'Activity · {count}'**
  String desktopSidebarActivity(int count);

  /// Accessible identity of a priority sidebar session with its project context.
  ///
  /// In en, this message translates to:
  /// **'{sessionTitle} in {projectName}'**
  String desktopSidebarActivitySession(String sessionTitle, String projectName);

  /// Tooltip for the sidebar project's new-session button, revealed on hover or keyboard focus.
  ///
  /// In en, this message translates to:
  /// **'New session in {projectName}'**
  String desktopSidebarNewSession(String projectName);

  /// Tooltip for hiding a project's recent-session rows in the desktop sidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse {projectName}'**
  String desktopSidebarCollapseProject(String projectName);

  /// Tooltip for showing a project's recent-session rows in the desktop sidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand {projectName}'**
  String desktopSidebarExpandProject(String projectName);

  /// Desktop control tooltip with its available platform-specific keyboard shortcut.
  ///
  /// In en, this message translates to:
  /// **'{label} ({shortcut})'**
  String desktopShortcutHint(String label, String shortcut);

  /// Tooltip for switching desktop navigation to the compact project rail.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get desktopSidebarCollapse;

  /// Tooltip for restoring the expanded desktop navigation sidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get desktopSidebarExpand;

  /// Tooltip on the expanded desktop sidebar's drag handle.
  ///
  /// In en, this message translates to:
  /// **'Resize sidebar; double-click to reset'**
  String get desktopSidebarResize;

  /// Desktop sidebar row that opens the command palette.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get desktopSearch;

  /// Placeholder of the desktop command palette's search field.
  ///
  /// In en, this message translates to:
  /// **'Search sessions, projects and commands'**
  String get desktopCommandPaletteHint;

  /// Desktop command palette heading over the app-wide commands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get desktopCommandPaletteCommands;

  /// Desktop command palette command that collapses or expands the sidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle sidebar'**
  String get desktopToggleSidebar;

  /// Desktop command palette command that leaves a pushed page.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get desktopGoBack;

  /// Desktop project page toolbar toggle that switches the list to the project's archived sessions.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get desktopProjectPageArchived;

  /// Session list filter chip showing every active session, with their count.
  ///
  /// In en, this message translates to:
  /// **'All · {count}'**
  String sessionListFilterAll(int count);

  /// Heading of the new session page, above the project selector and the prompt input.
  ///
  /// In en, this message translates to:
  /// **'What should we work on?'**
  String get newSessionHeading;

  /// Desktop session page toolbar button that opens the session's file changes.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get desktopSessionPageChanges;

  /// Desktop subtask toolbar breadcrumb that returns to the session that started the subtask.
  ///
  /// In en, this message translates to:
  /// **'Main session'**
  String get desktopSessionParentBreadcrumb;

  /// Shown under a list's search field when no loaded title matches the query.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get listSearchNoMatches;

  /// Accessibility label of the button that empties a list's search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get listSearchClear;

  /// Placeholder of the search field above the phone's projects list.
  ///
  /// In en, this message translates to:
  /// **'Search projects and sessions'**
  String get projectListSearchHint;

  /// Placeholder of the search field above the phone's session list.
  ///
  /// In en, this message translates to:
  /// **'Search sessions'**
  String get sessionListSearchHint;

  /// Shown in the session list when the Running or Unread filter leaves no session.
  ///
  /// In en, this message translates to:
  /// **'No sessions match this filter'**
  String get sessionListFilterEmpty;

  /// Session list filter chip showing only sessions an agent is working in, with their count.
  ///
  /// In en, this message translates to:
  /// **'Running · {count}'**
  String sessionListFilterRunning(int count);

  /// Session list filter chip showing only sessions with unopened activity, with their count.
  ///
  /// In en, this message translates to:
  /// **'Unread · {count}'**
  String sessionListFilterUnread(int count);

  /// Desktop project page overflow menu action that reloads the project's session list.
  ///
  /// In en, this message translates to:
  /// **'Refresh sessions'**
  String get desktopProjectPageRefresh;

  /// Tooltip for explicitly refreshing both desktop sidebar inventories.
  ///
  /// In en, this message translates to:
  /// **'Refresh projects and sessions'**
  String get desktopSidebarRefresh;

  /// Accessible busy label while both desktop sidebar inventories refresh.
  ///
  /// In en, this message translates to:
  /// **'Refreshing projects and sessions'**
  String get desktopSidebarRefreshing;

  /// Confirmation after both desktop sidebar inventories refresh.
  ///
  /// In en, this message translates to:
  /// **'Projects and sessions updated'**
  String get desktopSidebarRefreshSuccess;

  /// Failure notice when either desktop sidebar inventory could not refresh.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh projects and sessions'**
  String get desktopSidebarRefreshFailed;

  /// Sidebar recovery notice when bridge ownership can be reclaimed.
  ///
  /// In en, this message translates to:
  /// **'Another bridge currently owns this account connection.'**
  String get desktopBridgeTakenOver;

  /// Action to reclaim local or relay bridge ownership.
  ///
  /// In en, this message translates to:
  /// **'Take over'**
  String get desktopBridgeTakeOver;

  /// Sidebar notice for supervised bridge authentication recovery.
  ///
  /// In en, this message translates to:
  /// **'Your Sesori account is required before the local bridge can start.'**
  String get desktopBridgeLoginRequired;

  /// Action to recover authentication and start the local bridge.
  ///
  /// In en, this message translates to:
  /// **'Start bridge'**
  String get desktopBridgeStart;

  /// Sidebar notice when automatic bridge crash recovery stops.
  ///
  /// In en, this message translates to:
  /// **'The local bridge stopped after repeated crashes.'**
  String get desktopBridgeCrashGiveUp;

  /// Action to open the local bridge's diagnostic logs.
  ///
  /// In en, this message translates to:
  /// **'Open logs'**
  String get desktopBridgeOpenLogs;

  /// Heading for controls of the bridge supervised on this computer, not the desktop relay client.
  ///
  /// In en, this message translates to:
  /// **'Local bridge'**
  String get desktopLocalBridgeTitle;

  /// Action that turns off the supervised local bridge without quitting Sesori.
  ///
  /// In en, this message translates to:
  /// **'Stop bridge'**
  String get desktopBridgeStop;

  /// Secondary popover action opening bridge configuration.
  ///
  /// In en, this message translates to:
  /// **'Bridge settings…'**
  String get desktopBridgeSettings;

  /// Desktop settings tab for app-wide preferences.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get desktopSettingsGeneral;

  /// Native login-item switch in desktop General settings.
  ///
  /// In en, this message translates to:
  /// **'Launch Sesori at login'**
  String get desktopSettingsLaunchAtLogin;

  /// Explains native app startup, not a connected bridge's configuration.
  ///
  /// In en, this message translates to:
  /// **'Start Sesori in the background when you sign in to this computer.'**
  String get desktopSettingsLaunchAtLoginDescription;

  /// Settings owned by the connected bridge, which may be on another computer.
  ///
  /// In en, this message translates to:
  /// **'Connected bridge'**
  String get desktopSettingsConnectedBridge;

  /// Scope explanation above connected-bridge configuration.
  ///
  /// In en, this message translates to:
  /// **'These settings apply to the bridge you\'re connected to, including one on another computer.'**
  String get desktopSettingsConnectedBridgeDescription;

  /// Separates local supervised-bridge status and diagnostics from connected-bridge settings.
  ///
  /// In en, this message translates to:
  /// **'This computer'**
  String get desktopSettingsThisComputer;

  /// No description provided for @projectListTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectListTitle;

  /// Heading over the sessions waiting for the user or running, across projects, at the top of Projects.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get projectListActivity;

  /// No description provided for @projectListLoadingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Loading projects'**
  String get projectListLoadingSemantics;

  /// No description provided for @projectListDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Default project'**
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

  /// Amber status on a project row whose folder was moved or deleted on the bridge's computer.
  ///
  /// In en, this message translates to:
  /// **'Folder not found'**
  String get projectListFolderNotFound;

  /// Action that removes a project whose folder no longer exists from the project list.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get projectListRemove;

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

  /// Status under the machine name on the desktop's bridge-offline home.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get projectsBridgeOfflineDisconnected;

  /// Heading of the bridge-offline Projects screen, under the connection graphic. The bar's bridge line above already names the computer.
  ///
  /// In en, this message translates to:
  /// **'Bridge offline'**
  String get projectsBridgeOfflineTitle;

  /// Quiet line under the 'Bridge offline' heading saying when the bridge was last seen, e.g. 'Last seen 5h ago'. Omitted when the bridge has never reported a last-seen time. The placeholder is already-formatted text from the app's shared relative-time vocabulary (the same one the project rows use), which is compact for recent instants and becomes a plain date past the relative window.
  ///
  /// In en, this message translates to:
  /// **'Last seen {lastSeen}'**
  String projectsBridgeOfflineLastSeen(String lastSeen);

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

  /// Desktop project recovery action that starts or retries the supervised local bridge.
  ///
  /// In en, this message translates to:
  /// **'Start the bridge'**
  String get projectsDesktopStartBridge;

  /// Desktop-only explanation shown while the local supervised bridge is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Start the local bridge to load your projects and sessions in Sesori.'**
  String get projectsDesktopStartBridgeInfo;

  /// No description provided for @connectionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connectionLostTitle;

  /// No description provided for @connectionLostReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get connectionLostReconnect;

  /// No description provided for @connectionReconnectingTitle.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get connectionReconnectingTitle;

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
  /// **'Log out'**
  String get settingsLogout;

  /// Title of the confirmation dialog shown before the user logs out.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get settingsLogoutConfirmTitle;

  /// Body of the log-out confirmation dialog: logging out removes this device's access to the user's bridges until they sign in again.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to sign in again to reach your bridges from this device.'**
  String get settingsLogoutConfirmMessage;

  /// Button that closes the log-out confirmation dialog and keeps the user signed in.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsLogoutConfirmCancel;

  /// One line above the bridge settings group while no bridge is connected; the rows below it are dimmed.
  ///
  /// In en, this message translates to:
  /// **'Connect to a bridge to change these settings.'**
  String get settingsBridgeOffline;

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

  /// Plain statement of what YOLO mode does, under its Settings toggle and in the session page's YOLO explanation.
  ///
  /// In en, this message translates to:
  /// **'Sesori approves every permission request for you, so the agent never stops to ask.'**
  String get settingsYoloDescription;

  /// No description provided for @settingsYoloLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the bridge setting…'**
  String get settingsYoloLoading;

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

  /// No description provided for @settingsPluginWarmupTitle.
  ///
  /// In en, this message translates to:
  /// **'Warm harness on session open'**
  String get settingsPluginWarmupTitle;

  /// No description provided for @settingsPluginWarmupDescription.
  ///
  /// In en, this message translates to:
  /// **'Starts the session\'s harness when you open it to reduce delays on your first action.'**
  String get settingsPluginWarmupDescription;

  /// No description provided for @settingsPluginWarmupLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the bridge setting…'**
  String get settingsPluginWarmupLoading;

  /// No description provided for @settingsPluginWarmupUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Update the connected bridge to configure this setting.'**
  String get settingsPluginWarmupUnsupported;

  /// No description provided for @settingsPluginWarmupLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the bridge setting. Check your connection and try again.'**
  String get settingsPluginWarmupLoadFailed;

  /// No description provided for @settingsPluginWarmupUncertain.
  ///
  /// In en, this message translates to:
  /// **'The update status is unknown. Refresh before trying again.'**
  String get settingsPluginWarmupUncertain;

  /// No description provided for @settingsPluginWarmupUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the bridge setting. Check your connection and try again.'**
  String get settingsPluginWarmupUpdateFailed;

  /// No description provided for @settingsPluginWarmupRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry harness warm-up setting'**
  String get settingsPluginWarmupRetry;

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
  /// **'Global harness settings'**
  String get harnessManagementDefaultsSection;

  /// No description provided for @harnessManagementDefaultTimeout.
  ///
  /// In en, this message translates to:
  /// **'Default idle timeout'**
  String get harnessManagementDefaultTimeout;

  /// No description provided for @harnessManagementDefaultTimeoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Apply to all harnesses and replace individual overrides.'**
  String get harnessManagementDefaultTimeoutDescription;

  /// No description provided for @harnessManagementEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get harnessManagementEnabled;

  /// No description provided for @harnessManagementRefreshSetup.
  ///
  /// In en, this message translates to:
  /// **'Check setup'**
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
  /// **'Restart harness'**
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

  /// No description provided for @harnessManagementReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get harnessManagementReview;

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
  /// **'Force disable {harnessName}?'**
  String harnessManagementForceDisableTitle(String harnessName);

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

  /// No description provided for @harnessAuthenticationViewProgress.
  ///
  /// In en, this message translates to:
  /// **'View sign-in'**
  String get harnessAuthenticationViewProgress;

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

  /// No description provided for @harnessAuthenticationBrowserInstructions.
  ///
  /// In en, this message translates to:
  /// **'Only continue if you started this login. Verify the provider\'s website address before signing in. Sesori will return automatically when authorization finishes.'**
  String get harnessAuthenticationBrowserInstructions;

  /// No description provided for @harnessAuthenticationPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing sign-in…'**
  String get harnessAuthenticationPreparing;

  /// No description provided for @harnessAuthenticationPreparingDescription.
  ///
  /// In en, this message translates to:
  /// **'The provider page will open after the bridge prepares this sign-in.'**
  String get harnessAuthenticationPreparingDescription;

  /// No description provided for @harnessAuthenticationOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening the secure provider page…'**
  String get harnessAuthenticationOpening;

  /// No description provided for @harnessAuthenticationWaitingForBrowser.
  ///
  /// In en, this message translates to:
  /// **'Complete sign-in in the provider page. Sesori will return automatically.'**
  String get harnessAuthenticationWaitingForBrowser;

  /// No description provided for @harnessAuthenticationFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finishing sign-in with the bridge…'**
  String get harnessAuthenticationFinalizing;

  /// No description provided for @harnessAuthenticationSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Sign-in completed successfully.'**
  String get harnessAuthenticationSucceeded;

  /// No description provided for @harnessAuthenticationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled. No account was connected.'**
  String get harnessAuthenticationCancelled;

  /// No description provided for @harnessAuthenticationRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get harnessAuthenticationRetry;

  /// No description provided for @harnessAuthenticationDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get harnessAuthenticationDone;

  /// No description provided for @harnessAuthenticationClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get harnessAuthenticationClose;

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

  /// No description provided for @harnessAuthenticationUpdateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update Sesori to continue this harness login.'**
  String get harnessAuthenticationUpdateRequired;

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
  /// **'The secure website could not be opened. Try again.'**
  String get harnessAuthenticationBrowserFailed;

  /// No description provided for @harnessAuthenticationRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get harnessAuthenticationRequestFailed;

  /// No description provided for @harnessAuthenticationPastedCodeInstructions.
  ///
  /// In en, this message translates to:
  /// **'Only continue if you started this login. Sesori will sign {harnessName} on the connected computer into your account. Open the sign-in page, verify its address, approve access, then paste the code shown after approval.'**
  String harnessAuthenticationPastedCodeInstructions(String harnessName);

  /// No description provided for @harnessAuthenticationOpenSignInPage.
  ///
  /// In en, this message translates to:
  /// **'Open sign-in page'**
  String get harnessAuthenticationOpenSignInPage;

  /// No description provided for @harnessAuthenticationPastedCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code from the sign-in page'**
  String get harnessAuthenticationPastedCodeLabel;

  /// No description provided for @harnessAuthenticationSubmitCode.
  ///
  /// In en, this message translates to:
  /// **'Submit code'**
  String get harnessAuthenticationSubmitCode;

  /// No description provided for @harnessAuthenticationPastedCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Paste the complete code shown after approval, without spaces.'**
  String get harnessAuthenticationPastedCodeInvalid;

  /// No description provided for @harnessAuthenticationPastedCodeNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'The code could not be confirmed. Submit it again.'**
  String get harnessAuthenticationPastedCodeNotConfirmed;

  /// No description provided for @harnessesRegisteredSection.
  ///
  /// In en, this message translates to:
  /// **'Registered harnesses'**
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

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @desktopSettingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get desktopSettingsTheme;

  /// No description provided for @settingsSectionAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get settingsSectionAnalytics;

  /// No description provided for @settingsBasicUsageAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Basic usage analytics'**
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

  /// No description provided for @settingsSectionSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get settingsSectionSessions;

  /// No description provided for @settingsSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// No description provided for @settingsDefaultInputDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how you default talk to Sesori.'**
  String get settingsDefaultInputDescription;

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
  /// **'Terms of service'**
  String get settingsLegalTerms;

  /// No description provided for @settingsLegalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
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
  /// **'AI notifications'**
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
  /// **'AI interactions'**
  String get notificationCategoryAiInteraction;

  /// No description provided for @notificationCategoryAiInteractionDescription.
  ///
  /// In en, this message translates to:
  /// **'Questions and permission requests from active AI sessions'**
  String get notificationCategoryAiInteractionDescription;

  /// No description provided for @notificationCategorySessionMessage.
  ///
  /// In en, this message translates to:
  /// **'Session messages'**
  String get notificationCategorySessionMessage;

  /// No description provided for @notificationCategorySessionMessageDescription.
  ///
  /// In en, this message translates to:
  /// **'New assistant messages from running sessions'**
  String get notificationCategorySessionMessageDescription;

  /// No description provided for @notificationCategoryConnectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection status'**
  String get notificationCategoryConnectionStatus;

  /// No description provided for @notificationCategoryConnectionStatusDescription.
  ///
  /// In en, this message translates to:
  /// **'Bridge online and offline status changes'**
  String get notificationCategoryConnectionStatusDescription;

  /// No description provided for @notificationCategorySystemUpdate.
  ///
  /// In en, this message translates to:
  /// **'System updates'**
  String get notificationCategorySystemUpdate;

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
  /// **'Start your first session'**
  String get sessionListEmptyTitle;

  /// No description provided for @sessionListUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled session'**
  String get sessionListUntitled;

  /// Heading for sessions whose updated or archive timestamp is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get sessionListUnknownDate;

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

  /// Label of the primary action that starts a new session: the sessions list button and the desktop sidebar button.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get sessionListNewSession;

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

  /// Label on a transcript message injected by session automation rather than authored by the user or agent.
  ///
  /// In en, this message translates to:
  /// **'Automation'**
  String get sessionDetailAutomation;

  /// No description provided for @sessionDetailRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sessionDetailRetry;

  /// Action that refreshes harness availability after authentication may have been restored elsewhere.
  ///
  /// In en, this message translates to:
  /// **'Recheck'**
  String get sessionDetailRecheck;

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

  /// Under a long code block in a chat message that shows only its first lines; opens the whole block in a modal.
  ///
  /// In en, this message translates to:
  /// **'Open all {count} lines'**
  String codeBlockOpenAll(int count);

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
  /// **'Search commands'**
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

  /// No description provided for @sessionDetailStopNotAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Session not stopped'**
  String get sessionDetailStopNotAcceptedTitle;

  /// No description provided for @sessionDetailStopNotAcceptedBackgroundMessage.
  ///
  /// In en, this message translates to:
  /// **'Sesori couldn’t verify whether background work finished, so it didn’t stop this session. Restart the harness, then try again.'**
  String get sessionDetailStopNotAcceptedBackgroundMessage;

  /// No description provided for @sessionDetailStopNotAcceptedGenericMessage.
  ///
  /// In en, this message translates to:
  /// **'Sesori couldn’t safely stop this session. Restart the harness, then try again.'**
  String get sessionDetailStopNotAcceptedGenericMessage;

  /// No description provided for @sessionDetailStopScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Sub-agents are running'**
  String get sessionDetailStopScopeTitle;

  /// No description provided for @sessionDetailStopScopeMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The main agent and 1 sub-agent are still working.} other{The main agent and {count} sub-agents are still working.}}'**
  String sessionDetailStopScopeMessage(int count);

  /// No description provided for @sessionDetailStopScopeMessageMainIdle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The main agent is done, but 1 sub-agent is still working. Stop it?} other{The main agent is done, but {count} sub-agents are still working. Stop them?}}'**
  String sessionDetailStopScopeMessageMainIdle(int count);

  /// No description provided for @sessionDetailStopSubAgentsOnly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Stop 1 sub-agent} other{Stop {count} sub-agents}}'**
  String sessionDetailStopSubAgentsOnly(int count);

  /// No description provided for @sessionDetailStopMainAgentOnly.
  ///
  /// In en, this message translates to:
  /// **'Stop main agent only'**
  String get sessionDetailStopMainAgentOnly;

  /// No description provided for @sessionDetailStopAll.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Stop main agent and 1 sub-agent} other{Stop main agent and {count} sub-agents}}'**
  String sessionDetailStopAll(int count);

  /// No description provided for @sessionDetailThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get sessionDetailThinking;

  /// No description provided for @sessionDetailWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get sessionDetailWorking;

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

  /// No description provided for @sessionDetailToolError.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get sessionDetailToolError;

  /// No description provided for @sessionDetailToolCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get sessionDetailToolCancelled;

  /// No description provided for @sessionDetailShell.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get sessionDetailShell;

  /// No description provided for @sessionDetailCommandRan.
  ///
  /// In en, this message translates to:
  /// **'Ran'**
  String get sessionDetailCommandRan;

  /// No description provided for @sessionDetailFollowOutput.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get sessionDetailFollowOutput;

  /// The one-line summary of a collapsed group of agent steps in a session transcript: how many finished steps it holds, where every thinking block, tool call and sub-agent counts as one step, e.g. '7 steps'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step} other{{count} steps}}'**
  String transcriptSummarySteps(int count);

  /// Part of the one line a folded turn of a session transcript shows: how many steps the agent took in it, e.g. '3 steps · 1m 02s — Fixed the failing test'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No steps} =1{1 step} other{{count} steps}}'**
  String transcriptTurnSteps(int count);

  /// The line a folded turn of a session transcript shows while the agent works on it and has taken no step yet.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get transcriptTurnRunning;

  /// The line a folded turn of a session transcript shows while the agent works on it: how many steps it has taken so far, e.g. 'Running · step 3'.
  ///
  /// In en, this message translates to:
  /// **'Running · step {step}'**
  String transcriptTurnRunningStep(int step);

  /// Start of the line a folded turn of a session transcript shows when the turn ended in an error, followed by the error's first line when there is one, e.g. 'Ended with an error · Rate limit reached'.
  ///
  /// In en, this message translates to:
  /// **'Ended with an error'**
  String get transcriptTurnFailed;

  /// Start of the line a folded session transcript shows for the messages before the first loaded prompt, whose own prompt may be on an older page that has not loaded, followed by the step count, e.g. 'Earlier turn, partly loaded · 3 steps'.
  ///
  /// In en, this message translates to:
  /// **'Earlier turn, partly loaded'**
  String get transcriptTurnPartlyLoaded;

  /// Start of the line a folded session transcript shows for the messages before the user's first prompt, such as automation, followed by the step count, e.g. 'Before the first prompt · 2 steps'.
  ///
  /// In en, this message translates to:
  /// **'Before the first prompt'**
  String get transcriptTurnBeforeFirstPrompt;

  /// A session transcript duration under a minute, such as how long a folded turn took or how long the agent has been working, e.g. '42s'.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String transcriptTurnSeconds(int seconds);

  /// A session transcript duration under an hour, such as how long a folded turn took or how long the agent has been working. The seconds always have two digits, e.g. '1m 02s'.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String transcriptTurnMinutes(int minutes, String seconds);

  /// A session transcript duration of an hour or more, such as how long a folded turn took or how long the agent has been working. The minutes and seconds always have two digits, e.g. '1h 05m 12s'.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m {seconds}s'**
  String transcriptTurnHours(int hours, String minutes, String seconds);

  /// Label of the session toolbar button that folds every turn of the transcript to one line each.
  ///
  /// In en, this message translates to:
  /// **'Fold all turns'**
  String get transcriptFoldAll;

  /// Label of the session toolbar button that unfolds every folded turn of the transcript.
  ///
  /// In en, this message translates to:
  /// **'Unfold all turns'**
  String get transcriptUnfoldAll;

  /// Screen reader hint of the prompt pinned at the top of a session transcript while the user reads that prompt's turn. Activating it scrolls the transcript to the prompt.
  ///
  /// In en, this message translates to:
  /// **'Jump to this prompt'**
  String get transcriptStickyPromptJumpHint;

  /// What the prompt pinned at the top of a session transcript shows when the prompt has no text and its first attachment has no file name.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get transcriptStickyPromptAttachment;

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

  /// No description provided for @sessionDetailUnavailableCommand.
  ///
  /// In en, this message translates to:
  /// **'Command unavailable'**
  String get sessionDetailUnavailableCommand;

  /// No description provided for @sessionDetailQueueCancellationFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancellation was not confirmed. The message may already have been sent.'**
  String get sessionDetailQueueCancellationFailed;

  /// No description provided for @sessionDetailSendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sessionDetailSendingMessage;

  /// Status under a message whose send is still in flight after a short delay; names the harness, e.g. OpenCode.
  ///
  /// In en, this message translates to:
  /// **'Sending to {harnessName}…'**
  String sessionDetailSendingToHarness(String harnessName);

  /// Status under a message whose send failed; Retry and Remove buttons follow it.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t send'**
  String get sessionDetailSendFailed;

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

  /// No description provided for @sessionDetailAuthenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Provider login required'**
  String get sessionDetailAuthenticationRequired;

  /// No description provided for @sessionDetailCommandUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That command is no longer available. Remove it from the queue to continue.'**
  String get sessionDetailCommandUnavailable;

  /// No description provided for @sessionDetailCancelQueued.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sessionDetailCancelQueued;

  /// No description provided for @sessionDetailRemoveQueued.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get sessionDetailRemoveQueued;

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

  /// No description provided for @sessionDetailFastMode.
  ///
  /// In en, this message translates to:
  /// **'Fast mode'**
  String get sessionDetailFastMode;

  /// Label of the chip beside the session's model picker while YOLO mode is on for the session. Keep the product term YOLO.
  ///
  /// In en, this message translates to:
  /// **'YOLO'**
  String get sessionDetailYoloChip;

  /// Session approval menu option, and the tooltip of the composer's approval chip, for a session where every permission request waits for the user.
  ///
  /// In en, this message translates to:
  /// **'Ask for approval'**
  String get sessionApprovalAsk;

  /// Session approval menu option that makes Sesori approve every permission request for this session. Keep the product term YOLO.
  ///
  /// In en, this message translates to:
  /// **'Approve everything (YOLO)'**
  String get sessionApprovalYolo;

  /// Marks the session approval menu option that matches the bridge-wide setting, which sessions follow unless changed.
  ///
  /// In en, this message translates to:
  /// **'{option} (default)'**
  String sessionApprovalDefaultOption(String option);

  /// Error alert when the bridge did not acknowledge a change to the session's approval mode.
  ///
  /// In en, this message translates to:
  /// **'Could not change approval for this session. Try again.'**
  String get sessionApprovalUpdateFailed;

  /// Title of the sheet or dialog opened by tapping the YOLO chip on the session page.
  ///
  /// In en, this message translates to:
  /// **'YOLO mode is on'**
  String get sessionDetailYoloTitle;

  /// Button in the YOLO explanation that opens the settings where YOLO mode is turned off.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get sessionDetailYoloOpenSettings;

  /// No description provided for @sessionDetailFastModeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch speed?'**
  String get sessionDetailFastModeConfirmTitle;

  /// No description provided for @sessionDetailFastModeConfirmEnableBody.
  ///
  /// In en, this message translates to:
  /// **'Switching speed drops the prompt cache, so the next message re-reads the whole conversation. Fast mode also uses more of your usage.'**
  String get sessionDetailFastModeConfirmEnableBody;

  /// No description provided for @sessionDetailFastModeConfirmDisableBody.
  ///
  /// In en, this message translates to:
  /// **'Switching speed drops the prompt cache, so the next message re-reads the whole conversation.'**
  String get sessionDetailFastModeConfirmDisableBody;

  /// No description provided for @sessionDetailFastModeConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get sessionDetailFastModeConfirmAction;

  /// No description provided for @sessionDetailFastModeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sessionDetailFastModeCancel;

  /// No description provided for @sessionDetailFastModeUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Fast mode is unavailable'**
  String get sessionDetailFastModeUnavailableTitle;

  /// No description provided for @sessionDetailFastModeUnavailableExtraUsageDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on extra usage for your account to use fast mode.'**
  String get sessionDetailFastModeUnavailableExtraUsageDisabled;

  /// No description provided for @sessionDetailFastModeUnavailableNotOnPlan.
  ///
  /// In en, this message translates to:
  /// **'Your plan doesn\'t include fast mode.'**
  String get sessionDetailFastModeUnavailableNotOnPlan;

  /// No description provided for @sessionDetailFastModeUnavailableDisabledByOrganization.
  ///
  /// In en, this message translates to:
  /// **'Your organization has turned off fast mode.'**
  String get sessionDetailFastModeUnavailableDisabledByOrganization;

  /// No description provided for @sessionDetailFastModeUnavailableUnknown.
  ///
  /// In en, this message translates to:
  /// **'Fast mode can\'t be used with this account right now.'**
  String get sessionDetailFastModeUnavailableUnknown;

  /// No description provided for @sessionDetailModelSearch.
  ///
  /// In en, this message translates to:
  /// **'Search models...'**
  String get sessionDetailModelSearch;

  /// No description provided for @subAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sub-agents'**
  String get subAgentsTitle;

  /// Tooltip and screen-reader label of the sub-agents pill in the composer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sub-agent} other{{count} sub-agents}}, {running} working'**
  String subAgentsSummary(int count, int running);

  /// No description provided for @backgroundTaskStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
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

  /// Action on the desktop 'Session archived' alert that cancels the archive before it is sent.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get sessionListArchiveUndo;

  /// Title of the desktop alert shown before archiving a session that is still running.
  ///
  /// In en, this message translates to:
  /// **'Archive a running session?'**
  String get sessionListArchiveRunningTitle;

  /// Body of the desktop alert shown before archiving a running session.
  ///
  /// In en, this message translates to:
  /// **'“{title}” is still running. Archiving makes it permanently read-only.'**
  String sessionListArchiveRunningMessage(String title);

  /// Title of the desktop alert shown when the bridge refuses to delete a session's worktree while archiving.
  ///
  /// In en, this message translates to:
  /// **'The worktree can’t be deleted safely'**
  String get sessionListArchiveRefusedTitle;

  /// Destructive button on both cleanup refusal modals that retries the archive or delete with force, so the worktree and the work in it are removed.
  ///
  /// In en, this message translates to:
  /// **'Delete anyway'**
  String get sessionListCleanupDeleteAnyway;

  /// Informational line shown after an archive or delete that could not remove a shared worktree. Not a question: nothing was lost and there is nothing to decide.
  ///
  /// In en, this message translates to:
  /// **'Another session is still using the worktree, so it was left in place.'**
  String get sessionListCleanupWorktreeKept;

  /// Title of the desktop delete alert, naming the session.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”?'**
  String sessionListDeleteNamedTitle(String title);

  /// Line in the delete confirmation, on both shells, stating that a session with a dedicated worktree loses it. Deletion never offers a choice about this.
  ///
  /// In en, this message translates to:
  /// **'Its worktree will be deleted too. The branch is kept.'**
  String get sessionListDeleteWorktreeNotice;

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
  /// **'Sign in with email'**
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

  /// Shown when the user declined a browser sign-in on the confirmation page or at the provider.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was declined. The browser page did not confirm this sign-in.'**
  String get loginDeclined;

  /// Link that abandons a browser sign-in that is waiting for the user.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get loginCancel;

  /// Link under the email sign-in form that returns to the provider buttons.
  ///
  /// In en, this message translates to:
  /// **'Other ways to sign in'**
  String get loginOtherWaysToSignIn;

  /// One-line pitch on the desktop sign-in window's brand panel.
  ///
  /// In en, this message translates to:
  /// **'Watch and steer your coding sessions from your desk or your phone.'**
  String get desktopLoginTagline;

  /// No description provided for @desktopLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get desktopLoginTitle;

  /// No description provided for @desktopLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the same account as on your phone.'**
  String get desktopLoginSubtitle;

  /// No description provided for @desktopLoginContinueWithGithub.
  ///
  /// In en, this message translates to:
  /// **'Continue with GitHub'**
  String get desktopLoginContinueWithGithub;

  /// No description provided for @desktopLoginContinueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get desktopLoginContinueWithApple;

  /// No description provided for @desktopLoginContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get desktopLoginContinueWithGoogle;

  /// Marker on the desktop sign-in method this device signed in with last.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get desktopLoginLastUsed;

  /// Subtitle above the desktop email sign-in form.
  ///
  /// In en, this message translates to:
  /// **'For accounts created with an email and password.'**
  String get desktopLoginEmailSubtitle;

  /// No description provided for @desktopLoginWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue in your browser'**
  String get desktopLoginWaitingTitle;

  /// Desktop card shown while a browser sign-in waits. The device is the name the browser page asks the user to confirm.
  ///
  /// In en, this message translates to:
  /// **'We opened {provider} sign-in in your browser. The page will ask you to confirm “{device}”. Come back here when it is done.'**
  String desktopLoginWaitingMessage(String provider, String device);

  /// Countdown on the desktop browser sign-in card, in minutes and seconds.
  ///
  /// In en, this message translates to:
  /// **'The link expires in {time}'**
  String desktopLoginExpiresIn(String time);

  /// No description provided for @desktopLoginOpenAgain.
  ///
  /// In en, this message translates to:
  /// **'Open again'**
  String get desktopLoginOpenAgain;

  /// No description provided for @desktopLoginCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get desktopLoginCopyLink;

  /// No description provided for @desktopLoginLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get desktopLoginLinkCopied;

  /// No description provided for @desktopLoginCancelHandoff.
  ///
  /// In en, this message translates to:
  /// **'Cancel and choose another way'**
  String get desktopLoginCancelHandoff;

  /// No description provided for @desktopLoginBrowserFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open your browser'**
  String get desktopLoginBrowserFailedTitle;

  /// No description provided for @desktopLoginBrowserFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy the link, open it in any browser on this computer, and finish signing in there. We are still waiting.'**
  String get desktopLoginBrowserFailedMessage;

  /// Button that tries again to open the sign-in page in the browser.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get desktopLoginTryAgain;

  /// No description provided for @desktopLoginExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'The sign-in link expired'**
  String get desktopLoginExpiredTitle;

  /// No description provided for @desktopLoginExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing was confirmed in the browser within 5 minutes. Choose a way to sign in again.'**
  String get desktopLoginExpiredMessage;

  /// No description provided for @desktopLoginDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was declined'**
  String get desktopLoginDeclinedTitle;

  /// No description provided for @desktopLoginDeclinedMessage.
  ///
  /// In en, this message translates to:
  /// **'The browser page did not confirm this sign-in. Choose a way to sign in again.'**
  String get desktopLoginDeclinedMessage;

  /// Screen-reader label for a session an agent is actively working in; the visual signal is the twinkling sparkle
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get sessionListRunning;

  /// Shown on a session row, in place of its last-activity time, while the bridge has scheduled an automatic continuation after a quota reset. The time is local, with the date only when it is not today.
  ///
  /// In en, this message translates to:
  /// **'Resumes {time}'**
  String sessionListResumes(String time);

  /// Screen-reader and tooltip wording for a session row whose automatic continuation is scheduled; the time includes the date.
  ///
  /// In en, this message translates to:
  /// **'Resumes at {time}'**
  String sessionListResumesAtDescription(String time);

  /// Screen-reader label for a session with unopened agent activity; the visual signal is the resting sparkle
  ///
  /// In en, this message translates to:
  /// **'New activity'**
  String get sessionListNewActivity;

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

  /// Amber word leading a session row's meta line while the session waits for the user's answer or permission
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get sessionListWaiting;

  /// Label showing the number of active background tasks for a session
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 background task} other{{count} background tasks}}'**
  String sessionListBackgroundTasks(int count);

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

  /// Persistent composer status shown after a retryable async transcription failure.
  ///
  /// In en, this message translates to:
  /// **'Recording saved'**
  String get voiceRecordingSaved;

  /// No description provided for @voiceRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get voiceRetry;

  /// No description provided for @voiceDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get voiceDiscard;

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
  /// **'Transcription failed. Record again or type instead.'**
  String get voiceErrorTranscription;

  /// No description provided for @voiceErrorSavedRecordingMissing.
  ///
  /// In en, this message translates to:
  /// **'The saved recording is no longer available. Record again or type instead.'**
  String get voiceErrorSavedRecordingMissing;

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
  /// **'Add project'**
  String get addProject;

  /// Primary action of the add-project sheet: registers the folder the browser is currently showing as a Sesori project.
  ///
  /// In en, this message translates to:
  /// **'Add {folder}'**
  String addFolderAsProject(String folder);

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

  /// Add-project browser: the folder being browsed has no subfolders to list.
  ///
  /// In en, this message translates to:
  /// **'No folders here'**
  String get folderBrowserNoFolders;

  /// Second line under folderBrowserNoFolders. The browser lists folders only, so the folder may still hold files.
  ///
  /// In en, this message translates to:
  /// **'Only folders are listed, so any files in it stay hidden.'**
  String get folderBrowserNoFoldersDetail;

  /// Breadcrumb segment and shortcut button in the add-project browser that stand for the host user's home folder.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get folderPickerHome;

  /// Shortcut button that jumps to the host filesystem root in the add-project browser. Shown on hosts without drive letters.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get folderPickerRoot;

  /// Accessibility label for the up-arrow button at the start of the add-project browser's breadcrumb, which opens the parent of the folder being browsed.
  ///
  /// In en, this message translates to:
  /// **'Parent folder'**
  String get folderBrowserParentFolder;

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
  /// **'Hide project'**
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
  /// **'Continue without Git'**
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
  /// **'The bridge can\'t access this folder. On macOS, grant Full Disk Access to the process running the bridge (the Sesori app/helper or Terminal) in System Settings → Privacy & Security → Full Disk Access, then retry.'**
  String get fetchDirectoryPermissionDenied;

  /// No description provided for @addProjectPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'The bridge can\'t access that folder. Grant the process running the bridge (the Sesori app/helper or Terminal) Full Disk Access on your Mac, then try again.'**
  String get addProjectPermissionDenied;

  /// No description provided for @filesystemAccessDegradedTitle.
  ///
  /// In en, this message translates to:
  /// **'Limited folder access'**
  String get filesystemAccessDegradedTitle;

  /// No description provided for @filesystemAccessDegradedBody.
  ///
  /// In en, this message translates to:
  /// **'The bridge can\'t read some folders. On macOS, grant Full Disk Access to the process running the bridge (the Sesori app/helper or Terminal) in System Settings → Privacy & Security.'**
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

  /// No description provided for @needsYouAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get needsYouAnswer;

  /// No description provided for @needsYouReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get needsYouReview;

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
  /// **'Rename session'**
  String get renameSessionTitle;

  /// No description provided for @renameProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename project'**
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
  /// **'New worktree'**
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

  /// No description provided for @newSessionOptionsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry loading models'**
  String get newSessionOptionsRetry;

  /// No description provided for @newSessionOptionsLoad.
  ///
  /// In en, this message translates to:
  /// **'Load models'**
  String get newSessionOptionsLoad;

  /// Warning title shown when the selected coding harness has no authenticated provider/model available for this project.
  ///
  /// In en, this message translates to:
  /// **'{plugin} login required'**
  String newSessionAuthenticationRequiredTitle(String plugin);

  /// No description provided for @newSessionProjectUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t verify whether this project supports worktrees. Try again before creating the session.'**
  String get newSessionProjectUnavailable;

  /// No description provided for @sessionDetailArchivedNotice.
  ///
  /// In en, this message translates to:
  /// **'This session is archived and read-only.'**
  String get sessionDetailArchivedNotice;

  /// No description provided for @sessionDetailHarnessFallbackName.
  ///
  /// In en, this message translates to:
  /// **'This harness'**
  String get sessionDetailHarnessFallbackName;

  /// No description provided for @sessionDetailHarnessDisabledReason.
  ///
  /// In en, this message translates to:
  /// **'{harnessName} is disabled.'**
  String sessionDetailHarnessDisabledReason(String harnessName);

  /// No description provided for @sessionDetailHarnessAuthenticationReason.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {harnessName} to continue.'**
  String sessionDetailHarnessAuthenticationReason(String harnessName);

  /// No description provided for @sessionDetailHarnessRuntimeMissingReason.
  ///
  /// In en, this message translates to:
  /// **'{harnessName} is not installed or cannot be used.'**
  String sessionDetailHarnessRuntimeMissingReason(String harnessName);

  /// No description provided for @sessionDetailHarnessUnavailableReason.
  ///
  /// In en, this message translates to:
  /// **'{harnessName} is unavailable.'**
  String sessionDetailHarnessUnavailableReason(String harnessName);

  /// No description provided for @sessionDetailHarnessStoppingReason.
  ///
  /// In en, this message translates to:
  /// **'{harnessName} is stopping.'**
  String sessionDetailHarnessStoppingReason(String harnessName);

  /// No description provided for @sessionDetailHarnessNotInspectedReason.
  ///
  /// In en, this message translates to:
  /// **'{harnessName} has not been checked yet.'**
  String sessionDetailHarnessNotInspectedReason(String harnessName);

  /// No description provided for @sessionDetailHarnessUnknownReason.
  ///
  /// In en, this message translates to:
  /// **'{harnessName} reported an unknown status.'**
  String sessionDetailHarnessUnknownReason(String harnessName);

  /// No description provided for @sessionDetailHarnessMissingReason.
  ///
  /// In en, this message translates to:
  /// **'This session’s harness is not available on the connected bridge.'**
  String get sessionDetailHarnessMissingReason;

  /// No description provided for @sessionDetailHarnessCheckFailedReason.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t check whether this session’s harness is available.'**
  String get sessionDetailHarnessCheckFailedReason;

  /// No description provided for @sessionDetailContentLoadFailedReason.
  ///
  /// In en, this message translates to:
  /// **'The harness is available, but chat content or options could not be loaded. Reopen the chat to try again.'**
  String get sessionDetailContentLoadFailedReason;

  /// No description provided for @sessionDetailHarnessCheckingReason.
  ///
  /// In en, this message translates to:
  /// **'Checking whether this session’s harness is available…'**
  String get sessionDetailHarnessCheckingReason;

  /// No description provided for @sessionDetailHarnessHistoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Chat history for this session still needs the harness. Enable it to load the transcript.'**
  String get sessionDetailHarnessHistoryUnavailable;

  /// No description provided for @sessionDetailHarnessRefreshWarning.
  ///
  /// In en, this message translates to:
  /// **'Harness status could not be refreshed. The last known status is shown.'**
  String get sessionDetailHarnessRefreshWarning;

  /// No description provided for @sessionDetailOpenHarnessSettings.
  ///
  /// In en, this message translates to:
  /// **'Open harness settings'**
  String get sessionDetailOpenHarnessSettings;

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

  /// No description provided for @sessionListForceMessage.
  ///
  /// In en, this message translates to:
  /// **'The following issues were found:'**
  String get sessionListForceMessage;

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
  /// **'Allow this action?'**
  String get diffPermissionRequestTitle;

  /// No description provided for @diffPermissionReject.
  ///
  /// In en, this message translates to:
  /// **'Don’t allow'**
  String get diffPermissionReject;

  /// No description provided for @diffPermissionOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get diffPermissionOnce;

  /// No description provided for @diffPermissionAlwaysAllow.
  ///
  /// In en, this message translates to:
  /// **'Always approve'**
  String get diffPermissionAlwaysAllow;

  /// No description provided for @diffFileChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'File changes'**
  String get diffFileChangesTitle;

  /// No description provided for @diffFilesChangedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} file{count, plural, =1{} other{s}} changed'**
  String diffFilesChangedCount(int count);

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

  /// Quiet transcript row marking where the coding agent summarized its earlier conversation to free context space.
  ///
  /// In en, this message translates to:
  /// **'Context compacted'**
  String get sessionDetailContextCompacted;

  /// Title of the modal showing the summary the coding agent carried forward when it compacted its context.
  ///
  /// In en, this message translates to:
  /// **'Compaction summary'**
  String get sessionDetailCompactionSummaryTitle;

  /// No description provided for @sessionDetailCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get sessionDetailCopy;

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
  /// **'Know when a session needs you.'**
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

  /// Caption under the pull-to-refresh spinner once the pull has passed the ordinary trigger, inviting the user to keep pulling to start a full catalog scan. Names what the user gets rather than the mechanism: scanning harnesses is how it works, not what it is for.
  ///
  /// In en, this message translates to:
  /// **'Keep pulling to find new sessions'**
  String get catalogScanPullCaption;

  /// Ordinary title of the row above a list while a catalog scan is in flight, including the number of terminal harnesses.
  ///
  /// In en, this message translates to:
  /// **'Scanning · {finished} of {total} finished'**
  String catalogScanRunningTitle(int finished, int total);

  /// Supporting line before one pending harness reports catalog progress.
  ///
  /// In en, this message translates to:
  /// **'Preparing {harness} scan…'**
  String catalogScanPreparingOneDetail(String harness);

  /// Supporting line while a fresh management snapshot authoritatively reports the named harness as starting.
  ///
  /// In en, this message translates to:
  /// **'Starting {harness}…'**
  String catalogScanStartingDetail(String harness);

  /// Supporting line while the named harness is enumerating but has not found a session yet.
  ///
  /// In en, this message translates to:
  /// **'Reading {harness} sessions…'**
  String catalogScanReadingDetail(String harness);

  /// Supporting line while the named harness enumerates sessions.
  ///
  /// In en, this message translates to:
  /// **'{harness} — {sessions, plural, =1{1 session found} other{{sessions} sessions found}}'**
  String catalogScanReadingCountDetail(String harness, int sessions);

  /// Supporting line while the named harness commits its catalog snapshot.
  ///
  /// In en, this message translates to:
  /// **'Saving {harness} scan results…'**
  String catalogScanSavingDetail(String harness);

  /// Title after one harness has remained authoritatively in startup for three seconds, including the number of terminal harnesses.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {harness} · {finished} of {total} finished'**
  String catalogScanWaitingTitle(String harness, int finished, int total);

  /// Wrapped explanation after one harness has remained authoritatively in startup for three seconds.
  ///
  /// In en, this message translates to:
  /// **'{harness} must finish starting before scanning can continue. You can keep browsing.'**
  String catalogScanWaitingDetail(String harness);

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
  /// **'Scanning finished'**
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
  /// **'Check bridge logs'**
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

  /// Title of the scan row when a deep pull cannot start because there is no live bridge connection.
  ///
  /// In en, this message translates to:
  /// **'Bridge not connected'**
  String get catalogScanNotConnectedTitle;

  /// Supporting line on the not-connected scan row, naming what the user must do before scanning.
  ///
  /// In en, this message translates to:
  /// **'Connect to a bridge to scan'**
  String get catalogScanNotConnectedDetail;

  /// Title of the scan row when the connected bridge has no harness ready to scan, or has not reported its harnesses yet.
  ///
  /// In en, this message translates to:
  /// **'No harness to scan'**
  String get catalogScanNoHarnessTitle;

  /// Supporting line on the no-harness scan row, naming where the user can see and fix their harness setup.
  ///
  /// In en, this message translates to:
  /// **'Check your harnesses in Settings'**
  String get catalogScanNoHarnessDetail;

  /// Popup shown on Settings to Harnesses when a scan started there finishes. The placeholder is the same result wording the lists' scan row uses, so one scan reads the same everywhere.
  ///
  /// In en, this message translates to:
  /// **'Scan complete — {result}'**
  String harnessManagementScanFinished(String result);

  /// Popup shown on Settings to Harnesses when a scan started there finished with some harnesses failing. Both counts are at least one, so the total is always plural.
  ///
  /// In en, this message translates to:
  /// **'{failed} of {total} harnesses could not be scanned'**
  String harnessManagementScanPartlyFailed(int failed, int total);

  /// Popup shown on Settings to Harnesses when a scan started there failed outright. Names the bridge log because this outcome comes from the bridge's own progress events, unlike a request that never reached it.
  ///
  /// In en, this message translates to:
  /// **'Scan failed. Check the bridge log for details'**
  String get harnessManagementScanFinishedFailed;

  /// Settings action on a harness card that re-imports that one harness's catalog, the pointer-and-keyboard equivalent of the lists' deep pull.
  ///
  /// In en, this message translates to:
  /// **'Scan for sessions'**
  String get harnessManagementScan;

  /// Supporting line under the per-harness scan action, saying what scanning does.
  ///
  /// In en, this message translates to:
  /// **'Find sessions created or moved outside Sesori and reload their latest messages.'**
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

  /// No description provided for @harnessManagementRefreshSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Recheck installation, sign-in and runtime status.'**
  String get harnessManagementRefreshSetupDescription;

  /// No description provided for @harnessManagementRestartDescription.
  ///
  /// In en, this message translates to:
  /// **'Restart {name}. Active sessions need your confirmation.'**
  String harnessManagementRestartDescription(String name);

  /// No description provided for @harnessManagementIdleTimeoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Stop this harness after the selected time without an active session.'**
  String get harnessManagementIdleTimeoutDescription;

  /// No description provided for @harnessesNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get harnessesNeedsAttention;

  /// No description provided for @harnessesNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get harnessesNotInstalled;

  /// No description provided for @harnessesStatusSetupSection.
  ///
  /// In en, this message translates to:
  /// **'Status & setup'**
  String get harnessesStatusSetupSection;

  /// No description provided for @harnessesActionsSection.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get harnessesActionsSection;

  /// No description provided for @harnessesAutomationSection.
  ///
  /// In en, this message translates to:
  /// **'Automation'**
  String get harnessesAutomationSection;

  /// No description provided for @harnessesStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get harnessesStatusLabel;

  /// No description provided for @harnessesVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get harnessesVersionLabel;

  /// No description provided for @harnessesActivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get harnessesActivityLabel;

  /// No description provided for @harnessesInstallingStatus.
  ///
  /// In en, this message translates to:
  /// **'Installing'**
  String get harnessesInstallingStatus;

  /// No description provided for @harnessesInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Install {name}'**
  String harnessesInstallTitle(String name);

  /// No description provided for @harnessesInstallingTitle.
  ///
  /// In en, this message translates to:
  /// **'Installing {name}'**
  String harnessesInstallingTitle(String name);

  /// No description provided for @harnessesInstallDescription.
  ///
  /// In en, this message translates to:
  /// **'Install this harness on your connected computer to use it in Sesori.'**
  String get harnessesInstallDescription;

  /// No description provided for @harnessesStartInstallation.
  ///
  /// In en, this message translates to:
  /// **'Start installation'**
  String get harnessesStartInstallation;

  /// No description provided for @harnessesRestartInstallation.
  ///
  /// In en, this message translates to:
  /// **'Restart installation'**
  String get harnessesRestartInstallation;

  /// No description provided for @harnessesInstallationFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation failed'**
  String get harnessesInstallationFailed;

  /// No description provided for @harnessesInstallationFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Start the installation again when you’re ready.'**
  String get harnessesInstallationFailedDescription;

  /// No description provided for @harnessesEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} enabled'**
  String harnessesEnabledLabel(String name);

  /// No description provided for @harnessesUpdatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Updating {name}'**
  String harnessesUpdatingLabel(String name);

  /// No description provided for @harnessesForceRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart {name}?'**
  String harnessesForceRestartTitle(String name);

  /// No description provided for @harnessesForceRestartDescription.
  ///
  /// In en, this message translates to:
  /// **'{name} may be active in a session. Force restarting can interrupt active work.'**
  String harnessesForceRestartDescription(String name);

  /// No description provided for @harnessesForceRestartAction.
  ///
  /// In en, this message translates to:
  /// **'Force restart'**
  String get harnessesForceRestartAction;

  /// No description provided for @harnessesStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get harnessesStatusIdle;

  /// No description provided for @harnessesStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get harnessesStatusRunning;

  /// No description provided for @archivedSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Archived sessions'**
  String get archivedSessionsTitle;

  /// No description provided for @archivedSessionsClose.
  ///
  /// In en, this message translates to:
  /// **'Close archived sessions'**
  String get archivedSessionsClose;

  /// Date heading shared by regular and archived session lists.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get archivedSessionsToday;

  /// Date heading shared by regular and archived session lists.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get archivedSessionsYesterday;

  /// Date heading shared by regular and archived session lists.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get archivedSessionsThisWeek;

  /// Date heading shared by regular and archived session lists.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get archivedSessionsLastWeek;

  /// Date heading shared by regular and archived session lists.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get archivedSessionsThisMonth;

  /// Date heading shared by regular and archived session lists.
  ///
  /// In en, this message translates to:
  /// **'One month ago'**
  String get archivedSessionsLastMonth;

  /// No description provided for @sessionAutoContinuationMenu.
  ///
  /// In en, this message translates to:
  /// **'Auto continuation'**
  String get sessionAutoContinuationMenu;

  /// No description provided for @sessionAutoContinuationAfterQuotaResets.
  ///
  /// In en, this message translates to:
  /// **'After quota resets'**
  String get sessionAutoContinuationAfterQuotaResets;

  /// No description provided for @sessionAutoContinuationEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable auto continuation'**
  String get sessionAutoContinuationEnable;

  /// No description provided for @sessionAutoContinuationDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get sessionAutoContinuationDisable;

  /// No description provided for @sessionAutoContinuationOn.
  ///
  /// In en, this message translates to:
  /// **'Auto continuation on'**
  String get sessionAutoContinuationOn;

  /// Label of the quiet chip beside the session's model picker while auto continuation is enabled and nothing is due. Tapping it offers Disable.
  ///
  /// In en, this message translates to:
  /// **'Auto-continue'**
  String get sessionAutoContinuationChip;

  /// No description provided for @sessionAutoContinuationQuotaReached.
  ///
  /// In en, this message translates to:
  /// **'Quota reached'**
  String get sessionAutoContinuationQuotaReached;

  /// No description provided for @sessionAutoContinuationOlderBridge.
  ///
  /// In en, this message translates to:
  /// **'Update your bridge to use auto continuation.'**
  String get sessionAutoContinuationOlderBridge;

  /// No description provided for @sessionAutoContinuationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Auto continuation is unavailable for this harness or provider.'**
  String get sessionAutoContinuationUnavailable;

  /// No description provided for @sessionAutoContinuationOffer.
  ///
  /// In en, this message translates to:
  /// **'Continue at {time} and two minutes after each later quota reset. Keep your bridge running.'**
  String sessionAutoContinuationOffer(String time);

  /// No description provided for @sessionAutoContinuationScheduled.
  ///
  /// In en, this message translates to:
  /// **'Continues at {time}. Keep your bridge running.'**
  String sessionAutoContinuationScheduled(String time);

  /// No description provided for @sessionAutoContinuationResetUnknown.
  ///
  /// In en, this message translates to:
  /// **'Reset time unavailable. Auto continuation cannot be scheduled.'**
  String get sessionAutoContinuationResetUnknown;

  /// No description provided for @sessionAutoContinuationPausedWork.
  ///
  /// In en, this message translates to:
  /// **'Paused while this session has active or queued work. Checks resume automatically.'**
  String get sessionAutoContinuationPausedWork;

  /// No description provided for @sessionAutoContinuationPausedInput.
  ///
  /// In en, this message translates to:
  /// **'Paused until you answer the pending question or permission request.'**
  String get sessionAutoContinuationPausedInput;

  /// No description provided for @sessionAutoContinuationPausedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Paused while the harness is unavailable. Checks resume automatically.'**
  String get sessionAutoContinuationPausedUnavailable;

  /// No description provided for @sessionAutoContinuationPausedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Paused because the session could not be checked. Checks resume automatically.'**
  String get sessionAutoContinuationPausedUnknown;

  /// No description provided for @sessionAutoContinuationUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'The last attempt could not be confirmed. It will not be sent again automatically.'**
  String get sessionAutoContinuationUnconfirmed;

  /// No description provided for @sessionAutoContinuationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Continuation sent at {time}. Enabled for future quota resets.'**
  String sessionAutoContinuationSubmitted(String time);

  /// No description provided for @sessionAutoContinuationFailed.
  ///
  /// In en, this message translates to:
  /// **'The continuation could not be sent. This attempt will not be retried automatically.'**
  String get sessionAutoContinuationFailed;

  /// No description provided for @sessionAutoContinuationStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable. A scheduled time cannot be confirmed.'**
  String get sessionAutoContinuationStatusUnknown;

  /// No description provided for @sessionAutoContinuationUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm the change. Reconnect and check auto continuation before trying again.'**
  String get sessionAutoContinuationUpdateFailed;

  /// No description provided for @sessionAutoContinuationAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Auto continuation disabled. The previous continuation was already sent; future automatic sends are disabled.'**
  String get sessionAutoContinuationAlreadySubmitted;
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
