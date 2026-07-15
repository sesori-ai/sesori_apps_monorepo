import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// A project's id is a stable identifier that survives folder moves; its path
/// is the live directory. The tile must DISPLAY the path (and derive the
/// fallback name from it) while still NAVIGATING with the id — that handle is
/// what every bridge API call is keyed on.
void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
  const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
  const connected = ConnectionStatus.connected(config: config, health: health);

  late BehaviorSubject<ConnectionStatus> statusController;
  late MockConnectionService mockConnectionService;
  late MockProjectService mockProjectService;
  late MockProjectRepository mockProjectRepository;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late StubConnectionOverlayCubit overlayCubit;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    statusController = BehaviorSubject<ConnectionStatus>.seeded(connected);
    mockConnectionService = MockConnectionService();
    mockProjectService = MockProjectService();
    mockProjectRepository = MockProjectRepository();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    overlayCubit = StubConnectionOverlayCubit();

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);

    getIt.registerLazySingleton<ProjectService>(() => mockProjectService);
    registerListServices(
      projectService: mockProjectService,
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

  /// Hosts the screen in a minimal router so tile taps have somewhere to
  /// navigate; the sessions route records the projectId path parameter it
  /// received.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<Project> projects,
    required void Function(String projectId) onSessionsRoute,
  }) async {
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(Projects(data: projects)),
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: "/", builder: (_, _) => const ProjectListScreen()),
        GoRoute(
          path: "/projects/:projectId/sessions",
          builder: (_, state) {
            onSessionsRoute(state.pathParameters["projectId"]!);
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
    await tester.pumpAndSettle();
  }

  testWidgets("tile displays the live path and derives the fallback name from it, but navigates with the id", (
    tester,
  ) async {
    // A moved project: the stable id points where the folder used to be.
    final project = testProject(id: "/projects/my-app", path: "/moved/my-app");
    String? pushedProjectId;

    await pumpScreen(
      tester,
      projects: [project],
      onSessionsRoute: (projectId) => pushedProjectId = projectId,
    );

    // Displays the live directory, not the id…
    expect(find.text("moved/my-app"), findsOneWidget);
    expect(find.text("projects/my-app"), findsNothing);
    // …and derives the name from the live directory's basename.
    expect(find.text("my-app"), findsOneWidget);

    await tester.tap(find.text("my-app"));
    await tester.pumpAndSettle();

    // The bridge keys every project call on the id, so navigation carries it.
    expect(pushedProjectId, equals("/projects/my-app"));
  });

  testWidgets("tile derives the name from a Windows bridge path", (tester) async {
    // Paths come from the bridge's host platform — a Windows bridge sends
    // backslash-separated directories that the phone must still parse.
    final project = testProject(id: r"C:\dev\win-app", path: r"C:\dev\win-app");

    await pumpScreen(tester, projects: [project], onSessionsRoute: (_) {});

    expect(find.text("win-app"), findsOneWidget);
  });

  testWidgets("tile falls back to the id when an older bridge sends no path", (tester) async {
    // Older bridges omit `path`; there the id IS the directory.
    final project = Project.fromJson({
      "id": "/home/user/legacy-app",
      "name": null,
      "time": {"created": 1700000000000, "updated": 1700000000000},
    });

    await pumpScreen(tester, projects: [project], onSessionsRoute: (_) {});

    // A row is far too narrow for a real path, so only the segments that tell
    // projects apart survive; the dropped head is marked with an ellipsis.
    expect(find.text("…/user/legacy-app"), findsOneWidget);
    expect(find.text("legacy-app"), findsOneWidget);
  });
}
