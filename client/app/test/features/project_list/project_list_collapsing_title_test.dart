import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// The two disconnected Projects states — the connect-your-computer onboarding
/// and the bridge-offline view — used to own an inner scroll view, which forced
/// the page scroll off and left the large title pinned while the body moved
/// underneath it. They are bodies now, hosted in the scaffold's page scroll, so
/// the title scrolls away with the content and collapses into the top nav bar
/// exactly as it does on the loaded project list.
void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
  const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
  const bridgeOffline = ConnectionStatus.bridgeOffline(config: config, health: health);

  late BehaviorSubject<ConnectionStatus> statusController;
  late MockConnectionService mockConnectionService;
  late MockProjectService mockProjectService;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late StubConnectionOverlayCubit overlayCubit;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    statusController = BehaviorSubject<ConnectionStatus>.seeded(bridgeOffline);
    mockConnectionService = MockConnectionService();
    mockProjectService = MockProjectService();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    overlayCubit = StubConnectionOverlayCubit();

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

    getIt.registerLazySingleton<ProjectService>(() => mockProjectService);
    registerListServices(projectService: mockProjectService);
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    getIt.registerLazySingleton<SseEventTracker>(MockSseEventTracker.new);
    getIt.registerLazySingleton<RouteSource>(MockRouteSource.new);
    getIt.registerLazySingleton<SessionUnseenTracker>(FakeSessionUnseenTracker.new);
    getIt.registerLazySingleton<RegisteredBridgesService>(() => mockRegisteredBridgesService);
    getIt.registerLazySingleton<FailureReporter>(MockFailureReporter.new);
  });

  tearDown(() async {
    await overlayCubit.close();
    await statusController.close();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester, {required bool hasRegisteredBridges}) async {
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => hasRegisteredBridges);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
    // A phone-width viewport, deliberately short so both bodies overflow it.
    // Overflow is the precondition for the behaviour under test: a body that
    // fits leaves the page with no scroll extent, and a large title with
    // nothing to scroll against correctly stays put.
    tester.view.physicalSize = const Size(393, 500);
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
  }

  /// The large title rendered in the page's scroll view, as opposed to the
  /// same-text title that lives in the top navigation bar. `skipOffstage: false`
  /// keeps it findable once it has scrolled up out of the viewport — which is
  /// precisely the state these tests assert.
  Finder largeTitle(String title) => find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.text(title, skipOffstage: false),
    skipOffstage: false,
  );

  /// The alpha the large title is painted with: 1 while fully shown, 0 once it
  /// has collapsed into the bar.
  double largeTitleAlpha(WidgetTester tester, String title) => tester.widget<Text>(largeTitle(title)).style!.color!.a;

  /// Drags the page up past [PregoTopNavigation.collapseDistance].
  Future<void> scrollPageUp(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets("the bridge-offline body scrolls the page, collapsing the large title", (tester) async {
    await pumpScreen(tester, hasRegisteredBridges: true);
    expect(find.text("Disconnected"), findsOneWidget);
    // A single scroll view for the whole page — the body no longer nests one.
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);

    // Expanding the install commands (the disclosure at the end of the body)
    // grows the body past the viewport, which is when the title must travel
    // with the content. The button may itself sit below the short viewport, so
    // scroll it into view first, then return to the top for a clean baseline.
    await tester.scrollUntilVisible(find.text("Install commands", skipOffstage: false), 100);
    await tester.tap(find.text("Install commands"));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600), warnIfMissed: false);
    await tester.pumpAndSettle();

    final titleBefore = tester.getTopLeft(largeTitle("Projects")).dy;
    expect(largeTitleAlpha(tester, "Projects"), closeTo(1, 0.001));

    await scrollPageUp(tester);

    expect(tester.getTopLeft(largeTitle("Projects")).dy, lessThan(titleBefore));
    expect(largeTitleAlpha(tester, "Projects"), closeTo(0, 0.001));
  });

  testWidgets("the connect onboarding scrolls the page, collapsing the large title", (tester) async {
    await pumpScreen(tester, hasRegisteredBridges: false);
    expect(find.text("Waiting for the bridge..."), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);

    final titleBefore = tester.getTopLeft(largeTitle("Connect")).dy;
    expect(largeTitleAlpha(tester, "Connect"), closeTo(1, 0.001));

    await scrollPageUp(tester);

    expect(tester.getTopLeft(largeTitle("Connect")).dy, lessThan(titleBefore));
    expect(largeTitleAlpha(tester, "Connect"), closeTo(0, 0.001));
  });

  testWidgets("pulling the disconnected page down re-attempts the bridge connection", (tester) async {
    await pumpScreen(tester, hasRegisteredBridges: false);
    verifyNever(() => mockConnectionService.reconnect());

    // The scaffold's RefreshIndicator now drives the reconnect that the body's
    // own pull-to-refresh used to.
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    verify(() => mockConnectionService.reconnect()).called(1);
  });
}
