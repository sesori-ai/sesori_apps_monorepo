import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/features/project_list/widgets/project_tile.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// A project row's third line is a single status slot — running, unopened,
/// unavailable, or nothing — followed by when the project last changed.
///
/// A running row twinkles on an infinite repeating animation, so these tests
/// pump fixed durations and never `pumpAndSettle` — it would pump to its
/// timeout and throw.
void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
  const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
  const connected = ConnectionStatus.connected(config: config, health: health);

  /// The row is laid out from the type scale it renders — a 16/24 title over
  /// two 14/20 detail lines, inside 12px of padding — and the whole list is
  /// pitched on it. A style change that drifts this drifts the list.
  const rowHeight = 96.0;

  late BehaviorSubject<ConnectionStatus> statusController;
  late MockConnectionService mockConnectionService;
  late MockProjectRepository mockProjectRepository;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late StubConnectionOverlayCubit overlayCubit;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    statusController = BehaviorSubject<ConnectionStatus>.seeded(connected);
    mockConnectionService = MockConnectionService();
    mockProjectRepository = MockProjectRepository();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    overlayCubit = StubConnectionOverlayCubit();

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);

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

  /// Pumps the list without settling, so a twinkling row doesn't hang the test.
  /// The fixed pumps carry the cubit's load future through to a rendered list.
  Future<void> pumpList(
    WidgetTester tester, {
    required List<Project> projects,
    Map<String, int> activeSessions = const {},
    void Function(String projectId)? onSessionsRoute,
  }) async {
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(Projects(data: projects)),
    );
    // Seeded before the cubit loads, so the first rendered list already carries
    // the activity rather than flashing an idle row.
    (getIt<SseEventTracker>() as MockSseEventTracker).emitProjectActivity(activeSessions);

    final router = GoRouter(
      routes: [
        GoRoute(path: "/", builder: (_, _) => const ProjectListScreen()),
        GoRoute(
          path: "/projects/:projectId/sessions",
          builder: (_, state) {
            onSessionsRoute?.call(state.pathParameters["projectId"]!);
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>.value(
        value: overlayCubit,
        child: MaterialApp.router(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Color titleColour(WidgetTester tester, String name) => tester.widget<Text>(find.text(name)).style!.color!;

  FontWeight? titleWeight(WidgetTester tester, String name) =>
      tester.widget<Text>(find.text(name)).style!.fontWeight;

  /// Whether the row's sparkle is twinkling. `tester.hasRunningAnimations` is
  /// no use here — the router's own page transition keeps it true — so the
  /// sparkle's contract is read off the widget. That the flag really does start
  /// and stop the loop is PregoAiLoader's own test.
  bool sparkleTwinkles(WidgetTester tester) => tester.widget<PregoAiLoader>(find.byType(PregoAiLoader)).animate;

  group("a project an agent is working in", () {
    testWidgets("marks itself Running with a twinkling sparkle", (tester) async {
      final project = testProject(id: "p1", name: "my-app");

      await pumpList(tester, projects: [project], activeSessions: {"p1": 1});

      expect(find.text("Running"), findsOneWidget);
      expect(find.byType(PregoAiLoader), findsOneWidget);
      expect(sparkleTwinkles(tester), isTrue);
    });

    testWidgets("counts the sessions when more than one is live", (tester) async {
      final project = testProject(id: "p1", name: "my-app");

      await pumpList(tester, projects: [project], activeSessions: {"p1": 2});

      expect(find.text("2 running"), findsOneWidget);
    });
  });

  group("a project with activity the user hasn't opened", () {
    testWidgets("marks itself New activity, without moving", (tester) async {
      final project = testProject(id: "p1", name: "my-app").copyWith(hasUnseenChanges: true);

      await pumpList(tester, projects: [project]);

      expect(find.text("New activity"), findsOneWidget);
      expect(find.byType(PregoAiLoader), findsOneWidget);
      // Unopened activity is a state, not an event: the sparkle marks it but
      // must not animate, or a list nobody is working in would twinkle forever.
      expect(sparkleTwinkles(tester), isFalse);
    });

    testWidgets("weights its title against the rows the user has already read", (tester) async {
      await pumpList(
        tester,
        projects: [
          testProject(id: "p1", name: "unread").copyWith(hasUnseenChanges: true),
          testProject(id: "p2", name: "read"),
        ],
      );

      expect(titleWeight(tester, "unread"), FontWeight.w500);
      expect(titleWeight(tester, "read"), FontWeight.w400);
    });
  });

  testWidgets("a running project that is also unseen reports the live turn, not the backlog", (tester) async {
    // Both are true; the slot holds one. A turn in flight is the more useful
    // thing to say, and the title's weight still carries the unopened state.
    final project = testProject(id: "p1", name: "my-app").copyWith(hasUnseenChanges: true);

    await pumpList(tester, projects: [project], activeSessions: {"p1": 1});

    expect(find.text("Running"), findsOneWidget);
    expect(find.text("New activity"), findsNothing);
    expect(titleWeight(tester, "my-app"), FontWeight.w500);
  });

  testWidgets("a read, idle project says only when it last changed", (tester) async {
    final project = testProject(id: "p1", name: "my-app").copyWith(
      time: ProjectTime(created: 0, updated: DateTime.now().millisecondsSinceEpoch),
    );

    await pumpList(tester, projects: [project]);

    expect(find.byType(PregoAiLoader), findsNothing);
    expect(find.text("Running"), findsNothing);
    expect(find.text("New activity"), findsNothing);
    expect(find.text("just now"), findsOneWidget);
  });

  group("a project whose folder is gone", () {
    Project missingProject() => testProject(id: "p1", path: "/gone/my-app", name: "my-app").copyWith(
      directoryMissing: true,
      time: ProjectTime(created: 0, updated: DateTime.now().millisecondsSinceEpoch),
    );

    testWidgets("recedes, and says why", (tester) async {
      await pumpList(tester, projects: [missingProject()]);

      expect(find.text("Unavailable"), findsOneWidget);
      expect(titleColour(tester, "my-app"), PregoColorsLight.textDisabled);
      // When the folder is gone, when it last changed is noise.
      expect(find.text("just now"), findsNothing);
      expect(find.byType(PregoAiLoader), findsNothing);
    });

    testWidgets("refuses to open, and explains instead", (tester) async {
      var navigated = false;

      await pumpList(
        tester,
        projects: [missingProject()],
        onSessionsRoute: (_) => navigated = true,
      );

      await tester.tap(find.text("my-app"));
      await tester.pump();
      await tester.pump();

      expect(navigated, isFalse);
      expect(find.textContaining("no longer exists"), findsOneWidget);
    });
  });

  group("the list's pitch", () {
    testWidgets("every row is the same height", (tester) async {
      await pumpList(
        tester,
        projects: [
          testProject(id: "p1", name: "running"),
          testProject(id: "p2", name: "unseen").copyWith(hasUnseenChanges: true),
          testProject(id: "p3", name: "idle"),
        ],
        activeSessions: {"p1": 1},
      );

      for (final name in ["running", "unseen", "idle"]) {
        expect(tester.getSize(find.widgetWithText(ProjectTile, name)).height, rowHeight);
      }
    });

    testWidgets("survives a project from a bridge too old to send a timestamp", (tester) async {
      // COMPATIBILITY 2026-07-11 (v1.4.1): Old bridges omit Project.time, so the
      // row has no status and nothing to date. Its line box stays open anyway —
      // a short row here would knock the whole list off its pitch.
      final project = Project.fromJson({"id": "p1", "name": "my-app", "path": "/x/my-app", "time": null});

      await pumpList(tester, projects: [project]);

      expect(tester.getSize(find.widgetWithText(ProjectTile, "my-app")).height, rowHeight);
    });
  });

  group("under scaled-up accessibility text", () {
    /// Pumps a single bare tile — not the whole screen — at 3x text scale, so
    /// these tests exercise the row's own layout and can't fail for the glass
    /// scaffold's sake. [width] is the logical screen width.
    Future<void> pumpScaledTile(
      WidgetTester tester, {
      required Project project,
      required double width,
      int activeSessions = 0,
      bool unseen = false,
    }) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: Align(
              alignment: Alignment.topCenter,
              child: ProjectTile(project: project, activeSessions: activeSessions, unseen: unseen),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets("the status line grows with the text instead of cropping it to the 1x line box", (tester) async {
      final project = testProject(id: "p1", name: "my-app");

      await pumpScaledTile(tester, project: project, width: 520, activeSessions: 1);

      // The 14/20 status text needs three times its line box at 3x; a fixed
      // 20px box would crop it to the top third of its glyphs.
      expect(tester.getSize(find.text("Running")).height, greaterThan(20));
    });

    testWidgets("the status label yields to the timestamp instead of overflowing the row", (tester) async {
      final project = testProject(id: "p1", name: "my-app").copyWith(
        time: ProjectTime(created: 0, updated: DateTime.now().millisecondsSinceEpoch),
      );

      // Narrow enough that "New activity" plus "just now" cannot both fit —
      // but wide enough for the timestamp alone, which the test font inflates
      // to a full fontSize per glyph.
      await pumpScaledTile(tester, project: project, width: 480, unseen: true);

      // The ellipsized label is still the same Text; the timestamp keeps its
      // full width inside the row.
      expect(find.text("New activity"), findsOneWidget);
      final tile = tester.getRect(find.byType(ProjectTile));
      expect(tester.getRect(find.text("just now")).right, lessThanOrEqualTo(tile.right));
    });
  });

  group("the loading skeleton", () {
    testWidgets("keeps its bars at their designed height inside taller line boxes", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: const Material(child: ProjectTileSkeleton()),
        ),
      );

      // The title's 24px line box is taller than its 20px bar; the box must
      // hold the line open without stretching the bar to fill it.
      for (var i = 0; i < 3; i++) {
        expect(tester.getSize(find.byType(PregoSkeletonBar).at(i)).height, 20);
      }
    });
  });

  testWidgets("a row announces itself as one button, not three lines of text", (tester) async {
    // Both came free from ListTile, and the redesign has to supply them: an
    // InkWell contributes the actions but not the role, and leaves the row's
    // lines as separate nodes to swipe past one at a time.
    final handle = tester.ensureSemantics();
    final project = testProject(id: "p1", path: "/work/my-app", name: "my-app").copyWith(
      time: ProjectTime(created: 0, updated: DateTime.now().millisecondsSinceEpoch),
    );

    await pumpList(tester, projects: [project]);

    expect(
      tester.getSemantics(find.descendant(of: find.byType(ProjectTile), matching: find.byType(MergeSemantics))),
      matchesSemantics(
        label: "my-app\nwork/my-app\njust now",
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasLongPressAction: true,
        hasFocusAction: true,
      ),
    );

    handle.dispose();
  });
}
