import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  testWidgets("each cockpit eagerly owns one inventory and disposes it with the signed-in scope", (tester) async {
    final repository = MockProjectRepository();
    final connection = MockConnectionService();
    final activity = MockSseEventTracker();
    final unseen = FakeSessionUnseenTracker();
    final catalog = FakeCatalogRescanService();
    final events = StreamController<SseEvent>.broadcast(sync: true);
    final projects = ProjectListService(repository: repository, activityCalculator: const SessionActivityCalculator());
    final instances = <RecentSessionInventoryService>[];
    final closed = <RecentSessionInventoryService>[];
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
    // Register only the owned fake-backed factory, never production DI/bootstrap.
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
    addTearDown(() async {
      await getIt.unregister<RecentSessionInventoryService>();
      await projects.dispose();
      await events.close();
      await activity.onDispose();
      await unseen.onDispose();
      await catalog.onDispose();
    });

    // No child reads the Cubit: its eager construction must attach admission.
    await tester.pumpWidget(const DesktopCockpitCubitProvider(child: SizedBox.shrink()));
    expect(instances, hasLength(1));
    final first = instances.single;
    final publication = projects.listProjects();
    await tester.pump();
    await publication;
    expect(first.state.value["one"], isA<RecentSessionsLoaded>());
    final context = tester.element(find.byType(SizedBox));
    expect(context.read<RecentSessionInventoryService>(), same(first));
    final consumer = context.read<RecentSessionsCubit>();
    expect(consumer.state, same(first.state.value));

    await tester.pumpWidget(const SizedBox.shrink());
    // Provider teardown's asynchronous cancellations also finish in the real test zone.
    await tester.runAsync(() async {});
    await tester.pump();
    expect(consumer.isClosed, isTrue);
    expect(events.hasListener, isFalse);
    expect(closed, [first]);

    await tester.pumpWidget(const DesktopCockpitCubitProvider(child: SizedBox.shrink()));
    expect(instances, hasLength(2));
    expect(instances.last, isNot(same(first)));
    expect(instances.last.state.value, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {});
    await tester.pump();
    expect(closed, instances);
    expect(events.hasListener, isFalse);
  });
}
