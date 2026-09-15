import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop/core/widgets/desktop_escape_dismissal.dart";
import "package:sesori_desktop/features/auth_gate/auth_gate.dart";
import "package:sesori_desktop/features/settings/desktop_settings_modal.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockAuthGateCubit() extends MockCubit<AuthGateState> implements AuthGateCubit;
class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
class _MockAppearanceStore() extends Mock implements AppearanceStore;
class _MockChatInputModeStore() extends Mock implements ChatInputModeStore;
class _MockBridgeSettingsRepository() extends Mock implements BridgeSettingsRepository;
class _MockConnectionService() extends Mock implements ConnectionService;
class _MockProductAnalyticsService() extends Mock implements ProductAnalyticsService;
class _MockPluginManagementService() extends Mock implements PluginManagementService;
class _MockCatalogRescanService() extends Mock implements CatalogRescanService;
class _MockDesktopAttentionService() extends Mock implements DesktopAttentionService;
class _MockUrlLauncher() extends Mock implements UrlLauncher;

const AuthUser _user = AuthUser(
  id: "user-1",
  provider: AuthProvider.github,
  providerUserId: "gh-1",
  providerUsername: "alex",
);
const ServerConnectionConfig _connectionConfig = ServerConnectionConfig(
  relayHost: "relay.example.com",
  authToken: null,
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
);

