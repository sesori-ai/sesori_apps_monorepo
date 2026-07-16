import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/features/project_list/rename_project_dialog.dart";
import "package:sesori_mobile/features/project_list/widgets/project_tile.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// Swiping a project row toward its start edge reveals the rename button and
/// the hide pill ([PregoSwipeActions]); a full swipe commits the hide without
/// the buttons. The long-press menu stays as the other path to the same
/// actions.
///
/// Drag distances assume the 800px default test surface: the reveal strip is
/// ~204px (settle-open past ~102px of drag) and the full-swipe commit
/// threshold is 480px. ~20px of every drag is spent on touch slop.
void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
  const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
  const connected = ConnectionStatus.connected(config: config, health: health);

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
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    // Hiding the only project empties the list, and the cubit enriches the
    // empty state with the bridges it would offer to add a project on.
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);

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

  final project = testProject(id: "/home/user/my-app", path: "/home/user/my-app");

  /// Pumps the real screen with a single project loaded. A router hosts it
  /// because the rename sheet pops itself with go_router's `context.pop()`.
  Future<void> pumpScreen(WidgetTester tester) async {
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(Projects(data: [project])),
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: "/", builder: (_, _) => const ProjectListScreen()),
        GoRoute(path: "/projects/:projectId/sessions", builder: (_, _) => const SizedBox.shrink()),
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
    await tester.pumpAndSettle();
  }

  Finder tile() => find.widgetWithText(ProjectTile, "my-app");

  /// Swipes the row far enough to settle open on its actions.
  Future<void> swipeOpen(WidgetTester tester) async {
    await tester.drag(tile(), const Offset(-160, 0));
    await tester.pumpAndSettle();
  }

  testWidgets("swiping the row reveals Rename and Hide without navigating or acting", (tester) async {
    await pumpScreen(tester);

    // The hide pill starts past the row's edge, clipped out of view.
    expect(tester.getRect(find.text("Hide")).left, greaterThanOrEqualTo(800));

    await swipeOpen(tester);

    expect(tester.getRect(find.text("Hide")).left, lessThan(800));
    expect(find.byIcon(TablerRegular.pencil), findsOneWidget);
    // Still the list — the swipe is not a tap — and nothing was acted on.
    expect(tile(), findsOneWidget);
    verifyNever(() => mockProjectRepository.hideProject(projectId: any(named: "projectId")));
    expect(find.byType(RenameProjectDialog), findsNothing);
  });

  testWidgets("the revealed Hide pill hides the project and confirms with a snackbar", (tester) async {
    when(() => mockProjectRepository.hideProject(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.success(null),
    );

    await pumpScreen(tester);
    await swipeOpen(tester);

    await tester.tap(find.text("Hide"));
    await tester.pumpAndSettle();

    verify(() => mockProjectRepository.hideProject(projectId: project.id)).called(1);
    expect(find.text("Project hidden"), findsOneWidget);
    expect(tile(), findsNothing);
  });

  testWidgets("a rejected hide from the pill keeps the row and reports the failure", (tester) async {
    when(() => mockProjectRepository.hideProject(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );

    await pumpScreen(tester);
    await swipeOpen(tester);

    await tester.tap(find.text("Hide"));
    await tester.pumpAndSettle();

    expect(find.text("Failed to hide project"), findsOneWidget);
    expect(tile(), findsOneWidget);
  });

  testWidgets("the revealed rename button closes the row and opens the rename sheet", (tester) async {
    await pumpScreen(tester);
    await swipeOpen(tester);

    await tester.tap(find.byIcon(TablerRegular.pencil));
    await tester.pumpAndSettle();

    expect(find.byType(RenameProjectDialog), findsOneWidget);
    verifyNever(() => mockProjectRepository.hideProject(projectId: any(named: "projectId")));
  });

  testWidgets("a full swipe hides the project without touching the buttons", (tester) async {
    when(() => mockProjectRepository.hideProject(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.success(null),
    );

    await pumpScreen(tester);

    await tester.drag(tile(), const Offset(-520, 0));
    await tester.pumpAndSettle();

    verify(() => mockProjectRepository.hideProject(projectId: project.id)).called(1);
    expect(find.text("Project hidden"), findsOneWidget);
    expect(tile(), findsNothing);
  });

  testWidgets("tapping the open row closes it instead of navigating; the next tap navigates", (tester) async {
    await pumpScreen(tester);
    await swipeOpen(tester);

    // The tap lands on the row's close-catcher, not the content underneath.
    await tester.tap(tile(), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Closed, still on the list: the actions are back off-row and no route
    // was pushed.
    expect(tester.getRect(find.text("Hide")).left, greaterThanOrEqualTo(800));
    expect(tile(), findsOneWidget);

    await tester.tap(tile());
    await tester.pumpAndSettle();

    // Now it navigated: the sessions route covers the list.
    expect(tile(), findsNothing);
  });

  testWidgets("the long-press menu still works after a swipe-open-close cycle", (tester) async {
    await pumpScreen(tester);
    await swipeOpen(tester);

    await tester.tap(tile(), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.longPress(tile());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InkWell, "Rename"), findsOneWidget);
    expect(find.widgetWithText(InkWell, "Hide Project"), findsOneWidget);
  });
}
