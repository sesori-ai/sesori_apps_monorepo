import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";

class _MockProjectInventoryService() extends Mock implements ProjectInventoryService;

void main() {
  testWidgets("cockpits own both inventories, admit initial projects, and dispose their scopes", (tester) async {
    final repository = MockProjectRepository();
    final connection = MockConnectionService();
    final activity = MockSseEventTracker();
    final unseen = FakeSessionUnseenTracker();
    final catalog = FakeCatalogRescanService();
    final events = StreamController<SseEvent>.broadcast(sync: true);
    final projects = ProjectListService(repository: repository, activityCalculator: const SessionActivityCalculator());
    final instances = <RecentSessionInventoryService>[];
    final closed = <RecentSessionInventoryService>[];
    final projectInstances = <ProjectInventoryService>[];
    final closedProjects = <ProjectInventoryService>[];
    var workflowCount = 0;
    when(() => connection.events).thenAnswer((_) => events.stream);
    when(repository.listProjects).thenAnswer(
      (_) async => ApiResponse.success(
        const Projects(
          data: [ProjectSummary(id: "one", name: "One", path: "/one", time: null)],
        ),
      ),
    );
    when(() => repository.listSessions(projectId: "one", waitForPrData: false)).thenAnswer(
      (_) async => ApiResponse.success(const SessionListResponse(items: [])),
    );
    // Register only owned fake-backed factories, never production DI/bootstrap.
    getIt.registerFactory<SessionRepository>(MockSessionRepository.new);
    getIt.registerFactory<RecentSessionInventoryService>(() {
      final inventory = RecentSessionInventoryService(
        sessionListService: SessionListService(
          repository: repository,
          activityCalculator: const SessionActivityCalculator(),
        ),
        projectListService: projects,
        connectionService: connection,
        sseEventTracker: activity,
        sessionUnseenTracker: unseen,
        catalogRescanService: catalog,
      );
      instances.add(inventory);
      inventory.state.listen((_) {}, onDone: () => closed.add(inventory));
      return inventory;
    });
    getIt.registerFactory<ProjectInventoryService>(() {
      // Recent admission must already exist before project startup publishes.
      expect(instances, hasLength(projectInstances.length + 1));
      expect(instances.last.state.value, isEmpty);
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
    getIt.registerFactoryParam<DesktopSidebarRefreshService, ProjectInventoryService, RecentSessionInventoryService>((
      project,
      recent,
    ) {
      expect(project, same(projectInstances.last));
      expect(recent, same(instances.last));
      workflowCount++;
      return DesktopSidebarRefreshService(projectInventory: project, recentInventory: recent);
    });
    addTearDown(() async {
      await getIt.unregister<DesktopSidebarRefreshService>();
      await getIt.unregister<SessionRepository>();
      await getIt.unregister<ProjectInventoryService>();
      await getIt.unregister<RecentSessionInventoryService>();
      await projects.dispose();
      await events.close();
      await activity.onDispose();
      await unseen.onDispose();
      await catalog.onDispose();
    });

    final child = Builder(
      builder: (context) {
        context.read<ProjectListCubit>();
        context.read<DesktopSidebarRefreshCubit>();
        return const SizedBox.shrink();
      },
    );
    await tester.pumpWidget(DesktopCockpitCubitProvider(child: child));
    await tester.pump();
    expect(instances, hasLength(1));
    expect(projectInstances, hasLength(1));
    final first = instances.single;
    expect(first.state.value["one"], isA<RecentSessionsLoaded>());
    final context = tester.element(find.byType(SizedBox));
    expect(context.read<RecentSessionInventoryService>(), same(first));
    expect(context.read<ProjectInventoryService>(), same(projectInstances.single));
    final consumer = context.read<RecentSessionsCubit>();
    final projectConsumer = context.read<ProjectListCubit>();
    final refreshConsumer = context.read<DesktopSidebarRefreshCubit>();
    expect(workflowCount, 1);
    expect(consumer.state, same(first.state.value));

    await tester.pumpWidget(const SizedBox.shrink());
    // Provider teardown's asynchronous cancellations also finish in the real test zone.
    await tester.runAsync(() async {});
    await tester.pump();
    expect(consumer.isClosed, isTrue);
    expect(projectConsumer.isClosed, isTrue);
    expect(refreshConsumer.isClosed, isTrue);
    expect(events.hasListener, isFalse);
    expect(closed, [first]);
    expect(closedProjects, projectInstances);

    await tester.pumpWidget(DesktopCockpitCubitProvider(child: child));
    expect(instances, hasLength(2));
    expect(projectInstances, hasLength(2));
    expect(workflowCount, 2);
    expect(instances.last, isNot(same(first)));
    expect(projectInstances.last, isNot(same(projectInstances.first)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {});
    await tester.pump();
    expect(closed, instances);
    expect(closedProjects, projectInstances);
    expect(events.hasListener, isFalse);
  });
}
