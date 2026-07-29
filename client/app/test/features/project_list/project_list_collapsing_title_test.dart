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
/// the page scroll off and left the bar's title pinned while the body moved
/// underneath it. They are bodies now, hosted in the scaffold's page scroll.
///
/// Both trade the loaded list's collapsing large title for the compact
/// back-leading block, whose subtitle reports the connection the body is about:
/// what the setup checklist is waiting for, or the machine the offline view is
/// trying to reach. So neither page has a large title to scroll away, and the
/// bar stays put while its body scrolls.
void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
  const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
  const bridgeOffline = ConnectionStatus.bridgeOffline(config: config, health: health);

  late BehaviorSubject<ConnectionStatus> statusController;
  late MockConnectionService mockConnectionService;
  late MockProjectRepository mockProjectRepository;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late StubConnectionOverlayCubit overlayCubit;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    statusController = BehaviorSubject<ConnectionStatus>.seeded(bridgeOffline);
    mockConnectionService = MockConnectionService();
    mockProjectRepository = MockProjectRepository();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    overlayCubit = StubConnectionOverlayCubit();

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockProjectRepository.listProjects()).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

    getIt.registerLazySingleton<ProjectRepository>(() => mockProjectRepository);
    registerListServices(
      projectRepository: mockProjectRepository,
    );
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

  Future<void> pumpScreen(
    WidgetTester tester, {
    required bool hasRegisteredBridges,
    List<BridgeSummary> bridges = const [],
  }) async {
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => hasRegisteredBridges);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => bridges);
    // A phone-width viewport, deliberately short so the body overflows it.
    // Overflow is the precondition for the behaviour under test: a body that
    // fits leaves the page with no scroll extent, and a bar with nothing to
    // scroll against correctly stays put.
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

  /// Drags the page up past [PregoTopNavigation.collapseDistance].
  Future<void> scrollPageUp(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets("the bridge-offline body scrolls under a back-leading bar naming the machine", (tester) async {
    await pumpScreen(
      tester,
      hasRegisteredBridges: true,
      bridges: [
        BridgeSummary(
          id: "a",
          name: "Macbook-Pro.local",
          platform: "macos",
          addedAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026, 7),
        ),
      ],
    );
    // A single scroll view for the whole page — the body no longer nests one.
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);

    // The bar carries the page title over the machine the body is trying to
    // reach, so there is no large title in the scroll view to collapse.
    expect(find.byType(PregoNavLeadingTitle), findsOneWidget);
    expect(largeTitle("Projects"), findsNothing);
    expect(find.text("Projects"), findsOneWidget);
    expect(find.byIcon(TablerRegular.device_laptop), findsNWidgets(2));
    expect(find.text("Macbook-Pro.local"), findsNWidgets(2));

    // The body scrolls under a bar that stays put.
    final barBefore = tester.getTopLeft(find.byType(PregoNavLeadingTitle));
    final bodyBefore = tester.getTopLeft(find.text("Make sure the Bridge is running")).dy;
    await scrollPageUp(tester);
    expect(tester.getTopLeft(find.text("Make sure the Bridge is running")).dy, lessThan(bodyBefore));
    expect(tester.getTopLeft(find.byType(PregoNavLeadingTitle)), barBefore);
  });

  testWidgets("the connect onboarding hosts a back-leading bar instead of a large title", (tester) async {
    await pumpScreen(tester, hasRegisteredBridges: false);
    // Still one page scroll owned by the scaffold, as on the offline body.
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);

    // The bar carries the page title over a status row reporting what the body
    // is waiting for — so there is no large title in the scroll view to
    // collapse, and the body's own caption is the only other copy of the text.
    expect(find.byType(PregoNavLeadingTitle), findsOneWidget);
    expect(largeTitle("Projects"), findsNothing);
    expect(find.text("Projects"), findsOneWidget);
    expect(find.byIcon(TablerRegular.broadcast_off), findsOneWidget);
    expect(find.text("Waiting for the bridge..."), findsNWidgets(2));

    // Scrolling moves the body without disturbing the fixed bar.
    final barBefore = tester.getTopLeft(find.byType(PregoNavLeadingTitle));
    await scrollPageUp(tester);
    expect(tester.getTopLeft(find.byType(PregoNavLeadingTitle)), barBefore);
  });

  testWidgets("pulling the disconnected page down re-attempts the bridge connection", (tester) async {
    await pumpScreen(tester, hasRegisteredBridges: false);
    verifyNever(() => mockConnectionService.reconnect());

    // The scaffold's sliver refresh control drives the reconnect that the
    // body's own pull-to-refresh used to.
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    verify(() => mockConnectionService.reconnect()).called(1);
  });
}
