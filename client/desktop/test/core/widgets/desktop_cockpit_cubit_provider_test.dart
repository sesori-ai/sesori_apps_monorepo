import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_shared/sesori_shared.dart";

class _MockProjectInventoryService() extends Mock implements ProjectInventoryService;

class _MockSessionWindowService() extends Mock implements SessionWindowService;

void main() {
  setUpAll(registerCoreFallbackValues);

  testWidgets("cockpits own the project inventory and the sessions window, and dispose their scopes", (tester) async {
    final repository = MockProjectRepository();
    final connection = MockConnectionService();
    final activity = MockSseEventTracker();
    final unseen = FakeSessionUnseenTracker();
    final catalog = FakeCatalogRescanService();
    final events = StreamController<SseEvent>.broadcast(sync: true);
    final projects = ProjectListService(repository: repository);
    final projectInstances = <ProjectInventoryService>[];
    final windows = <SessionWindowService>[];
    final closedWindows = <SessionWindowService>[];
    final closedProjects = <ProjectInventoryService>[];
    var workflowCount = 0;
    when(() => connection.events).thenAnswer((_) => events.stream);
    final statuses = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
    addTearDown(statuses.close);
    when(() => connection.status).thenAnswer((_) => statuses);
    when(() => connection.currentStatus).thenAnswer((_) => statuses.value);
    when(repository.listProjects).thenAnswer(
      (_) async => ApiResponse.success(
        const Projects(
          data: [ProjectSummary(id: "one", name: "One", path: "/one", time: null)],
        ),
      ),
    );
    // Register only owned fake-backed factories, never production DI/bootstrap.
    getIt.registerFactory<SessionCleanupService>(() => SessionCleanupService(repository: MockSessionRepository()));
    getIt.registerSingleton<RegisteredBridgesService>(MockRegisteredBridgesService());
    getIt.registerSingleton<ConnectionService>(connection);
    getIt.registerSingleton<ActiveBridgeLocality>(const FakeActiveBridgeLocality());
    final filterTracker = SessionListFilterTracker(connectionService: connection, projectListService: projects);
    getIt.registerSingleton<SessionListFilterTracker>(filterTracker);
    getIt.registerFactory<SessionLaunchService>(
      () => inMemorySessionLaunchService(launchRepository: inMemorySessionLaunchRepository()),
    );
    getIt.registerFactory<ProjectInventoryService>(() {
      final inventory = _MockProjectInventoryService();
      final states = BehaviorSubject<ProjectListState>.seeded(const ProjectListState.loading());
      when(() => inventory.state).thenAnswer((_) => states.value);
      when(() => inventory.stateStream).thenAnswer((_) => states.stream);
      when(inventory.dispose).thenAnswer((_) async {
        await states.close();
        closedProjects.add(inventory);
      });
      projectInstances.add(inventory);
      unawaited(projects.listProjects());
      return inventory;
    });
    getIt.registerSingleton<SseEventTracker>(activity);
    getIt.registerSingleton<SessionUnseenTracker>(unseen);
    getIt.registerFactoryParam<SessionWindowService, AllSessionsMode, ProjectInventoryService>((mode, project) {
      expect(mode, AllSessionsMode.active);
      expect(project, same(projectInstances.last));
      final window = _MockSessionWindowService();
      when(window.dispose).thenAnswer((_) async => closedWindows.add(window));
      windows.add(window);
      return window;
    });
    getIt.registerFactoryParam<SessionListRefreshService, ProjectInventoryService, SessionWindowService>((
      project,
      window,
    ) {
      expect(project, same(projectInstances.last));
      expect(window, same(windows.last));
      workflowCount++;
      return SessionListRefreshService(
        projectInventory: project,
        window: window,
        catalogRescanService: catalog,
      );
    });
    addTearDown(() async {
      await getIt.unregister<SessionListRefreshService>();
      await getIt.unregister<SessionWindowService>();
      await getIt.unregister<SseEventTracker>();
      await getIt.unregister<SessionUnseenTracker>();
      await getIt.unregister<SessionCleanupService>();
      await getIt.unregister<RegisteredBridgesService>();
      await getIt.unregister<ConnectionService>();
      await getIt.unregister<ActiveBridgeLocality>();
      await getIt.unregister<SessionListFilterTracker>();
      await filterTracker.dispose();
      await getIt.unregister<SessionLaunchService>();
      await getIt.unregister<ProjectInventoryService>();
      await projects.dispose();
      await events.close();
      await activity.onDispose();
      await unseen.onDispose();
      await catalog.onDispose();
    });

    final child = Builder(
      builder: (context) {
        context.read<ProjectListCubit>();
        context.read<SessionListRefreshCubit>();
        context.read<SessionWindowService>();
        return const SizedBox.shrink();
      },
    );
    await tester.pumpWidget(DesktopCockpitCubitProvider(child: child));
    await tester.pump();
    expect(projectInstances, hasLength(1));
    expect(windows, hasLength(1));
    final context = tester.element(find.byType(SizedBox));
    expect(context.read<ProjectInventoryService>(), same(projectInstances.single));
    expect(context.read<SessionWindowService>(), same(windows.single));
    final projectConsumer = context.read<ProjectListCubit>();
    final refreshConsumer = context.read<SessionListRefreshCubit>();
    expect(workflowCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    // Provider teardown's asynchronous cancellations also finish in the real test zone.
    await tester.runAsync(() async {});
    await tester.pump();
    expect(projectConsumer.isClosed, isTrue);
    expect(refreshConsumer.isClosed, isTrue);
    expect(events.hasListener, isFalse);
    expect(closedWindows, windows);
    expect(closedProjects, projectInstances);

    await tester.pumpWidget(DesktopCockpitCubitProvider(child: child));
    expect(projectInstances, hasLength(2));
    expect(windows, hasLength(2));
    expect(workflowCount, 2);
    expect(projectInstances.last, isNot(same(projectInstances.first)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {});
    await tester.pump();
    expect(closedProjects, projectInstances);
    expect(closedWindows, windows);
    expect(events.hasListener, isFalse);
  });
}
