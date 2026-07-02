import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/project/project_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/capabilities/sse/sse_event_repository.dart";
import "package:sesori_dart_core/src/platform/route_source.dart";
import "package:sesori_dart_core/src/platform/url_launcher.dart";
import "package:sesori_dart_core/src/services/registered_bridges_service.dart";
import "package:sesori_mobile/core/analytics/analytics_event.dart";
import "package:sesori_mobile/core/analytics/analytics_reporter.dart";
import "package:sesori_mobile/core/support_links.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// End-to-end analytics guard for the onboarding "Need help?" support menu:
// tapping the pill logs the menu-open event, and tapping a support channel
// logs the channel event and launches its external link.
//
// Pumps the real [ProjectListScreen] driven into the connected-but-empty
// onboarding state (its cubit is built from getIt, so every dependency is
// registered as a mock below).
// ---------------------------------------------------------------------------

const _connectionConfig = ServerConnectionConfig(
  relayHost: "relay.example.com",
  authToken: "test-token",
);
const _connectedStatus = ConnectionStatus.connected(
  config: _connectionConfig,
  health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null),
);

Widget _buildApp() {
  final router = GoRouter(
    routes: [
      GoRoute(path: "/", builder: (context, state) => const ProjectListScreen()),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(
      colorScheme: PregoColors.light.toFlutterColorScheme(),
      textTheme: PregoTextTheme.light.asFlutterTextTheme(),
      fontFamily: PregoTextTheme.fontFamily,
      fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
      extensions: [PregoDesignSystem.light],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  final getIt = GetIt.instance;

  late MockProjectService mockProjectService;
  late MockConnectionService mockConnectionService;
  late MockSseEventRepository mockSseEventRepository;
  late MockRouteSource mockRouteSource;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late MockFailureReporter mockFailureReporter;
  late MockUrlLauncher mockUrlLauncher;
  late MockAnalyticsReporter mockAnalyticsReporter;
  late BehaviorSubject<ConnectionStatus> statusController;

  setUpAll(registerAllFallbackValues);

  void register<T extends Object>(T instance) {
    if (getIt.isRegistered<T>()) getIt.unregister<T>();
    getIt.registerSingleton<T>(instance);
  }

  setUp(() {
    mockProjectService = MockProjectService();
    mockConnectionService = MockConnectionService();
    mockSseEventRepository = MockSseEventRepository();
    mockRouteSource = MockRouteSource();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    mockFailureReporter = MockFailureReporter();
    mockUrlLauncher = MockUrlLauncher();
    mockAnalyticsReporter = MockAnalyticsReporter();
    statusController = BehaviorSubject<ConnectionStatus>.seeded(_connectedStatus);

    // Connected relay with zero projects → the connected-but-empty onboarding
    // state, whose floating action is the "Need help?" menu.
    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockProjectService.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(const Projects(data: [])),
    );
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => true);
    when(
      () => mockAnalyticsReporter.logEvent(event: any(named: "event")),
    ).thenAnswer((_) async {});

    register<ProjectService>(mockProjectService);
    register<ConnectionService>(mockConnectionService);
    register<SseEventRepository>(mockSseEventRepository);
    register<RouteSource>(mockRouteSource);
    register<RegisteredBridgesService>(mockRegisteredBridgesService);
    register<FailureReporter>(mockFailureReporter);
    register<UrlLauncher>(mockUrlLauncher);
    register<AnalyticsReporter>(mockAnalyticsReporter);
  });

  tearDown(() async {
    await getIt.reset();
    await statusController.close();
  });

  /// Pumps the screen into the onboarding state and returns once the
  /// "Need help?" pill is visible.
  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.text("Need help?"), findsOneWidget);
    // The screen's minute ticker would otherwise linger as a pending timer;
    // unmounting at the end of the test disposes it.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets("tapping the Need help pill logs the menu-open event", (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text("Need help?"));
    await tester.pumpAndSettle();

    verify(
      () => mockAnalyticsReporter.logEvent(event: const AnalyticsEvent.needHelpMenuOpened()),
    ).called(1);
    // The popup actually opened alongside the event.
    expect(find.text("Email"), findsOneWidget);
  });

  testWidgets("tapping a support channel logs the channel event and launches the link", (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text("Need help?"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Email"));
    await tester.pumpAndSettle();

    verify(
      () => mockAnalyticsReporter.logEvent(
        event: const AnalyticsEvent.supportLinkOpened(channel: SupportChannel.email),
      ),
    ).called(1);
    final launched = verify(() => mockUrlLauncher.launch(captureAny())).captured.single as Uri;
    expect(launched.toString(), SupportLinks.email);
  });

  testWidgets("each support channel reports its own analytics channel value", (tester) async {
    await pumpOnboarding(tester);

    const channelByLabel = {
      "Discord": SupportChannel.discord,
      "DM on X": SupportChannel.x,
    };
    for (final entry in channelByLabel.entries) {
      await tester.tap(find.text("Need help?"));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();

      verify(
        () => mockAnalyticsReporter.logEvent(
          event: AnalyticsEvent.supportLinkOpened(channel: entry.value),
        ),
      ).called(1);
    }
  });
}