void main() {
  setUpAll(() {
    registerFallbackValue(AppearanceMode.system);
    registerFallbackValue(ChatInputMode.voiceFirst);
    registerFallbackValue(DesktopAttentionPreference.enabled);
  });

  late _MockAuthGateCubit authGateCubit;
  late _MockBridgeControlCubit bridgeControl;
  late _MockAppearanceStore appearanceStore;
  late AppearanceCubit appearanceCubit;
  late ChatInputModeCubit chatInputModeCubit;
  late _MockBridgeSettingsRepository repository;
  late _MockDesktopAttentionService desktopAttentionService;
  late _MockPluginManagementService pluginService;
  late BehaviorSubject<ConnectionStatus> connectionStatuses;
  late BehaviorSubject<DesktopAttentionPreference> attentionPreferences;
  late BehaviorSubject<ProductAnalyticsState> analyticsStates;
  late BehaviorSubject<PluginManagementLoadResult> pluginSnapshots;
  late BehaviorSubject<Map<String, PluginInstallState>> installStates;
  late BehaviorSubject<Map<String, PluginAuthenticationChallenge>> authenticationChallenges;
  late BehaviorSubject<Map<String, PluginAuthenticationBrowserState>> authenticationBrowserStates;
  late StreamController<PluginAuthenticationTerminalUpdate> authenticationTerminal;
  late BehaviorSubject<CatalogRescanState> catalogScanStates;
  late int logoutCompletions;

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
    repository = _MockBridgeSettingsRepository();
    when(repository.load).thenAnswer(
      (_) async => const BridgeSettingsLoadSupported(
        response: BridgeSettingsResponse(
          pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
          yolo: YoloSettingsResponse(enabled: false),
          warmUpPluginsOnSessionOpen: true,
        ),
      ),
    );
    getIt.registerSingleton<BridgeSettingsRepository>(repository);
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
    catalogScanStates = BehaviorSubject<CatalogRescanState>.seeded(const CatalogRescanState.idle());
    pluginService = _MockPluginManagementService();
    final catalogRescanService = _MockCatalogRescanService();
    when(() => pluginService.snapshots).thenAnswer((_) => pluginSnapshots.stream);
    when(() => pluginService.installStates).thenAnswer((_) => installStates.stream);
    when(() => pluginService.authenticationChallenges).thenAnswer((_) => authenticationChallenges.stream);
    when(() => pluginService.authenticationBrowserStates).thenAnswer((_) => authenticationBrowserStates.stream);
    when(() => pluginService.authenticationTerminal).thenAnswer((_) => authenticationTerminal.stream);
    when(pluginService.onDispose).thenAnswer((_) async {});
    when(() => catalogRescanService.state).thenAnswer((_) => catalogScanStates.stream);
    when(catalogRescanService.onDispose).thenAnswer((_) async {});
    getIt.registerSingleton<PluginManagementService>(pluginService);
    getIt.registerSingleton<CatalogRescanService>(catalogRescanService);
    getIt.registerSingleton<UrlLauncher>(_MockUrlLauncher());
  });

  tearDown(() async {
    await getIt.reset();
    await appearanceCubit.close();
    await attentionPreferences.close();
    await connectionStatuses.close();
    await chatInputModeCubit.close();
    await analyticsStates.close();
    await pluginSnapshots.close();
    await installStates.close();
    await authenticationChallenges.close();
    await authenticationBrowserStates.close();
    await authenticationTerminal.close();
    await catalogScanStates.close();
  });

  Future<GoRouter> open({required WidgetTester tester, required DesktopSettingsTab tab}) async {
    final router = GoRouter(
      initialLocation: "/session",
      routes: [
        ShellRoute(
          builder: (_, state, child) => BlocProvider<AuthGateCubit>.value(
            value: authGateCubit,
            child: Builder(
              builder: (context) {
                // Exercise registered shortcuts without mounting production DI or the cockpit.
                final shell = buildDesktopRoutes().single as ShellRoute;
                final gate = shell.builder!(context, state, child) as AuthGate;
                final shortcuts = (gate.child as Builder).builder(context) as CallbackShortcuts;
                return CallbackShortcuts(bindings: shortcuts.bindings, child: child);
              },
            ),
          ),
          routes: [
            GoRoute(
              path: "/session",
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => unawaited(
                    showDesktopSettingsModal(
                      context: context,
                      initialTab: tab,
                      onLogoutCompleted: () => logoutCompletions++,
                    ),
                  ),
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
          BlocProvider<AppearanceCubit>.value(value: appearanceCubit),
          BlocProvider<ChatInputModeCubit>.value(value: chatInputModeCubit),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => DesktopEscapeDismissal(child: child!),
        ),
      ),
    );
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> select({required WidgetTester tester, required DesktopSettingsTab tab}) async {
    await tester.tap(find.byKey(ValueKey("desktop-settings-tab-${tab.name}")));
    await tester.pumpAndSettle();
  }

  testWidgets("General composes preferences instead of a mobile navigation menu", (tester) async {
    final router = await open(tester: tester, tab: DesktopSettingsTab.general);
    expect(router.state.uri.path, "/session");
    expect(find.byType(SettingsView), findsNothing);
    expect(find.byType(AppearancePicker), findsOneWidget);
    expect(find.byType(ChatInputModePicker), findsOneWidget);
    expect(find.text("alex"), findsNothing);
    expect(find.text("Warm harness on session open"), findsNothing);
    expect(find.text("AI Interactions"), findsNothing);
    verify(bridgeControl.refreshLaunchAtLogin).called(1);
    verifyNever(repository.load);
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

  testWidgets("Bridge distinguishes connected configuration from local diagnostics", (tester) async {
    await open(tester: tester, tab: DesktopSettingsTab.bridge);
    expect(find.text("Connected bridge"), findsOneWidget);
    expect(find.text("This computer"), findsOneWidget);
    expect(find.text("Local bridge"), findsOneWidget);
    expect(find.text("Off"), findsOneWidget);
    expect(find.text("Warm harness on session open"), findsOneWidget);
    expect(find.text("Launch Sesori at login"), findsNothing);
    expect(find.text("Quit Sesori"), findsNothing);
    await tester.ensureVisible(find.text("Open Logs"));
    await tester.tap(find.text("Open Logs"));
    verify(bridgeControl.openLogs).called(1);
    verifyNever(bridgeControl.refreshLaunchAtLogin);
    final interval = find.byKey(const Key("pull_request_refresh_interval"));
    await tester.ensureVisible(interval);
    await tester.tap(interval);
    await tester.pumpAndSettle();
    final input = find.byType(EditableText);
    await tester.showKeyboard(input);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(tester.widget<EditableText>(input).focusNode.hasFocus, isFalse);
    expect(find.byType(PregoBottomSheet), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PregoBottomSheet), findsNothing);
    expect(find.byKey(const Key("desktop-settings-modal")), findsOneWidget);
  });

  testWidgets("Notifications uses desktop attention and Account retains supervised logout", (tester) async {
    await open(tester: tester, tab: DesktopSettingsTab.notifications);
    expect(find.text("AI Interactions"), findsOneWidget);
    expect(find.text("Session Messages"), findsNothing);
    expect(find.text("Connection Status"), findsNothing);
    await tester.tap(find.byType(PregoSwitch));
    await tester.pumpAndSettle();
    expect(attentionPreferences.value, DesktopAttentionPreference.disabled);
    when(authGateCubit.signOut).thenAnswer((_) async => DesktopLogoutOutcome.completed);
    await select(tester: tester, tab: DesktopSettingsTab.account);
    expect(find.text("alex"), findsOneWidget);
    await tester.tap(find.text("Log Out"));
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
      await tester.tap(find.text("Log Out"));
      await tester.pumpAndSettle();
      expect(logoutCompletions, 0);
      expect(find.byKey(const Key("desktop-settings-modal")), findsOneWidget);
      expect(router.state.uri.path, "/session");
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("late logout completion cannot pop the opener after dismissal", (tester) async {
    final logout = Completer<DesktopLogoutOutcome>();
    when(authGateCubit.signOut).thenAnswer((_) => logout.future);
    final router = await open(tester: tester, tab: DesktopSettingsTab.account);
    await tester.tap(find.text("Log Out"));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    logout.complete(DesktopLogoutOutcome.completed);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, "/session");
    expect(logoutCompletions, 1);
    expect(find.text("open"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("minimum window keeps tabs reachable; Escape and outside preserve the route", (tester) async {
    tester.view.physicalSize = const Size(560, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = await open(tester: tester, tab: DesktopSettingsTab.general);
    final opener = tester.element(find.text("open", skipOffstage: false));
    final bounds = tester.getRect(find.byKey(const Key("desktop-settings-modal")));
    expect(bounds.left, greaterThanOrEqualTo(12));
    expect(bounds.right, lessThanOrEqualTo(548));
    expect(bounds.bottom, lessThanOrEqualTo(468));
    for (final tab in DesktopSettingsTab.values) {
      expect(find.byKey(ValueKey("desktop-settings-tab-${tab.name}")).hitTestable(), findsOneWidget);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, "/session");
    expect(tester.element(find.text("open")), same(opener));
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
    expect(find.byType(AppearancePicker), findsOneWidget);
    expect(router.state.uri.path, "/session");
    expect(tester.element(find.text("open", skipOffstage: false)), same(opener));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.windows}));

  testWidgets("harness detail shares its owner; Back stays inside and Close returns to the session", (tester) async {
    final router = await open(tester: tester, tab: DesktopSettingsTab.harnesses);
    final opener = tester.element(find.text("open", skipOffstage: false));
    final cubit = tester.element(find.byType(HarnessesSettingsView)).read<PluginManagementCubit>();
    expect(find.bySemanticsLabel("Back"), findsNothing);
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
    await open(tester: tester, tab: DesktopSettingsTab.harnesses);
    await tester.tap(find.text("OpenCode"));
    await tester.pumpAndSettle();
    final detail = tester.widget<HarnessSettingsDetailView>(find.byType(HarnessSettingsDetailView));
    await tester.tap(find.byKey(const Key("harness_authentication_opencode")));
    await tester.pumpAndSettle();
    expect(find.byType(PregoBottomSheet), findsOneWidget);
    detail.onClose();
    await tester.pumpAndSettle();
    expect(find.byType(PregoBottomSheet), findsNothing);
    expect(find.text("open"), findsOneWidget);
    expect(pluginSnapshots.hasListener, isFalse);
    verifyNever(() => pluginService.cancelAuthentication(pluginId: "opencode"));
  });
}
