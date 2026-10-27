import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart" show FontLoader, LogicalKeyboardKey, rootBundle;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_desktop/core/widgets/desktop_command_palette.dart";
import "package:sesori_desktop/core/widgets/desktop_escape_dismissal.dart";
import "package:sesori_desktop/features/auth_gate/auth_gate.dart";
import "package:sesori_desktop/features/settings/desktop_settings_modal.dart";
import "package:sesori_desktop/features/settings/desktop_update_section.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _MockAuthGateCubit() extends MockCubit<AuthGateState> implements AuthGateCubit;
class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
class _MockFileAccessCubit() extends MockCubit<FileAccessState> implements FileAccessCubit;
class _MockAppearanceStore() extends Mock implements AppearanceStore;
class _MockChatInputModeStore() extends Mock implements ChatInputModeStore;
class _MockBridgeSettingsService() extends Mock implements BridgeSettingsService;
class _MockConnectionService() extends Mock implements ConnectionService;
class _MockProductAnalyticsService() extends Mock implements ProductAnalyticsService;
class _MockPluginManagementService() extends Mock implements PluginManagementService;
class _MockDesktopAttentionService() extends Mock implements DesktopAttentionService;
class _MockDesktopUpdateService() extends Mock implements DesktopUpdateService;
class _MockUrlLauncher() extends Mock implements UrlLauncher;
class _MockComputerSwitchDispatcher() extends Mock implements ComputerSwitchDispatcher;
class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;
class _MockConnectionOverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit;

/// A desktop whose own bridge is [bridgeId].
class const _LocalBridge({required final String bridgeId}) implements ActiveBridgeLocality {
  @override
  String? get localBridgeId => bridgeId;

  @override
  Stream<String?> get localBridgeIdStream => Stream.value(bridgeId);

  @override
  bool isLocalBridge({required String bridgeId}) => bridgeId == this.bridgeId;
}

const _demo = ProjectSummary(id: "demo", name: "demo-app", path: "/work/demo-app", time: null);

const AuthUser _user = AuthUser(
  id: "user-1",
  provider: AuthProvider.github,
  providerUserId: "gh-1",
  providerUsername: "alex",
);
const ServerConnectionConfig _connectionConfig = ServerConnectionConfig(
  relayHost: "relay.example.com",
  authToken: null,
  bridgeId: null,
);
const HealthResponse _health = HealthResponse(
  healthy: true,
  version: "test",
  filesystemAccessDegraded: false,
);
const ConnectionStatus _connected = ConnectionStatus.connected(config: _connectionConfig, health: _health);
const PluginManagementMetadata _plugin = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "opencode",
    displayName: "OpenCode",
    state: PluginSetupState.ready,
    runtimeVersion: null,
    actionHint: null,
  ),
  runtimeState: PluginRuntimeState.active,
  workState: PluginManagementWorkState.idle,
  idleTimeoutMins: 10,
  hasIdleTimeoutOverride: false,
  managementCapabilities: {PluginManagementCapability.setupRefresh},
  actionHint: null,
);
const PluginManagementResponse _pluginResponse = PluginManagementResponse(
  snapshotToken: "snapshot-1",
  bridgeId: "bridge-1",
  defaultPluginId: "opencode",
  defaultIdleTimeoutMins: 10,
  plugins: [_plugin],
);
const _bridgeState = BridgeControlState(
  trayAvailability: SystemTrayAvailability.available,
  activity: BridgeControlActivity.idle,
  statusLabel: "Off",
  processState: BridgeProcessStopped(),
  desiredState: BridgeProcessDesiredState.off,
  toggleTarget: BridgeProcessDesiredState.on,
  launchAtLoginEnabled: false,
  controlStatus: BridgeControlStatus.offline,
  updateState: DesktopUpdateManagedBySystem(),
);

