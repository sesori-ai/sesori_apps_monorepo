import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockAllSessionsCubit() extends MockCubit<AllSessionsState> implements AllSessionsCubit;

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

class _MockRecentSessionInventoryService() extends Mock implements RecentSessionInventoryService;

void main() {
  const project = ProjectSummary(id: "p1", name: "Project One", path: "/p1", time: null);

  AllSessionsState state({
    required String query,
    required List<AllSessionsFailure> failures,
    required List<AllSessionsRow> rows,
    required String? scratchProjectId,
    SessionListChipCounts counts = const SessionListChipCounts(all: 0, running: 0, unread: 0),
    bool isLoading = false,
  }) => AllSessionsState(
    projectId: null,
    query: query,
    quickFilter: SessionListQuickFilter.all,
    everyProjectRows: rows,
    rows: rows,
    counts: counts,
    failures: failures,
    isLoading: isLoading,
    scratchProjectId: scratchProjectId,
    defaultProjectId: null,
  );

  AllSessionsRow row({
    required String title,
    required DateTime updatedAt,
    required DateTime? archivedAt,
    required bool isRunning,
  }) => AllSessionsRow(
    session: testSession(
      id: title,
      title: title,
      updatedAt: updatedAt.millisecondsSinceEpoch,
      archivedAt: archivedAt,
    ),
    project: project,
    isRunning: isRunning,
    isUnseen: false,
    isAwaitingInput: false,
    isRetrying: false,
    backgroundTaskCount: 0,
  );

  late _MockProjectListCubit projects;

  Future<_MockAllSessionsCubit> pumpList(
    WidgetTester tester, {
    required AllSessionsState initial,
    Stream<AllSessionsState> updates = const Stream.empty(),
    AllSessionsMode mode = AllSessionsMode.archived,
    ProjectListState projectList = const ProjectListState.loaded(
      projects: [project],
      folderProjects: [project],
      scratchProject: null,
    ),
    Stream<ProjectListState> projectUpdates = const Stream.empty(),
    AllSessionsDisconnectedBuilder disconnectedBuilder = _offlinePage,
  }) async {
    final cubit = _MockAllSessionsCubit();
    whenListen(cubit, updates, initialState: initial);
    when(() => cubit.mode).thenReturn(mode);
    when(() => cubit.retry(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    when(() => cubit.setHiddenSessionIds(sessionIds: any(named: "sessionIds"))).thenReturn(null);
    projects = _MockProjectListCubit();
    whenListen(projects, projectUpdates, initialState: projectList);
    when(() => projects.retryLoadProjects()).thenAnswer((_) async {});
    final inventory = _MockRecentSessionInventoryService();
    when(() => inventory.state).thenAnswer((_) => BehaviorSubject.seeded(const {}));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AllSessionsCubit>.value(value: cubit),
            BlocProvider<ProjectListCubit>.value(value: projects),
            BlocProvider(
              create: (_) => PendingSessionArchiveCubit(
                cleanupService: SessionCleanupService(repository: MockSessionRepository()),
              ),
            ),
            RepositoryProvider<RecentSessionInventoryService>.value(value: inventory),
            RepositoryProvider(create: (_) => idleSessionLaunchService()),
          ],
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                AllSessionsList(
                  onSessionTap: ({required row}) {},
                  actionDispatcher: const SessionListActionDispatcher(
                    deleteConfirmation: SessionDeleteConfirmation.sheet,
                    onSessionArchived: null,
                    onSessionDeleted: null,
                    onSessionMarkedUnread: null,
                  ),
                  createActionCubit: ({required projectId, required session}) => throw StateError("no row to act on"),
                  selectedSessionId: null,
                  disconnectedBuilder: disconnectedBuilder,
                  emptyState: const Text("Nothing here"),
                  header: null,
                  endClearance: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // A running row's loader never settles.
    await tester.pump();
    return cubit;
  }

  testWidgets("a project that failed to load gets a retry row instead of the empty state", (tester) async {
    final cubit = await pumpList(
      tester,
      initial: state(
        query: "",
        failures: const [AllSessionsFailure(project: project, reason: RemoteFailureReason.networkDown)],
        rows: const [],
        scratchProjectId: null,
      ),
    );
    expect(find.text("Couldn’t load Project One"), findsOneWidget);
    expect(find.text("Nothing here"), findsNothing);
    await tester.tap(find.text("Retry"));
    verify(() => cubit.retry(projectId: "p1")).called(1);
  });

  testWidgets("a query that matches nothing says so instead of the empty state", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "zzz", failures: const [], rows: const [], scratchProjectId: null),
    );
    expect(find.text("Nothing here"), findsNothing);
    expect(find.text("No matches"), findsOneWidget);
  });

  testWidgets("archived rows sit under their archive date, as the archived mode sorts", (tester) async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    await pumpList(
      tester,
      initial: state(
        query: "",
        failures: const [],
        rows: [
          row(title: "Archived today", archivedAt: today, updatedAt: yesterday, isRunning: false),
          // Still running, but an archive lists it by its archive date.
          row(title: "Archived yesterday", archivedAt: yesterday, updatedAt: today, isRunning: true),
        ],
        scratchProjectId: null,
      ),
    );

    double topOf(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text("Today"), findsOneWidget);
    expect(find.text("Yesterday"), findsOneWidget);
    expect(topOf("Today"), lessThan(topOf("Archived today")));
    expect(topOf("Archived today"), lessThan(topOf("Yesterday")));
    expect(topOf("Yesterday"), lessThan(topOf("Archived yesterday")));
    // Archived has no status chips.
    expect(find.byKey(const Key("session-list-filter-all")), findsNothing);
  });

  testWidgets("with nothing to show the empty state fills the list", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "", failures: const [], rows: const [], scratchProjectId: null),
    );
    expect(find.text("Nothing here"), findsOneWidget);
  });

  testWidgets("Archived shows a failed project list with Retry, not the empty state", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "", failures: const [], rows: const [], scratchProjectId: null),
      projectList: const ProjectListState.failed(reason: RemoteFailureReason.networkDown),
    );
    expect(find.text("Failed to load projects"), findsOneWidget);
    expect(find.text("Nothing here"), findsNothing);

    await tester.tap(find.text("Retry"));
    verify(() => projects.retryLoadProjects()).called(1);
  });

  for (final mode in AllSessionsMode.values) {
    testWidgets("${mode.name} shows the disconnected computer, not the empty state", (tester) async {
      await pumpList(
        tester,
        mode: mode,
        initial: state(query: "", failures: const [], rows: const [], scratchProjectId: null),
        projectList: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text("Computer offline"), findsOneWidget);
      expect(find.text("Nothing here"), findsNothing);
      expect(find.byType(PregoSkeletonList), findsNothing);
    });
  }

  testWidgets("the active list adds the status chips over its rows", (tester) async {
    final now = DateTime.now();
    await pumpList(
      tester,
      mode: AllSessionsMode.active,
      initial: state(
        query: "",
        failures: const [],
        rows: [row(title: "Fix the parser", updatedAt: now, archivedAt: null, isRunning: false)],
        scratchProjectId: null,
        counts: const SessionListChipCounts(all: 1, running: 0, unread: 0),
      ),
    );
    expect(find.text("All · 1"), findsOneWidget);
    expect(find.byKey(const Key("session-list-filter-running")), findsOneWidget);
    expect(find.text("Fix the parser"), findsOneWidget);
    // Unfiltered, a row names its project.
    expect(find.text("Project One"), findsOneWidget);
  });

  testWidgets("unfiltered, a No project row names no project", (tester) async {
    const scratch = ProjectSummary(id: "scratch", name: null, path: "/scratch", time: null, kind: ProjectKind.scratch);
    final now = DateTime.now();
    await pumpList(
      tester,
      mode: AllSessionsMode.active,
      initial: state(
        query: "",
        failures: const [],
        rows: [
          row(title: "Fix the parser", updatedAt: now, archivedAt: null, isRunning: false),
          AllSessionsRow(
            session: testSession(id: "jot", title: "Jot down ideas", updatedAt: now.millisecondsSinceEpoch),
            project: scratch,
            isRunning: false,
            isUnseen: false,
            isAwaitingInput: false,
            isRetrying: false,
            backgroundTaskCount: 0,
          ),
        ],
        scratchProjectId: scratch.id,
      ),
      projectList: const ProjectListState.loaded(
        projects: [project, scratch],
        folderProjects: [project],
        scratchProject: scratch,
      ),
    );
    expect(find.text("Jot down ideas"), findsOneWidget);
    expect(find.text("Project One"), findsOneWidget);
    expect(find.text("No project"), findsNothing);
  });

  group("the hand-off from the loading skeleton", () {
    final now = DateTime.now();
    final loading = state(query: "", failures: const [], rows: const [], scratchProjectId: null, isLoading: true);
    final empty = state(query: "", failures: const [], rows: const [], scratchProjectId: null);
    const failure = AllSessionsFailure(
      project: ProjectSummary(id: "p2", name: "Project Two", path: "/p2", time: null),
      reason: RemoteFailureReason.networkDown,
    );
    final failureRow = find.text("Couldn’t load Project Two");
    AllSessionsState loaded({
      required AllSessionsMode mode,
      required List<String> titles,
      String query = "",
      List<AllSessionsFailure> failures = const [],
    }) => state(
      query: query,
      failures: failures,
      rows: [
        for (final title in titles)
          row(
            title: title,
            updatedAt: now,
            archivedAt: mode == AllSessionsMode.archived ? now : null,
            isRunning: false,
          ),
      ],
      scratchProjectId: null,
      counts: SessionListChipCounts(all: titles.length, running: 0, unread: 0),
    );

    double opacityAbove(WidgetTester tester, Finder finder) => tester
        .widget<FadeTransition>(find.ancestor(of: finder, matching: find.byType(FadeTransition)).first)
        .opacity
        .value;
    double rowsOpacity(WidgetTester tester) => tester
        .widget<SliverFadeTransition>(
          find.ancestor(of: find.text("Fix the parser"), matching: find.byType(SliverFadeTransition)),
        )
        .opacity
        .value;

    /// The opacity [finder] paints at, through every fade above it.
    double paintedOpacity(WidgetTester tester, Finder finder) => tester
        .widgetList(
          find.ancestor(
            of: finder,
            matching: find.byWidgetPredicate((w) => w is FadeTransition || w is SliverFadeTransition || w is Opacity),
          ),
        )
        .fold(
          1.0,
          (painted, widget) =>
              painted *
              switch (widget) {
                FadeTransition(:final opacity) || SliverFadeTransition(:final opacity) => opacity.value,
                Opacity(:final opacity) => opacity,
                _ => 1.0,
              },
        );
    final skeleton = find.byType(PregoSkeletonList);
    double skeletonOpacity(WidgetTester tester) =>
        skeleton.evaluate().isEmpty ? 0 : paintedOpacity(tester, find.byType(PregoSkeletonListTile).first);

    /// Pumps a loading list until its skeleton has appeared, and returns
    /// where the skeleton stands.
    Future<double> pumpLoading(
      WidgetTester tester, {
      required Stream<AllSessionsState> updates,
      AllSessionsMode mode = AllSessionsMode.archived,
    }) async {
      await pumpList(tester, initial: loading, updates: updates, mode: mode);
      // Its 300 ms appearance delay, then its 200 ms fade in, timed from the
      // frame after the delay.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(skeletonOpacity(tester), 1);
      expect(find.byType(TextField), findsNothing);
      return tester.getTopLeft(skeleton).dy;
    }

    for (final mode in AllSessionsMode.values) {
      testWidgets("the first rows fade in where the skeleton stood as it fades out over them (${mode.name})", (
        tester,
      ) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        final skeletonTop = await pumpLoading(tester, updates: updates.stream, mode: mode);

        updates.add(loaded(mode: mode, titles: ["Fix the parser"]));
        await tester.pump();
        // The fade's clock starts on the frame after the one mounting the rows.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(skeletonOpacity(tester), inExclusiveRange(0, 1));
        expect(rowsOpacity(tester), inExclusiveRange(0, 1));
        expect(opacityAbove(tester, find.byType(TextField)), rowsOpacity(tester));
        if (mode == AllSessionsMode.active) {
          expect(opacityAbove(tester, find.byKey(const Key("session-list-filter-all"))), rowsOpacity(tester));
        }
        expect(tester.getTopLeft(skeleton).dy, skeletonTop);

        await tester.pump(const Duration(milliseconds: 150));
        expect(skeleton, findsNothing);
        expect(opacityAbove(tester, find.byType(TextField)), 1);
        expect(rowsOpacity(tester), 1);
      });
    }

    testWidgets("the empty state fades in where the skeleton stood as it fades out over it", (tester) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      final skeletonTop = await pumpLoading(tester, updates: updates.stream);

      updates.add(empty);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(skeletonOpacity(tester), inExclusiveRange(0, 1));
      expect(opacityAbove(tester, find.text("Nothing here")), inExclusiveRange(0, 1));
      expect(tester.getTopLeft(find.byType(PregoSkeletonList)).dy, skeletonTop);
      expect(tester.getTopLeft(find.text("Nothing here")).dy, skeletonTop);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(PregoSkeletonList), findsNothing);
      expect(opacityAbove(tester, find.text("Nothing here")), 1);
    });

    final failurePadding = find.ancestor(of: failureRow, matching: find.byType(Padding)).first;

    for (final withRows in [true, false]) {
      testWidgets(
        "a project that fails during the load fades in by itself, over the skeleton it stays above "
        "(${withRows ? "with rows" : "alone"})",
        (tester) async {
          final updates = StreamController<AllSessionsState>();
          addTearDown(updates.close);
          await pumpLoading(tester, updates: updates.stream);

          // Another project is still loading.
          updates.add(
            state(query: "", failures: const [failure], rows: const [], scratchProjectId: null, isLoading: true),
          );
          await tester.pump();
          expect(paintedOpacity(tester, failureRow), 0);
          await tester.pump(const Duration(milliseconds: 100));
          expect(paintedOpacity(tester, failureRow), inExclusiveRange(0, 1));
          expect(skeletonOpacity(tester), 1);
          await tester.pump(const Duration(milliseconds: 150));
          expect(paintedOpacity(tester, failureRow), 1);
          final skeletonTop = tester.getTopLeft(skeleton).dy;
          expect(skeletonTop, tester.getRect(failurePadding).bottom);

          updates.add(
            loaded(mode: AllSessionsMode.archived, titles: [if (withRows) "Fix the parser"], failures: const [failure]),
          );
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // It fades out where it stood, under the failed project.
          expect(skeletonOpacity(tester), inExclusiveRange(0, 1));
          expect(tester.getTopLeft(skeleton).dy, tester.getRect(failurePadding).bottom);
          // Alone, nothing arrives above it to push it down.
          if (!withRows) expect(tester.getTopLeft(skeleton).dy, skeletonTop);
          expect(paintedOpacity(tester, failureRow), 1);
          if (withRows) expect(rowsOpacity(tester), inExclusiveRange(0, 1));

          await tester.pump(const Duration(milliseconds: 150));
          expect(skeleton, findsNothing);
          expect(paintedOpacity(tester, failureRow), 1);
        },
      );

      testWidgets(
        "a project that fails as the load ends fades in with the first content (${withRows ? "with rows" : "alone"})",
        (tester) async {
          final updates = StreamController<AllSessionsState>();
          addTearDown(updates.close);
          final skeletonTop = await pumpLoading(tester, updates: updates.stream);

          updates.add(
            loaded(mode: AllSessionsMode.archived, titles: [if (withRows) "Fix the parser"], failures: const [failure]),
          );
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(paintedOpacity(tester, failureRow), inExclusiveRange(0, 1));
          if (withRows) expect(paintedOpacity(tester, failureRow), moreOrLessEquals(rowsOpacity(tester)));
          // It fades out where it stood, over the search field or, alone, over the failed project.
          expect(skeletonOpacity(tester), inExclusiveRange(0, 1));
          expect(tester.getTopLeft(skeleton).dy, skeletonTop);

          await tester.pump(const Duration(milliseconds: 150));
          expect(skeleton, findsNothing);
          expect(paintedOpacity(tester, failureRow), 1);
        },
      );
    }

    for (final endsAfter in [250, 320, 600]) {
      testWidgets("a load that ends ${endsAfter}ms in fades the skeleton out from there, never brightening", (
        tester,
      ) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        await pumpList(tester, initial: loading, updates: updates.stream);
        // Its 300 ms appearance delay, then its 200 ms fade in, timed from the
        // frame after the delay.
        await tester.pump(Duration(milliseconds: endsAfter < 300 ? endsAfter : 300));
        if (endsAfter > 300) await tester.pump(Duration(milliseconds: endsAfter - 300));
        final start = skeletonOpacity(tester);
        expect(start, switch (endsAfter) {
          250 => 0,
          320 => inExclusiveRange(0, 1),
          _ => 1,
        });

        updates.add(loaded(mode: AllSessionsMode.archived, titles: ["Fix the parser"]));
        // With nothing animating yet, a bare pump would skip the frame before the update arrives.
        await tester.pump(Duration.zero);
        var last = start;
        // The fade's clock starts on the frame after the one ending the load.
        for (var elapsed = 0; elapsed <= 200; elapsed += 10) {
          await tester.pump(const Duration(milliseconds: 10));
          final opacity = skeletonOpacity(tester);
          expect(opacity, lessThanOrEqualTo(last), reason: "at ${elapsed}ms");
          last = opacity;
        }
        expect(last, 0);

        await tester.pump(const Duration(milliseconds: 10));
        expect(skeleton, findsNothing);
        expect(rowsOpacity(tester), 1);
      });
    }

    testWidgets("the search field arrives with the rows, never over an empty body", (tester) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpLoading(tester, updates: updates.stream);

      updates.add(loaded(mode: AllSessionsMode.archived, titles: ["Fix the parser", "Write the docs"]));
      await tester.pump();
      // The rows are already in place at full size; the field shows with them.
      expect(opacityAbove(tester, find.byType(TextField)), 0);
      expect(rowsOpacity(tester), 0);
      final secondRowTop = tester.getTopLeft(find.text("Write the docs")).dy;
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(opacityAbove(tester, find.byType(TextField)), rowsOpacity(tester));
        expect(tester.getTopLeft(find.text("Write the docs")).dy, secondRowTop, reason: "no row grows in");
      }
      expect(rowsOpacity(tester), 1);
    });

    testWidgets("under reduced motion the hand-off is instant", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpLoading(tester, updates: updates.stream);

      updates.add(loaded(mode: AllSessionsMode.archived, titles: ["Fix the parser"]));
      // With nothing animating, a bare pump would skip the frame before the update arrives.
      await tester.pump(Duration.zero);

      expect(find.byType(PregoSkeletonList), findsNothing);
      expect(opacityAbove(tester, find.byType(TextField)), 1);
      expect(rowsOpacity(tester), 1);
    });

    testWidgets("a later refresh or search does not run a fade again", (tester) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpLoading(tester, updates: updates.stream, mode: AllSessionsMode.active);
      updates.add(
        loaded(mode: AllSessionsMode.active, titles: ["Fix the parser", "Write the docs"], failures: const [failure]),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      for (final update in [
        // A refresh that brings another session.
        loaded(
          mode: AllSessionsMode.active,
          titles: ["Fix the parser", "Write the docs", "Ship it"],
          failures: const [failure],
        ),
        // A search that narrows the list.
        loaded(mode: AllSessionsMode.active, titles: ["Fix the parser"], query: "parser", failures: const [failure]),
      ]) {
        updates.add(update);
        await tester.pump();
        expect(skeleton, findsNothing);
        expect(opacityAbove(tester, find.byType(TextField)), 1);
        expect(rowsOpacity(tester), 1);
        expect(paintedOpacity(tester, failureRow), 1);
      }
    });

    /// Whether the skeleton has begun to fade in.
    bool skeletonShown(WidgetTester tester) => !tester
        .widget<FadeTransition>(find.descendant(of: skeleton, matching: find.byType(FadeTransition)))
        .opacity
        .isDismissed;
    for (final mode in AllSessionsMode.values) {
      for (final throughProjectLoad in [true, false]) {
        testWidgets(
          "a computer about to connect is a load whose one skeleton hands off to the rows "
          "(${mode.name}${throughProjectLoad ? ", through the project load" : ""})",
          (tester) async {
            final projectUpdates = StreamController<ProjectListState>();
            final updates = StreamController<AllSessionsState>();
            addTearDown(projectUpdates.close);
            addTearDown(updates.close);
            // Disconnected, the cubit has nothing to load: only the surface knows.
            await pumpList(
              tester,
              mode: mode,
              initial: empty,
              updates: updates.stream,
              projectList: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true),
              projectUpdates: projectUpdates.stream,
              disconnectedBuilder: _aboutToConnect,
            );
            final first = tester.element(skeleton);
            expect(find.text("Nothing here"), findsNothing);
            await tester.pump(const Duration(milliseconds: 200));
            expect(skeletonShown(tester), isFalse);

            if (throughProjectLoad) {
              projectUpdates.add(const ProjectListState.loading());
              updates.add(loading);
              await tester.pump();
              expect(tester.element(skeleton), same(first));
            }
            // Its appearance delay runs on from the start rather than again.
            await tester.pump(const Duration(milliseconds: 150));
            expect(skeletonShown(tester), isTrue);
            await tester.pump(const Duration(milliseconds: 250));

            projectUpdates.add(
              const ProjectListState.loaded(projects: [project], folderProjects: [project], scratchProject: null),
            );
            updates.add(loaded(mode: mode, titles: ["Fix the parser"]));
            await tester.pump();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.element(skeleton), same(first));
            expect(skeletonOpacity(tester), inExclusiveRange(0, 1));
            expect(rowsOpacity(tester), inExclusiveRange(0, 1));

            await tester.pump(const Duration(milliseconds: 150));
            expect(skeleton, findsNothing);
            expect(rowsOpacity(tester), 1);
          },
        );
      }
    }
  });
}

Widget _offlinePage({required BuildContext context, required ProjectListBridgeDisconnected state}) =>
    const SliverToBoxAdapter(child: Text("Computer offline"));

/// A surface that knows the computer is about to connect.
Widget? _aboutToConnect({required BuildContext context, required ProjectListBridgeDisconnected state}) => null;
