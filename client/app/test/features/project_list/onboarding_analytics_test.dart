import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/analytics/analytics_event.dart";
import "package:sesori_mobile/core/analytics/analytics_reporter.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/core/support_links.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// End-to-end analytics guard for the Projects onboarding/recovery surfaces:
// every AnalyticsEvent union case is fired through a real widget tap, and the
// surface parameter tracks which body hosted it — the connect-your-computer
// setup or the bridge-offline view. (The connected-but-empty state carries no
// onboarding widgets anymore, so it fires no onboarding events.)
//
// Pumps the real [ProjectListScreen] (its cubit is built from getIt, so every
// dependency is registered as a mock below) driven into each state through
// the connection status stream + project list responses.
// ---------------------------------------------------------------------------

const _connectionConfig = ServerConnectionConfig(
  relayHost: "relay.example.com",
  authToken: "test-token",
);
const _health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
const _connectedStatus = ConnectionStatus.connected(config: _connectionConfig, health: _health);
const _bridgeOfflineStatus = ConnectionStatus.bridgeOffline(
  config: _connectionConfig,
  health: _health,
);

void main() {
  late MockProjectRepository mockProjectRepository;
  late MockConnectionService mockConnectionService;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late MockUrlLauncher mockUrlLauncher;
  late MockAnalyticsReporter mockAnalyticsReporter;
  late StubConnectionOverlayCubit overlayCubit;
  late BehaviorSubject<ConnectionStatus> statusController;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockProjectRepository = MockProjectRepository();
    mockConnectionService = MockConnectionService();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    mockUrlLauncher = MockUrlLauncher();
    mockAnalyticsReporter = MockAnalyticsReporter();
    overlayCubit = StubConnectionOverlayCubit();
    statusController = BehaviorSubject<ConnectionStatus>.seeded(_connectedStatus);

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
    when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => true);
    when(
      () => mockAnalyticsReporter.logEvent(event: any(named: "event")),
    ).thenAnswer((_) async {});

    getIt.registerLazySingleton<ProjectRepository>(() => mockProjectRepository);
    registerListServices(
      projectRepository: mockProjectRepository,
    );
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    getIt.registerLazySingleton<SseEventTracker>(MockSseEventTracker.new);
    getIt.registerLazySingleton<RouteSource>(MockRouteSource.new);
    getIt.registerLazySingleton<SessionAttentionTracker>(FakeSessionAttentionTracker.new);
    getIt.registerLazySingleton<RegisteredBridgesService>(() => mockRegisteredBridgesService);
    getIt.registerLazySingleton<FailureReporter>(MockFailureReporter.new);
    getIt.registerLazySingleton<UrlLauncher>(() => mockUrlLauncher);
    getIt.registerLazySingleton<AnalyticsReporter>(() => mockAnalyticsReporter);
  });

  tearDown(() async {
    await overlayCubit.close();
    await statusController.close();
    await getIt.reset();
  });

  /// Pumps the screen and settles. The tall viewport keeps every command box
  /// on-stage so taps land without scrolling; unmounting at the end of the
  /// test disposes the screen's minute ticker, which would otherwise linger
  /// as a pending timer.
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>.value(
        value: overlayCubit,
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProjectListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  /// Bridge offline with no bridge ever registered → the connect-your-computer
  /// setup onboarding.
  Future<void> pumpConnectSetup(WidgetTester tester) async {
    statusController.add(_bridgeOfflineStatus);
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => false);
    await pumpScreen(tester);
    expect(find.text("Waiting for the bridge..."), findsOneWidget);
  }

  /// Bridge offline with a bridge registered → the bridge-offline recovery
  /// view.
  Future<void> pumpBridgeOffline(WidgetTester tester) async {
    statusController.add(_bridgeOfflineStatus);
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    await pumpScreen(tester);
    expect(find.text("Disconnected"), findsOneWidget);
  }

  void verifyLogged(AnalyticsEvent event) {
    verify(() => mockAnalyticsReporter.logEvent(event: event)).called(1);
  }

  group("connect-your-computer setup onboarding", () {
    testWidgets("tapping the Need help pill logs the menu-open event", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Need help?"));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.needHelpMenuOpened(surface: OnboardingSurface.connectSetup),
      );
      // The popup actually opened alongside the event.
      expect(find.text("Email"), findsOneWidget);
    });

    testWidgets("tapping a support channel logs the channel event and launches the link", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Need help?"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Email"));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.supportLinkOpened(
          channel: SupportChannel.email,
          surface: OnboardingSurface.connectSetup,
        ),
      );
      final launched = verify(() => mockUrlLauncher.launch(captureAny())).captured.single as Uri;
      expect(launched.toString(), SupportLinks.email);
    });

    testWidgets("each support channel reports its own analytics channel value", (tester) async {
      await pumpConnectSetup(tester);

      const channelByLabel = {
        "Discord": SupportChannel.discord,
        "DM on X": SupportChannel.x,
      };
      for (final entry in channelByLabel.entries) {
        await tester.tap(find.text("Need help?"));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();

        verifyLogged(
          AnalyticsEvent.supportLinkOpened(
            channel: entry.value,
            surface: OnboardingSurface.connectSetup,
          ),
        );
      }
    });

    testWidgets("opening the why-bridge explainer logs its event", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Why is this needed?"));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.whyBridgeOpened(surface: OnboardingSurface.connectSetup),
      );
      // The sheet actually opened alongside the event (button + sheet title).
      expect(find.text("Why is this needed?"), findsNWidgets(2));
    });

    // Two command rows on this surface: the install box (step 1) first, the
    // run box (step 2) below it — hence copy/share at index 0 vs 1.
    testWidgets("copying the default install command logs curl on unix", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.bySemanticsLabel("Copy command").at(0));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.curl,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.connectSetup,
        ),
      );
    });

    testWidgets("copying after switching to the Windows group logs powershell", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.text("Windows PowerShell"));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel("Copy command").at(0));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.powershell,
          os: BridgeInstallOs.windows,
          surface: OnboardingSurface.connectSetup,
        ),
      );
    });

    testWidgets("copying a method tab logs that method under the selected group", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.text("npm"));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel("Copy command").at(0));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.npm,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.connectSetup,
        ),
      );
    });

    testWidgets("sharing the install command logs the shared event", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.bySemanticsLabel("Share command").at(0));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.installCommandShared(
          method: BridgeInstallMethod.curl,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.connectSetup,
        ),
      );
    });

    testWidgets("copying the step-2 run command logs the run event", (tester) async {
      await pumpConnectSetup(tester);

      await tester.tap(find.bySemanticsLabel("Copy command").at(1));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.runCommandCopied(surface: OnboardingSurface.connectSetup),
      );
    });
  });

  group("bridge-offline recovery view", () {
    testWidgets("copying the run command logs the bridge-offline surface", (tester) async {
      await pumpBridgeOffline(tester);

      // The install disclosure starts collapsed, so the always-visible run box
      // owns the only on-stage copy button.
      await tester.tap(find.bySemanticsLabel("Copy command"));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.runCommandCopied(surface: OnboardingSurface.bridgeOffline),
      );
    });

    testWidgets("sharing the run command logs the bridge-offline surface", (tester) async {
      await pumpBridgeOffline(tester);

      await tester.tap(find.bySemanticsLabel("Share command"));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.runCommandShared(surface: OnboardingSurface.bridgeOffline),
      );
    });

    testWidgets("copying from the expanded install disclosure logs the bridge-offline surface", (tester) async {
      await pumpBridgeOffline(tester);

      await tester.tap(find.text("Install commands"));
      await tester.pumpAndSettle();

      // Expanded, the install box unfolds below the disclosure at the end of
      // the body, so it sits after the always-visible run box.
      await tester.tap(find.bySemanticsLabel("Copy command").at(1));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.curl,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.bridgeOffline,
        ),
      );
    });

    testWidgets("tapping the Need help pill logs the bridge-offline surface", (tester) async {
      await pumpBridgeOffline(tester);

      await tester.tap(find.text("Need help?"));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.needHelpMenuOpened(surface: OnboardingSurface.bridgeOffline),
      );
      // The popup actually opened alongside the event.
      expect(find.text("Email"), findsOneWidget);
    });

    testWidgets("opening the why-bridge explainer logs the bridge-offline surface", (tester) async {
      await pumpBridgeOffline(tester);

      await tester.tap(find.text("Why is this needed?"));
      await tester.pumpAndSettle();

      verifyLogged(
        const AnalyticsEvent.whyBridgeOpened(surface: OnboardingSurface.bridgeOffline),
      );
      // The sheet actually opened alongside the event (button + sheet title).
      expect(find.text("Why is this needed?"), findsNWidgets(2));
    });
  });
}