void main() {
  setUpAll(() async {
    // Ahem's uniform advances do not represent the packaged settings font at large text scales.
    final font = FontLoader("packages/theme_prego/Satoshi Prego");
    for (final weight in ["Regular", "Medium", "Bold"]) {
      font.addFont(rootBundle.load("packages/theme_prego/assets/fonts/SatoshiPrego/SatoshiPrego-$weight.otf"));
    }
    await font.load();
    registerFallbackValue(AppearanceMode.system);
    registerFallbackValue(ChatInputMode.voiceFirst);
    registerFallbackValue(DesktopAttentionPreference.enabled);
    registerFallbackValue(DesktopAutomaticUpdates.enabled);
    registerFallbackValue(ComputerSwitchSource.settings);
  });

  late _MockAuthGateCubit authGateCubit;
  late _MockBridgeControlCubit bridgeControl;
  late _MockAppearanceStore appearanceStore;
  late AppearanceCubit appearanceCubit;
  late ChatInputModeCubit chatInputModeCubit;
  late _MockBridgeSettingsService bridgeSettingsService;
  late _MockDesktopAttentionService desktopAttentionService;
  late _MockPluginManagementService pluginService;
  late BehaviorSubject<ConnectionStatus> connectionStatuses;
  late BehaviorSubject<DesktopAttentionPreference> attentionPreferences;
  late _MockDesktopUpdateService desktopUpdateService;
  late BehaviorSubject<DesktopUpdateState> updateStates;
  late BehaviorSubject<DesktopAutomaticUpdates> automaticUpdates;
  late BehaviorSubject<ProductAnalyticsState> analyticsStates;
  late BehaviorSubject<PluginManagementLoadResult> pluginSnapshots;
  late BehaviorSubject<Map<String, PluginInstallState>> installStates;
  late BehaviorSubject<Map<String, PluginAuthenticationChallenge>> authenticationChallenges;
  late BehaviorSubject<Map<String, PluginAuthenticationBrowserState>> authenticationBrowserStates;
  late StreamController<PluginAuthenticationTerminalUpdate> authenticationTerminal;
  late int logoutCompletions;
  late _MockFileAccessCubit fileAccess;
  late MockRegisteredBridgesService registeredBridges;
  late _MockComputerSwitchDispatcher computerSwitchDispatcher;
  late _MockProjectListCubit projectList;
  late _MockConnectionOverlayCubit connectionOverlay;

  setUp(() async {
    await getIt.reset();
    PackageInfo.setMockInitialValues(
      appName: "Sesori",
      packageName: "com.sesori.desktop",
      version: "0.1.0",
      buildNumber: "1",
      buildSignature: "",
    );
    logoutCompletions = 0;
    fileAccess = _MockFileAccessCubit();
    whenListen(
      fileAccess,
      const Stream<FileAccessState>.empty(),
      initialState: const FileAccessState(status: FileAccessStatus.unsupported, dismissed: false),
    );
    when(fileAccess.openSystemSettings).thenAnswer((_) async {});
    authGateCubit = _MockAuthGateCubit();
    whenListen(
      authGateCubit,
      const Stream<AuthGateState>.empty(),
      initialState: const AuthGateState.signedIn(user: _user),
    );
    bridgeControl = _MockBridgeControlCubit();
    whenListen(bridgeControl, const Stream<BridgeControlState>.empty(), initialState: _bridgeState);
    when(bridgeControl.refreshLaunchAtLogin).thenAnswer((_) async {});
    when(() => bridgeControl.setLaunchAtLogin(enabled: any(named: "enabled"))).thenAnswer((_) async {});
    when(bridgeControl.openLogs).thenAnswer((_) async {});
    appearanceStore = _MockAppearanceStore();
    final chatInputModeStore = _MockChatInputModeStore();
    when(() => appearanceStore.write(mode: any(named: "mode"))).thenAnswer((_) async {});
    when(() => chatInputModeStore.write(mode: any(named: "mode"))).thenAnswer((_) async {});
    appearanceCubit = AppearanceCubit(store: appearanceStore, initialMode: AppearanceMode.system);
    chatInputModeCubit = ChatInputModeCubit(store: chatInputModeStore, initialMode: ChatInputMode.voiceFirst);
    final connectionService = _MockConnectionService();
    connectionStatuses = BehaviorSubject<ConnectionStatus>.seeded(_connected);
    when(() => connectionService.currentStatus).thenAnswer((_) => connectionStatuses.value);
    when(() => connectionService.status).thenAnswer((_) => connectionStatuses.stream);
    bridgeSettingsService = _MockBridgeSettingsService();
    when(bridgeSettingsService.load).thenAnswer(
      (_) async => const BridgeSettingsLoadSupported(
        response: BridgeSettingsResponse(
          pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
          yolo: YoloSettingsResponse(enabled: false),
          warmUpPluginsOnSessionOpen: true,
        ),
      ),
    );
    getIt.registerSingleton<BridgeSettingsService>(bridgeSettingsService);
    getIt.registerSingleton<ConnectionService>(connectionService);
    attentionPreferences = BehaviorSubject<DesktopAttentionPreference>.seeded(DesktopAttentionPreference.enabled);
    desktopAttentionService = _MockDesktopAttentionService();
    when(() => desktopAttentionService.currentPreference).thenAnswer((_) => attentionPreferences.value);
    when(() => desktopAttentionService.preference).thenAnswer((_) => attentionPreferences.stream);
    when(() => desktopAttentionService.setPreference(preference: any(named: "preference")))
        .thenAnswer((invocation) async {
          attentionPreferences.add(invocation.namedArguments[#preference]! as DesktopAttentionPreference);
        });
    getIt.registerSingleton<DesktopAttentionService>(desktopAttentionService);
    updateStates = BehaviorSubject<DesktopUpdateState>.seeded(
      const DesktopUpdateUnavailable(reason: DesktopUpdateUnavailableReason.developmentBuild),
    );
    automaticUpdates = BehaviorSubject<DesktopAutomaticUpdates>.seeded(DesktopAutomaticUpdates.enabled);
    desktopUpdateService = _MockDesktopUpdateService();
    when(() => desktopUpdateService.states).thenAnswer((_) => updateStates.stream);
    when(() => desktopUpdateService.currentState).thenAnswer((_) => updateStates.value);
    when(() => desktopUpdateService.installKind).thenReturn(DesktopInstallKind.linuxPackage);
    when(() => desktopUpdateService.automaticUpdates).thenAnswer((_) => automaticUpdates.stream);
    when(() => desktopUpdateService.currentAutomaticUpdates).thenAnswer((_) => automaticUpdates.value);
    when(() => desktopUpdateService.setAutomaticUpdates(preference: any(named: "preference"))).thenAnswer((
      invocation,
    ) async {
      automaticUpdates.add(invocation.namedArguments[#preference]! as DesktopAutomaticUpdates);
    });
    getIt.registerSingleton<DesktopUpdateService>(desktopUpdateService);
    analyticsStates = BehaviorSubject<ProductAnalyticsState>.seeded(
      const ProductAnalyticsState(
        preference: ProductAnalyticsPreferenceKnown(preference: ProductAnalyticsPreference.enabled),
        synchronization: ProductAnalyticsSynchronized(),
        availability: ProductAnalyticsInactive(reason: ProductAnalyticsInactiveReason.runtimeUnavailable),
      ),
    );
    final analyticsService = _MockProductAnalyticsService();
    when(() => analyticsService.state).thenAnswer((_) => analyticsStates.value);
    when(() => analyticsService.stateStream).thenAnswer((_) => analyticsStates.stream);
    getIt.registerSingleton<ProductAnalyticsService>(analyticsService);
    pluginSnapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
      const PluginManagementLoadResult.supported(response: _pluginResponse, refreshError: null),
    );
    installStates = BehaviorSubject<Map<String, PluginInstallState>>.seeded(const {});
    authenticationChallenges = BehaviorSubject<Map<String, PluginAuthenticationChallenge>>.seeded(const {});
    authenticationBrowserStates = BehaviorSubject<Map<String, PluginAuthenticationBrowserState>>.seeded(const {});
    authenticationTerminal = StreamController<PluginAuthenticationTerminalUpdate>.broadcast(sync: true);
    pluginService = _MockPluginManagementService();
    when(() => pluginService.snapshots).thenAnswer((_) => pluginSnapshots.stream);
    when(() => pluginService.installStates).thenAnswer((_) => installStates.stream);
    when(() => pluginService.authenticationChallenges).thenAnswer((_) => authenticationChallenges.stream);
    when(() => pluginService.authenticationBrowserStates).thenAnswer((_) => authenticationBrowserStates.stream);
    when(() => pluginService.authenticationTerminal).thenAnswer((_) => authenticationTerminal.stream);
    when(pluginService.onDispose).thenAnswer((_) async {});
    getIt.registerSingleton<PluginManagementService>(pluginService);
    getIt.registerSingleton<UrlLauncher>(_MockUrlLauncher());
    registeredBridges = MockRegisteredBridgesService();
    getIt.registerSingleton<RegisteredBridgesService>(registeredBridges);
    getIt.registerSingleton<SelectedComputerService>(FakeSelectedComputerService());
    getIt.registerSingleton<ActiveBridgeLocality>(const FakeActiveBridgeLocality());
    computerSwitchDispatcher = _MockComputerSwitchDispatcher();
    when(
      () => computerSwitchDispatcher.switchTo(
        bridgeId: any(named: "bridgeId"),
        source: any(named: "source"),
      ),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<ComputerSwitchDispatcher>(computerSwitchDispatcher);
    projectList = _MockProjectListCubit();
    whenListen(
      projectList,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(projects: [_demo], folderProjects: [_demo], scratchProject: null),
    );
    connectionOverlay = _MockConnectionOverlayCubit();
    whenListen(
      connectionOverlay,
      const Stream<ConnectionOverlayState>.empty(),
      initialState: const ConnectionOverlayState.hidden(connected: true),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await appearanceCubit.close();
    await attentionPreferences.close();
    await updateStates.close();
    await automaticUpdates.close();
    await connectionStatuses.close();
    await chatInputModeCubit.close();
    await analyticsStates.close();
    await pluginSnapshots.close();
    await installStates.close();
    await authenticationChallenges.close();
    await authenticationBrowserStates.close();
    await authenticationTerminal.close();
  });

  Future<GoRouter> openWith({
    required WidgetTester tester,
    required Future<void> Function({required BuildContext context}) show,
  }) async {
    final router = GoRouter(
      initialLocation: "/session",
      routes: [
        ShellRoute(
          // Below the root navigator, as in the cockpit: the settings window
          // reaches the project list only through what it re-provides.
          builder: (_, state, child) => MultiBlocProvider(
            providers: [
              BlocProvider<AuthGateCubit>.value(value: authGateCubit),
              BlocProvider<ProjectListCubit>.value(value: projectList),
              RepositoryProvider<ConnectionService>.value(value: getIt<ConnectionService>()),
            ],
            child: Builder(
              builder: (context) {
                // Exercise registered shortcuts without mounting production DI or the cockpit.
                final shell = buildDesktopRoutes().single as ShellRoute;
                final gate = shell.builder!(context, state, child) as AuthGate;
                final provider = gate.child as DesktopCockpitCubitProvider;
                final cockpit = (provider.child as Builder).builder(context) as DesktopCockpitShell;
                return CallbackShortcuts(
                  bindings: {desktopShortcut(key: LogicalKeyboardKey.comma): cockpit.onOpenSettings},
                  child: cockpit.child,
                );
              },
            ),
          ),
          routes: [
            GoRoute(
              path: "/session",
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => unawaited(show(context: context)),
                  child: const Text("open"),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<BridgeControlCubit>.value(value: bridgeControl),
          BlocProvider<FileAccessCubit>.value(value: fileAccess),
          BlocProvider<AppearanceCubit>.value(value: appearanceCubit),
          BlocProvider<ChatInputModeCubit>.value(value: chatInputModeCubit),
          BlocProvider<ConnectionOverlayCubit>.value(value: connectionOverlay),
        ],
        // As in the desktop shell, so owned sheets open as dialogs.
        child: PregoInteractionScope(
          mode: PregoInteractionMode.pointer,
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildPregoThemeData(brightness: Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) => DesktopEscapeDismissal(child: child!),
          ),
        ),
      ),
    );
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
    return router;
  }

  Future<GoRouter> open({required WidgetTester tester, required DesktopSettingsTab tab}) => openWith(
    tester: tester,
    show: ({required context}) => showDesktopSettingsModal(
      context: context,
      initialTab: tab,
      onLogoutCompleted: () => logoutCompletions++,
    ),
  );

  /// As every Harness settings entry point opens it.
  Future<GoRouter> openHarnesses({required WidgetTester tester}) => openWith(
    tester: tester,
    show: ({required context}) => showDesktopHarnessSettings(
      context: context,
      onLogoutCompleted: () => logoutCompletions++,
    ),
  );

  bool selected({required WidgetTester tester, required DesktopSettingsTab tab}) {
    final row = find.byKey(ValueKey("desktop-settings-tab-${tab.name}"));
    return tester
            .widget<Semantics>(find.descendant(of: row, matching: find.byType(Semantics)).first)
            .properties
            .selected ??
        false;
  }

  Future<void> select({required WidgetTester tester, required DesktopSettingsTab tab}) async {
    await tester.tap(find.byKey(ValueKey("desktop-settings-tab-${tab.name}")));
    await tester.pumpAndSettle();
  }

  Widget app({required Widget child}) => MaterialApp(
    theme: buildPregoThemeData(brightness: Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  Widget updateSection() => app(
    child: MultiBlocProvider(
      providers: [
        BlocProvider<BridgeControlCubit>.value(value: bridgeControl),
        BlocProvider(create: (_) => DesktopUpdateCubit(service: desktopUpdateService)),
      ],
      child: const Scaffold(body: DesktopUpdateSection()),
    ),
  );

  testWidgets("a development build offers no updater controls", (tester) async {
    await tester.pumpWidget(updateSection());
    expect(find.text("Development build"), findsOneWidget);
    expect(find.text("Check for updates"), findsNothing);
    expect(find.byType(PregoSwitch), findsNothing);
  });

  testWidgets("a package install toggles and checks, then offers Restart to update once installed", (tester) async {
    updateStates.add(const DesktopUpdateManagedBySystem());
    when(desktopUpdateService.check)
        .thenAnswer((_) async => updateStates.add(const DesktopUpdateReady(version: "1.8.5")));
    when(bridgeControl.restartToUpdate).thenAnswer((_) async {});
    await tester.pumpWidget(updateSection());
    expect(find.text("Restart to update"), findsNothing);

    await tester.tap(find.byType(PregoSwitch));
    await tester.pump();
    verify(() => desktopUpdateService.setAutomaticUpdates(preference: DesktopAutomaticUpdates.disabled)).called(1);
    expect(tester.widget<PregoSwitch>(find.byType(PregoSwitch)).value, isFalse);

    final checkRow = tester.getTopLeft(find.text("Check for updates"));
    await tester.tap(find.text("Check for updates"));
    await tester.pumpAndSettle();
    verify(desktopUpdateService.check).called(1);
    // The new row opens below; the rows above it stay where they were.
    expect(tester.getTopLeft(find.text("Check for updates")), checkRow);
    expect(find.textContaining("Version 1.8.5 is ready"), findsOneWidget);

    await tester.tap(find.text("Restart to update"));
    await tester.pump();
    verify(bridgeControl.restartToUpdate).called(1);
  });

  testWidgets("a Velopack install describes downloading verified updates", (tester) async {
    updateStates.add(const DesktopUpdateIdle());
    when(() => desktopUpdateService.installKind).thenReturn(DesktopInstallKind.velopack);
    await tester.pumpWidget(updateSection());
    expect(find.byType(PregoSwitch), findsOneWidget);
    expect(find.textContaining("installs them when you quit"), findsOneWidget);
    expect(find.text("Restart to update"), findsNothing);
  });

  for (final status in FileAccessStatus.values) {
    testWidgets("Bridge shows local permission $status even after home dismissal", (tester) async {
      whenListen(
        fileAccess,
        const Stream<FileAccessState>.empty(),
        initialState: FileAccessState(status: status, dismissed: true),
      );
      await open(tester: tester, tab: DesktopSettingsTab.bridge);
      if (status == FileAccessStatus.unsupported) {
        expect(find.text("Full Disk Access"), findsNothing);
      } else {
        final title = find.text("Full Disk Access");
        await Scrollable.ensureVisible(tester.element(title), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(title);
        verify(fileAccess.openSystemSettings).called(1);
        expect(find.text("This computer"), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("General composes preferences instead of a mobile navigation menu", (tester) async {
    final router = await open(tester: tester, tab: DesktopSettingsTab.general);
    expect(router.state.uri.path, "/session");
    expect(find.byType(SettingsView), findsNothing);
    expect(find.byKey(const ValueKey("desktop-theme-system")), findsOneWidget);
    expect(find.byType(ChatInputModePicker), findsNothing);
    expect(find.text("Default input"), findsNothing);
    expect(find.text("Desktop updates"), findsOneWidget);
    expect(find.text("Development build"), findsOneWidget);
    expect(find.text("alex"), findsNothing);
    expect(find.text("Warm harness on session open"), findsNothing);
    expect(find.text("AI interactions"), findsNothing);
    verify(bridgeControl.refreshLaunchAtLogin).called(1);
    verifyNever(bridgeSettingsService.load);
    await tester.tap(find.text("Dark"));
    await tester.pumpAndSettle();
    expect(appearanceCubit.state, AppearanceMode.dark);
    await tester.ensureVisible(find.text("Launch Sesori at login"));
    await tester.tap(find.byType(PregoSwitch));
    verify(() => bridgeControl.setLaunchAtLogin(enabled: true)).called(1);
    await tester.ensureVisible(find.text("v0.1.0 (1)"));
    await tester.pump();
    expect(find.text("v0.1.0 (1)").hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("Projects lists the cockpit's projects and opens the folder browser over the window", (tester) async {
    when(() => projectList.fetchFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer(
      (_) async => const FilesystemSuggestionsSuccess(
        suggestions: FilesystemSuggestions(data: [], path: "/work"),
      ),
    );
    when(() => projectList.parentHostPath(path: any(named: "path"))).thenReturn(null);
    await open(tester: tester, tab: DesktopSettingsTab.projects);
    expect(find.text("demo-app"), findsOneWidget);
    expect(find.text("/work/demo-app"), findsOneWidget);

    await tester.tap(find.byKey(const Key("projects-settings-open-folder")));
    await tester.pumpAndSettle();
    expect(find.byType(AddProjectDialog), findsOneWidget);
    expect(find.byKey(const Key("desktop-settings-modal")), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("Bridge distinguishes connected configuration from local diagnostics", (tester) async {
    await open(tester: tester, tab: DesktopSettingsTab.bridge);
    expect(find.text("Desktop updates"), findsNothing);
    expect(find.text("Connected bridge"), findsOneWidget);
    expect(find.text("This computer"), findsOneWidget);
    expect(find.text("Local bridge"), findsOneWidget);
    expect(find.text("Off"), findsOneWidget);
    expect(find.text("Warm harness on session open"), findsOneWidget);
    expect(find.text("Launch Sesori at login"), findsNothing);
    expect(find.text("Quit Sesori"), findsNothing);
    await tester.ensureVisible(find.text("Open logs"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Open logs"));
    verify(bridgeControl.openLogs).called(1);
    verifyNever(bridgeControl.refreshLaunchAtLogin);
  });

  testWidgets("a bridge without /settings shows the bridge settings as unsupported", (tester) async {
    when(bridgeSettingsService.load).thenAnswer((_) async => const BridgeSettingsLoadUnsupported());
    await open(tester: tester, tab: DesktopSettingsTab.bridge);

    expect(find.text("Update the connected bridge to configure this setting."), findsNWidgets(2));
  });

  testWidgets("Bridge opens with the computer entry, and a switch closes the window", (tester) async {
    registeredBridges.emitBridges(
      bridges: [
        BridgeSummary(
          id: "a",
          name: "studio-mac",
          hostname: "studio-mac",
          platform: BridgePlatform.macos,
          status: BridgeRegistrationStatus.active,
          addedAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026, 7),
        ),
        BridgeSummary(
          id: "b",
          name: "build-box",
          hostname: "build-box",
          platform: BridgePlatform.linux,
          status: BridgeRegistrationStatus.inactive,
          addedAt: DateTime.utc(2026),
          lastSeenAt: null,
        ),
      ],
    );
    await open(tester: tester, tab: DesktopSettingsTab.bridge);
    final entry = find.byKey(const Key("computer_settings_entry"));
    expect(find.descendant(of: entry, matching: find.text("studio-mac")), findsOneWidget);
    expect(tester.getTopLeft(find.text("Connected bridge")).dy, lessThan(tester.getTopLeft(entry).dy));
    expect(tester.getBottomLeft(entry).dy, lessThan(tester.getTopLeft(find.text("YOLO mode")).dy));

    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.tap(find.text("build-box"));
    await tester.pumpAndSettle();
    verify(() => computerSwitchDispatcher.switchTo(bridgeId: "b", source: ComputerSwitchSource.settings)).called(1);
    expect(find.byKey(const Key("desktop-settings-modal")), findsNothing);
  });

  testWidgets("Harnesses is a Bridge row, not a tab, and opens inside the Bridge tab with Back to it", (tester) async {
    await open(tester: tester, tab: DesktopSettingsTab.general);
    expect(find.byKey(const ValueKey("desktop-settings-tab-harnesses")), findsNothing);
    expect(find.text("Harnesses"), findsNothing);

    await select(tester: tester, tab: DesktopSettingsTab.bridge);
    // The connected bridge's card leads with it, as on the phone.
    final row = find.text("Harnesses");
    expect(row, findsOneWidget);
    expect(tester.getBottomLeft(row).dy, lessThan(tester.getTopLeft(find.text("YOLO mode")).dy));

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(HarnessesSettingsView), findsOneWidget);
    expect(find.text("OpenCode"), findsOneWidget);
    expect(find.text("YOLO mode"), findsNothing);
    // The page names itself under its Back while the sidebar keeps Bridge.
    expect(find.text("Harnesses"), findsOneWidget);
    expect(selected(tester: tester, tab: DesktopSettingsTab.bridge), isTrue);

    // Back stays inside the window, on the Bridge tab.
    await tester.tap(find.text("Back"));
    await tester.pumpAndSettle();
    expect(find.byType(HarnessesSettingsView), findsNothing);
    expect(find.text("YOLO mode"), findsOneWidget);
    expect(find.byKey(const Key("desktop-settings-modal")), findsOneWidget);
  });

  testWidgets("the window holds no Archived row on any tab, which the main window's sidebar holds", (tester) async {
    await open(tester: tester, tab: DesktopSettingsTab.general);
    for (final tab in DesktopSettingsTab.values) {
      await select(tester: tester, tab: tab);
      expect(find.byKey(const Key("desktop-settings-archived")), findsNothing);
      expect(find.text("Archived sessions"), findsNothing, reason: "the ${tab.name} tab");
    }
  });

  testWidgets("Manage computers pushes Computers inside the Bridge tab, and a switch there closes the window", (
    tester,
  ) async {
    registeredBridges.emitBridges(
      bridges: [
        BridgeSummary(
          id: "a",
          name: "Studio",
          hostname: "studio-mac.local",
          platform: BridgePlatform.macos,
          status: BridgeRegistrationStatus.active,
          addedAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026, 7),
        ),
        BridgeSummary(
          id: "b",
          name: "build-box",
          hostname: "build-box",
          platform: BridgePlatform.linux,
          status: BridgeRegistrationStatus.inactive,
          addedAt: DateTime.utc(2026),
          lastSeenAt: null,
        ),
      ],
    );
    await open(tester: tester, tab: DesktopSettingsTab.bridge);

    Future<void> manageComputers() async {
      await tester.tap(find.byKey(const Key("computer_settings_entry")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey("computer-menu-manage")));
      await tester.pumpAndSettle();
    }

    await manageComputers();
    expect(find.text("Computers"), findsOneWidget);
    expect(find.text("studio-mac.local"), findsOneWidget);
    expect(find.text("YOLO mode"), findsNothing);

    // Back stays inside the window, on the Bridge tab.
    await tester.tap(find.text("Back"));
    await tester.pumpAndSettle();
    expect(find.text("YOLO mode"), findsOneWidget);
    expect(find.byKey(const Key("desktop-settings-modal")), findsOneWidget);

    // Picking the Bridge tab again leaves the Computers page too.
    await manageComputers();
    await tester.tap(find.byKey(const ValueKey("desktop-settings-tab-bridge")));
    await tester.pumpAndSettle();
    expect(find.text("YOLO mode"), findsOneWidget);
    expect(find.text("studio-mac.local"), findsNothing);

    await manageComputers();
    await tester.tap(find.byKey(const ValueKey("computers-actions-b")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("computers-switch-b")));
    await tester.pumpAndSettle();
    verify(
      () => computerSwitchDispatcher.switchTo(bridgeId: "b", source: ComputerSwitchSource.computersPage),
    ).called(1);
    expect(find.byKey(const Key("desktop-settings-modal")), findsNothing);
  });

  testWidgets("Remove on this computer offers to turn its bridge off only while it is on", (tester) async {
    await getIt.unregister<ActiveBridgeLocality>();
    getIt.registerSingleton<ActiveBridgeLocality>(const _LocalBridge(bridgeId: "a"));
    final bridgeStates = StreamController<BridgeControlState>();
    addTearDown(bridgeStates.close);
    whenListen(
      bridgeControl,
      bridgeStates.stream,
      initialState: const BridgeControlState(
        trayAvailability: SystemTrayAvailability.available,
        activity: BridgeControlActivity.idle,
        statusLabel: "Running",
        processState: BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
        toggleTarget: BridgeProcessDesiredState.off,
        launchAtLoginEnabled: false,
        controlStatus: BridgeControlStatus.offline,
        updateState: DesktopUpdateManagedBySystem(),
      ),
    );
    when(bridgeControl.stopBridge).thenAnswer((_) async => bridgeStates.add(_bridgeState));
    registeredBridges.emitBridges(
      bridges: [
        BridgeSummary(
          id: "a",
          name: "Studio",
          hostname: "studio-mac.local",
          platform: BridgePlatform.macos,
          status: BridgeRegistrationStatus.active,
          addedAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026, 7),
        ),
      ],
    );
    await open(tester: tester, tab: DesktopSettingsTab.bridge);
    await tester.tap(find.byKey(const Key("computer_settings_entry")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("computer-menu-manage")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("computers-actions-a")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("computers-remove-a")));
    await tester.pumpAndSettle();

    expect(find.text("This computer can't be removed"), findsOneWidget);
    await tester.tap(find.byKey(const Key("desktop-computers-turn-off-bridge")));
    await tester.pumpAndSettle();

    verify(bridgeControl.stopBridge).called(1);
    expect(find.byKey(const Key("desktop-computers-turn-off-bridge")), findsNothing);
    expect(find.text("This computer can't be removed"), findsOneWidget);
    verifyNever(() => registeredBridges.remove(bridgeId: any(named: "bridgeId")));
  });

  testWidgets("Notifications uses desktop attention and Account retains supervised logout", (tester) async {
    await open(tester: tester, tab: DesktopSettingsTab.notifications);
    expect(find.text("AI interactions"), findsOneWidget);
    expect(find.text("Session messages"), findsNothing);
    expect(find.text("Connection status"), findsNothing);
    await tester.tap(find.byType(PregoSwitch));
    await tester.pumpAndSettle();
    expect(attentionPreferences.value, DesktopAttentionPreference.disabled);
    when(authGateCubit.signOut).thenAnswer((_) async => DesktopLogoutOutcome.completed);
    await select(tester: tester, tab: DesktopSettingsTab.account);
    expect(find.text("alex"), findsOneWidget);
    expect(find.bySemanticsLabel("Back"), findsNothing);
    expect(find.text("Profile"), findsNothing);
    // The sign-in method is said once, beside its provider icon.
    expect(find.textContaining("Signed in with"), findsOneWidget);
    await tester.tap(find.text("Log out"));
    await tester.pumpAndSettle();
    // Logging out asks first, in a dialog rather than a sheet on desktop.
    verifyNever(authGateCubit.signOut);
    expect(find.byType(PregoBottomSheet), findsNothing);
    expect(
      find.ancestor(of: find.byKey(const Key("logout_confirm_action")), matching: find.byType(Dialog)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key("logout_confirm_action")));
    await tester.pumpAndSettle();
    verify(authGateCubit.signOut).called(1);
    expect(logoutCompletions, 1);
    expect(find.byKey(const Key("desktop-settings-modal")), findsNothing);
    expect(find.text("open"), findsOneWidget);
  });

  for (final failure in DesktopLogoutOutcome.values.where((outcome) => outcome != DesktopLogoutOutcome.completed)) {
    testWidgets("failed logout ${failure.name} keeps Account open", (tester) async {
      when(authGateCubit.signOut).thenAnswer((_) async => failure);
      final router = await open(tester: tester, tab: DesktopSettingsTab.account);
      await tester.tap(find.text("Log out"));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("logout_confirm_action")));
      await tester.pumpAndSettle();
      verify(authGateCubit.signOut).called(1);
      expect(logoutCompletions, 0);
      expect(find.byKey(const Key("desktop-settings-modal")), findsOneWidget);
      expect(router.state.uri.path, "/session");
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("external auth rejection dismisses Settings without requesting another logout", (tester) async {
    final auth = StreamController<AuthGateState>();
    addTearDown(auth.close);
    whenListen(authGateCubit, auth.stream, initialState: const AuthGateState.signedIn(user: _user));
    await open(tester: tester, tab: DesktopSettingsTab.general);
    auth.add(const AuthGateState.signedOut());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("desktop-settings-modal")), findsNothing);
    expect(logoutCompletions, 0);
    verifyNever(authGateCubit.signOut);
  });

  testWidgets("late logout completion cannot pop the opener after dismissal", (tester) async {
    final logout = Completer<DesktopLogoutOutcome>();
    when(authGateCubit.signOut).thenAnswer((_) => logout.future);
    final router = await open(tester: tester, tab: DesktopSettingsTab.account);
    await tester.tap(find.text("Log out"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("logout_confirm_action")));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    logout.complete(DesktopLogoutOutcome.completed);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, "/session");
    expect(logoutCompletions, 1);
    expect(find.text("open"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0, 2.5]) {
    testWidgets("minimum window at ${scale}x keeps tabs reachable and preserves the route", (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(560, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = await open(tester: tester, tab: DesktopSettingsTab.general);
      final opener = tester.element(find.text("open", skipOffstage: false));
      expect(SessionDetailRouteVisibility.isVisibleOf(context: opener), isFalse);
      final bounds = tester.getRect(find.byKey(const Key("desktop-settings-modal")));
      expect(bounds.left, greaterThanOrEqualTo(12));
      expect(bounds.right, lessThanOrEqualTo(548));
      expect(bounds.bottom, lessThanOrEqualTo(468));
      for (final tab in DesktopSettingsTab.values) {
        final target = find.byKey(ValueKey("desktop-settings-tab-${tab.name}"));
        await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
        expect(MediaQuery.textScalerOf(tester.element(target)).scale(10), 10 * scale);
        // Only the largest scale overflows the tab list, so only it scrolls.
        if (scale > 2) expect(Scrollable.of(tester.element(target)).position.maxScrollExtent, greaterThan(0));
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key("desktop-settings-close")).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: "${tab.name} at scale $scale");
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, "/session");
      expect(tester.element(find.text("open")), same(opener));
      expect(SessionDetailRouteVisibility.isVisibleOf(context: opener), isTrue);
      await tester.tap(find.text("open"));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("desktop-settings-modal")), findsNothing);
      expect(tester.element(find.text("open")), same(opener));
      final modifier = Theme.of(tester.element(find.text("open"))).platform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("desktop-theme-system")), findsOneWidget);
      expect(router.state.uri.path, "/session");
      expect(tester.element(find.text("open", skipOffstage: false)), same(opener));
      expect(tester.takeException(), isNull);
    }, variant: const TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.windows}));
  }

  testWidgets("Harness settings lands on Bridge with Harnesses open; detail shares its owner and Close returns", (
    tester,
  ) async {
    final router = await openHarnesses(tester: tester);
    final opener = tester.element(find.text("open", skipOffstage: false));
    final cubit = tester.element(find.byType(HarnessesSettingsView)).read<PluginManagementCubit>();
    expect(selected(tester: tester, tab: DesktopSettingsTab.bridge), isTrue);
    expect(find.text("YOLO mode"), findsNothing);
    // The overview's one Back leads to Bridge's own page.
    expect(find.bySemanticsLabel("Back"), findsOneWidget);
    // Pulling the overview still refreshes the harness list, as the old tab did.
    when(pluginService.refresh).thenAnswer((_) async {});
    await tester.drag(find.text("OpenCode"), const Offset(0, 300));
    await tester.pumpAndSettle();
    verify(pluginService.refresh).called(1);
    await tester.tap(find.text("OpenCode"));
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(HarnessSettingsDetailView)).read<PluginManagementCubit>(), same(cubit));
    expect(find.byType(HarnessSettingsFlowView), findsOneWidget);
    await tester.tap(find.bySemanticsLabel("Back"));
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(HarnessesSettingsView)).read<PluginManagementCubit>(), same(cubit));
    await tester.tap(find.text("OpenCode"));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel("Close settings"));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, "/session");
    expect(tester.element(find.text("open")), same(opener));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(cubit.isClosed, isTrue);
    expect(pluginSnapshots.hasListener, isFalse);
    expect(authenticationTerminal.hasListener, isFalse);
  });

  testWidgets("closing the harness modal also dismisses its authentication sheet without cancellation", (tester) async {
    final challenge = PluginAuthenticationDeviceCodeChallenge(
      verificationUri: Uri.parse("https://auth.example/device"),
      userCode: "ABCD-EFGH",
    );
    when(() => pluginService.startAuthentication(pluginId: "opencode")).thenAnswer((_) async {
      authenticationChallenges.add({"opencode": challenge});
      return PluginAuthenticationStartResult.challenge(challenge: challenge);
    });
    pluginSnapshots.add(
      PluginManagementLoadResult.supported(
        response: _pluginResponse.copyWith(
          plugins: [
            _plugin.copyWith(
              setup: _plugin.setup.copyWith(state: PluginSetupState.authenticationRequired),
              managementCapabilities: {PluginManagementCapability.authentication},
            ),
          ],
        ),
        refreshError: null,
      ),
    );
    await openHarnesses(tester: tester);
    await tester.tap(find.text("OpenCode"));
    await tester.pumpAndSettle();
    final detail = tester.widget<HarnessSettingsDetailView>(find.byType(HarnessSettingsDetailView));
    await tester.tap(find.byKey(const Key("harness_authentication_opencode")));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    detail.onClose();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text("open"), findsOneWidget);
    expect(pluginSnapshots.hasListener, isFalse);
    verifyNever(() => pluginService.cancelAuthentication(pluginId: "opencode"));
  });

  testWidgets("pasted-code sheet defers opening and reaches the waiting state once applied", (tester) async {
    final challenge = PluginAuthenticationPastedCodeChallenge(
      authorizationUri: Uri.parse("https://auth.example/authorize"),
    );
    when(() => pluginService.startAuthentication(pluginId: "opencode")).thenAnswer((_) async {
      authenticationChallenges.add({"opencode": challenge});
      return PluginAuthenticationStartResult.challenge(challenge: challenge);
    });
    when(
      () => pluginService.submitAuthenticationCode(pluginId: "opencode", code: "PASTE-CODE-123"),
    ).thenAnswer((_) async => const PluginAuthenticationContinuationResult.applied());
    pluginSnapshots.add(
      PluginManagementLoadResult.supported(
        response: _pluginResponse.copyWith(
          plugins: [
            _plugin.copyWith(
              setup: _plugin.setup.copyWith(state: PluginSetupState.authenticationRequired),
              managementCapabilities: {PluginManagementCapability.authentication},
            ),
          ],
        ),
        refreshError: null,
      ),
    );
    await openHarnesses(tester: tester);
    await tester.tap(find.text("OpenCode"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("harness_authentication_opencode")));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    verifyNever(
      () => getIt<UrlLauncher>().launch(Uri.parse("https://auth.example/authorize"), mode: UrlLaunchMode.externalApp),
    );

    final codeField = find.descendant(
      of: find.byKey(const Key("harness_authentication_code_input")),
      matching: find.byType(TextFormField),
    );
    final submitButton = find.byKey(const Key("harness_authentication_submit_code"));
    expect(tester.widget<PregoButtonsSolid>(submitButton).onPressed, isNull);

    await tester.enterText(codeField, "PASTE-CODE-123");
    await tester.pump();
    expect(tester.widget<PregoButtonsSolid>(submitButton).onPressed, isNotNull);

    await tester.tap(submitButton);
    await tester.pump();
    verify(() => pluginService.submitAuthenticationCode(pluginId: "opencode", code: "PASTE-CODE-123")).called(1);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key("harness_authentication_activity")), findsOneWidget);
    expect(find.byKey(const Key("harness_authentication_code_input")), findsNothing);
  });
}
