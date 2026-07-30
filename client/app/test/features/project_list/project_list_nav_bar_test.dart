import "dart:async";

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

/// The Projects top navigation, which is the same compact back-leading block on
/// every state: the page title over a subtitle row naming the machine this
/// account is paired with. No state hosts a collapsing large title, so the bar
/// never changes size or place as the page moves between them — and the bodies,
/// which join the scaffold's page scroll rather than nesting one of their own,
/// scroll underneath a bar that stays put.
///
/// The two disconnected surfaces are the exception in what that subtitle says:
/// the connect-your-computer onboarding has no machine to name yet, so its row
/// reports what the setup checklist is waiting for.
void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
  const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
  const bridgeOffline = ConnectionStatus.bridgeOffline(config: config, health: health);
  const connected = ConnectionStatus.connected(config: config, health: health);

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

  Widget buildApp() => BlocProvider<ConnectionOverlayCubit>.value(
    value: overlayCubit,
    child: MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProjectListScreen(),
    ),
  );

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

    await tester.pumpWidget(buildApp());
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

  // -------------------------------------------------------------------------
  // The connected surfaces: the loading page and the loaded list wear the same
  // bar as the disconnected ones, with the machine name as its second line.
  //
  // The list fetch and the machine lookup are handed in as futures so a test can
  // hold either open and observe the state it asserts — a list still loading, a
  // machine not yet named — instead of racing through it. They are created
  // inside the test body on purpose: a Completer made in `setUp` belongs to the
  // enclosing zone, and completing it would never resume the awaits running in
  // the test's own fake-async zone.
  // -------------------------------------------------------------------------

  group("connected to a bridge", () {
    final macbook = BridgeSummary(
      id: "a",
      name: "Macbook-Pro.local",
      platform: "macos",
      addedAt: DateTime.utc(2026),
      lastSeenAt: DateTime.utc(2026, 7),
    );

    /// A one-project list, the payload the loaded-bar tests use.
    ApiResponse<Projects> oneProject() {
      final projects = Projects(
        data: [testProject(id: "p1", name: "app")],
      );
      return ApiResponse.success(projects);
    }

    setUp(() {
      statusController.add(connected);
      when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    });

    /// Frames enough to carry both cubits' await chains — the connection check,
    /// the list fetch, the registered-bridge latch and the bridge lookup —
    /// through to a rebuilt bar. Deliberately not [WidgetTester.pumpAndSettle]:
    /// the subtitle skeleton's sheen sweeps forever, so a settle would never
    /// return while the row is still waiting for its name.
    Future<void> drainFrames(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
    }

    /// Pumps the screen on a phone viewport, answering the list fetch with
    /// [list] and the machine lookup with [lookup], then drains the initial
    /// async work.
    Future<void> pumpConnected(
      WidgetTester tester, {
      required Future<ApiResponse<Projects>> list,
      required Future<List<BridgeSummary>> lookup,
    }) async {
      when(() => mockProjectRepository.listProjects()).thenAnswer((_) => list);
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) => lookup);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildApp());
      await drainFrames(tester);
      // Unmount before the test ends so the shimmer's ticker and appear timer —
      // and the screen's own minute ticker — are disposed rather than left
      // pending.
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    }

    testWidgets("the loaded list carries the page title over the machine name, with no large title", (tester) async {
      await pumpConnected(tester, list: Future.value(oneProject()), lookup: Future.value([macbook]));

      expect(find.byType(PregoNavLeadingTitle), findsOneWidget);
      // The only "Projects" on the page is the bar's own title: the list no
      // longer hosts a large one to scroll away.
      expect(largeTitle("Projects"), findsNothing);
      expect(find.text("Projects"), findsOneWidget);
      expect(find.text("Macbook-Pro.local"), findsOneWidget);
      expect(find.byIcon(TablerRegular.device_laptop), findsOneWidget);
      // Reachable, so the row's dot reads as online rather than carrying the
      // disconnected surfaces' error dot.
      expect(
        tester.widget<PregoNavSubtitle>(find.byType(PregoNavSubtitle)).status,
        PregoNavStatus.online,
      );
    });

    testWidgets("the loading page wears the same bar, shimmering the machine it cannot name yet", (tester) async {
      // Neither answer arrives: the page stays on its first load with nothing to
      // name yet.
      await pumpConnected(
        tester,
        list: Completer<ApiResponse<Projects>>().future,
        lookup: Completer<List<BridgeSummary>>().future,
      );

      expect(find.byType(PregoNavLeadingTitle), findsOneWidget);
      expect(find.text("Projects"), findsOneWidget);
      expect(largeTitle("Projects"), findsNothing);
      // The row is held by its skeleton rather than left out, so the block keeps
      // the height it will have once the name lands.
      expect(find.byType(PregoNavSubtitleSkeleton), findsOneWidget);
      expect(find.byType(PregoNavSubtitle), findsNothing);
    });

    testWidgets("the machine name lands in the space its skeleton was holding", (tester) async {
      final lookupGate = Completer<List<BridgeSummary>>();

      await pumpConnected(tester, list: Future.value(oneProject()), lookup: lookupGate.future);
      expect(find.byType(PregoNavSubtitleSkeleton), findsOneWidget);
      final titleWhileShimmering = tester.getTopLeft(find.text("Projects"));

      lookupGate.complete([macbook]);
      await drainFrames(tester);

      expect(find.byType(PregoNavSubtitleSkeleton), findsNothing);
      expect(find.text("Macbook-Pro.local"), findsOneWidget);
      // The point of the skeleton: the title above it does not move when the
      // real row replaces it.
      expect(tester.getTopLeft(find.text("Projects")), titleWhileShimmering);
    });

    testWidgets("a lookup with no machine to name drops the row for good", (tester) async {
      // An empty answer is the service's fail-soft shape, not an error.
      await pumpConnected(tester, list: Future.value(oneProject()), lookup: Future.value(const []));

      expect(find.byType(PregoNavSubtitleSkeleton), findsNothing);
      expect(find.byType(PregoNavSubtitle), findsNothing);
      expect(find.text("Projects"), findsOneWidget);
    });
  });
}
