import "dart:async";

import "package:bloc_test/bloc_test.dart";
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
import "package:sesori_desktop/features/settings/desktop_harnesses_settings_screen.dart";
import "package:sesori_desktop/features/settings/desktop_profile_screen.dart";
import "package:sesori_desktop/features/settings/desktop_settings_screen.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockAuthGateCubit() extends MockCubit<AuthGateState> implements AuthGateCubit;

class _StubConnectionOverlayCubit() extends Cubit<ConnectionOverlayState> implements ConnectionOverlayCubit {
  this : super(const ConnectionOverlayState.hidden(connected: true));

  @override
  void reconnect() {}
}

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
const ConnectionStatus _connected = ConnectionStatus.connected(
  config: _connectionConfig,
  health: _health,
);
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

void main() {
  setUpAll(() {
    registerFallbackValue(AppearanceMode.system);
    registerFallbackValue(ChatInputMode.voiceFirst);
    registerFallbackValue(DesktopAttentionPreference.enabled);
  });

  late _MockAuthGateCubit authGateCubit;
  late _StubConnectionOverlayCubit connectionOverlayCubit;
  late _MockAppearanceStore appearanceStore;
  late _MockChatInputModeStore chatInputModeStore;
  late AppearanceCubit appearanceCubit;
  late ChatInputModeCubit chatInputModeCubit;
  late BehaviorSubject<ConnectionStatus> connectionStatuses;
  late BehaviorSubject<DesktopAttentionPreference> attentionPreferences;
  late _MockDesktopAttentionService desktopAttentionService;
  late BehaviorSubject<ProductAnalyticsState> analyticsStates;
  late BehaviorSubject<PluginManagementLoadResult> pluginSnapshots;
  late BehaviorSubject<Map<String, PluginInstallState>> installStates;
  late BehaviorSubject<Map<String, PluginAuthenticationChallenge>> authenticationChallenges;
  late StreamController<PluginAuthenticationTerminalUpdate> authenticationTerminal;
  late BehaviorSubject<CatalogRescanState> catalogScanStates;

  setUp(() async {
    await getIt.reset();
    PackageInfo.setMockInitialValues(
      appName: "Sesori",
      packageName: "com.sesori.desktop",
      version: "0.1.0",
      buildNumber: "1",
      buildSignature: "",
    );

    authGateCubit = _MockAuthGateCubit();
    whenListen(
      authGateCubit,
      const Stream<AuthGateState>.empty(),
      initialState: const AuthGateState.signedIn(user: _user),
    );
    connectionOverlayCubit = _StubConnectionOverlayCubit();
    appearanceStore = _MockAppearanceStore();
    chatInputModeStore = _MockChatInputModeStore();
    when(() => appearanceStore.write(mode: any(named: "mode"))).thenAnswer((_) async {});
    when(() => chatInputModeStore.write(mode: any(named: "mode"))).thenAnswer((_) async {});
    appearanceCubit = AppearanceCubit(store: appearanceStore, initialMode: AppearanceMode.system);
    chatInputModeCubit = ChatInputModeCubit(
      store: chatInputModeStore,
      initialMode: ChatInputMode.voiceFirst,
    );

    connectionStatuses = BehaviorSubject<ConnectionStatus>.seeded(_connected);
    attentionPreferences = BehaviorSubject<DesktopAttentionPreference>.seeded(
      DesktopAttentionPreference.enabled,
    );
    desktopAttentionService = _MockDesktopAttentionService();
    when(() => desktopAttentionService.currentPreference).thenAnswer((_) => attentionPreferences.value);
    when(() => desktopAttentionService.preference).thenAnswer((_) => attentionPreferences.stream);
    when(
      () => desktopAttentionService.setPreference(preference: any(named: "preference")),
    ).thenAnswer((invocation) async {
      attentionPreferences.add(
        invocation.namedArguments[#preference]! as DesktopAttentionPreference,
      );
    });
    getIt.registerSingleton<DesktopAttentionService>(desktopAttentionService);
    analyticsStates = BehaviorSubject<ProductAnalyticsState>.seeded(
      const ProductAnalyticsState(
        preference: ProductAnalyticsPreferenceKnown(
          preference: ProductAnalyticsPreference.enabled,
        ),
        synchronization: ProductAnalyticsSynchronized(),
        availability: ProductAnalyticsInactive(
          reason: ProductAnalyticsInactiveReason.runtimeUnavailable,
        ),
      ),
    );
    pluginSnapshots = BehaviorSubject<PluginManagementLoadResult>();
    installStates = BehaviorSubject<Map<String, PluginInstallState>>.seeded(const {});
    authenticationChallenges = BehaviorSubject<Map<String, PluginAuthenticationChallenge>>.seeded(const {});
    authenticationTerminal = StreamController<PluginAuthenticationTerminalUpdate>.broadcast(sync: true);
    catalogScanStates = BehaviorSubject<CatalogRescanState>.seeded(const CatalogRescanState.idle());
  });

  tearDown(() async {
    await getIt.reset();
    await connectionOverlayCubit.close();
    await appearanceCubit.close();
    await attentionPreferences.close();
    await chatInputModeCubit.close();
    await connectionStatuses.close();
    await analyticsStates.close();
    await pluginSnapshots.close();
    await installStates.close();
    await authenticationChallenges.close();
    await authenticationTerminal.close();
    await catalogScanStates.close();
  });

  Widget app({required Widget child}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthGateCubit>.value(value: authGateCubit),
        BlocProvider<ConnectionOverlayCubit>.value(value: connectionOverlayCubit),
        BlocProvider<AppearanceCubit>.value(value: appearanceCubit),
        BlocProvider<ChatInputModeCubit>.value(value: chatInputModeCubit),
      ],
      child: MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  void useTallSurface({required WidgetTester tester}) {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets("desktop settings injects local attention without mobile notification routes", (tester) async {
    useTallSurface(tester: tester);
    final repository = _MockBridgeSettingsRepository();
    final connectionService = _MockConnectionService();
    when(() => connectionService.currentStatus).thenAnswer((_) => connectionStatuses.value);
    when(() => connectionService.status).thenAnswer((_) => connectionStatuses.stream);
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
    var profileOpens = 0;
    var harnessOpens = 0;

    await tester.pumpWidget(
      app(
        child: DesktopSettingsScreen(
          onClose: () {},
          onOpenProfile: () => profileOpens++,
          onOpenHarnesses: () => harnessOpens++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<PregoGlassScaffold>(find.byType(PregoGlassScaffold)).banner, isNull);
    expect(find.text("alex"), findsOneWidget);
    expect(find.text("Notifications"), findsOneWidget);
    expect(find.text("AI Interactions"), findsOneWidget);
    expect(find.text("Session Messages"), findsNothing);
    expect(find.text("Connection Status"), findsNothing);
    expect(find.text("Harnesses"), findsOneWidget);
    expect(find.text("Warm harness on session open"), findsOneWidget);
    expect(find.text("30 seconds"), findsOneWidget);
    expect(find.text("v0.1.0 (1)"), findsOneWidget);

    await tester.tap(find.text("alex"));
    await tester.tap(find.text("Harnesses"));
    await tester.tap(find.text("Dark"));
    await tester.pumpAndSettle();

    expect(profileOpens, 1);
    expect(harnessOpens, 1);
    expect(appearanceCubit.state, AppearanceMode.dark);
    verify(() => appearanceStore.write(mode: AppearanceMode.dark)).called(1);
  });

  testWidgets("desktop profile delegates logout through the auth gate", (tester) async {
    useTallSurface(tester: tester);
    final analyticsService = _MockProductAnalyticsService();
    when(() => analyticsService.state).thenAnswer((_) => analyticsStates.value);
    when(() => analyticsService.stateStream).thenAnswer((_) => analyticsStates.stream);
    getIt.registerSingleton<ProductAnalyticsService>(analyticsService);
    when(() => authGateCubit.signOut()).thenAnswer((_) async => DesktopLogoutOutcome.completed);
    var completed = 0;

    await tester.pumpWidget(
      app(
        child: DesktopProfileScreen(
          onClose: () {},
          onLogoutCompleted: () => completed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Log Out"));
    await tester.pumpAndSettle();

    verify(() => authGateCubit.signOut()).called(1);
    expect(completed, 1);
  });

  void registerHarnessServices() {
    final service = _MockPluginManagementService();
    final catalogRescanService = _MockCatalogRescanService();
    final urlLauncher = _MockUrlLauncher();
    when(() => service.snapshots).thenAnswer((_) => pluginSnapshots.stream);
    when(() => service.installStates).thenAnswer((_) => installStates.stream);
    when(() => service.authenticationChallenges).thenAnswer((_) => authenticationChallenges.stream);
    when(() => service.authenticationTerminal).thenAnswer((_) => authenticationTerminal.stream);
    when(service.onDispose).thenAnswer((_) async {});
    when(() => catalogRescanService.state).thenAnswer((_) => catalogScanStates.stream);
    when(catalogRescanService.onDispose).thenAnswer((_) async {});
    getIt.registerSingleton<PluginManagementService>(service);
    getIt.registerSingleton<CatalogRescanService>(catalogRescanService);
    getIt.registerSingleton<UrlLauncher>(urlLauncher);
  }

  for (final throughSettings in [false, true]) {
    testWidgets("desktop harness detail retains its flow and X preserves opener (settings: $throughSettings)", (
      tester,
    ) async {
      registerHarnessServices();
      final product = buildDesktopRoutes().single as ShellRoute;
      final harnessRoute = product.routes.whereType<ShellRoute>().singleWhere(
        (shell) => (shell.routes.first as GoRoute).path == AppRouteDef.settingsHarnesses.path,
      );
      final presentation = throughSettings ? HarnessSettingsPresentation.pushed : HarnessSettingsPresentation.modal;
      final router = GoRouter(
        initialLocation: "/opener",
        routes: [
          ShellRoute(
            builder: (_, _, child) => child,
            routes: [
              GoRoute(
                path: "/opener",
                builder: (context, _) => Scaffold(
                  body: TextButton(
                    onPressed: () => context.push<void>(
                      throughSettings
                          ? const AppRoute.settings().buildPath()
                          : AppRoute.settingsHarnesses(presentation: presentation).buildPath(),
                    ),
                    child: const Text("open"),
                  ),
                ),
              ),
              GoRoute(
                path: AppRouteDef.settings.path,
                builder: (context, _) => Scaffold(
                  body: TextButton(
                    onPressed: () =>
                        context.push<void>(AppRoute.settingsHarnesses(presentation: presentation).buildPath()),
                    child: const Text("harnesses"),
                  ),
                ),
              ),
              GoRoute(
                path: AppRouteDef.projects.path,
                builder: (_, _) => const Scaffold(body: Text("home")),
              ),
              harnessRoute,
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      pluginSnapshots.add(const PluginManagementLoadResult.supported(response: _pluginResponse, refreshError: null));
      await tester.pumpAndSettle();
      final opener = tester.element(find.text("open"));
      await tester.tap(find.text("open"));
      await tester.pumpAndSettle();
      if (throughSettings) {
        await tester.tap(find.text("harnesses"));
        await tester.pumpAndSettle();
      }
      final cubit = tester.element(find.byType(HarnessesSettingsView)).read<PluginManagementCubit>();
      await tester.tap(find.text("OpenCode"));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(HarnessSettingsDetailView)).read<PluginManagementCubit>(), same(cubit));
      expect(find.byType(HarnessSettingsFlowView), findsOneWidget);
      await tester.tap(find.bySemanticsLabel("Back"));
      await tester.pumpAndSettle();
      expect(find.byType(HarnessesSettingsView), findsOneWidget);
      await tester.tap(find.text("OpenCode"));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel("Close settings"));
      await tester.pumpAndSettle();
      expect(tester.element(find.text("open")), same(opener));
      expect(pluginSnapshots.hasListener, isFalse);
      expect(find.text("home"), findsNothing);
      router.go(
        const AppRoute.settingsHarnessDetail(
          pluginId: "opencode",
          presentation: HarnessSettingsPresentation.modal,
        ).buildPath(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HarnessesSettingsView, skipOffstage: false), findsOneWidget);
      await tester.tap(find.bySemanticsLabel("Close settings"));
      await tester.pumpAndSettle();
      expect(find.text("home"), findsOneWidget);
    });
  }

  testWidgets("desktop harness composition renders a supported bridge snapshot", (tester) async {
    useTallSurface(tester: tester);
    registerHarnessServices();

    await tester.pumpWidget(
      app(
        child: const DesktopHarnessesSettingsScreen(
          child: HarnessesSettingsView(
            presentation: HarnessSettingsPresentation.pushed,
            connectionBanner: null,
            onClose: _noOp,
            onBack: _noOp,
            onOpenHarness: _noOpenHarness,
          ),
        ),
      ),
    );
    pluginSnapshots.add(const PluginManagementLoadResult.supported(response: _pluginResponse, refreshError: null));
    await tester.pumpAndSettle();

    expect(find.text("Harnesses"), findsOneWidget);
    expect(find.text("OpenCode"), findsOneWidget);
    expect(find.text("Running"), findsNothing);
    expect(find.text("Idle"), findsNothing);
  });
}

void _noOp() {}

void _noOpenHarness({required String pluginId}) {}
