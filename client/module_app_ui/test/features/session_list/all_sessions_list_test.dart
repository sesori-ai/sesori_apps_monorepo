import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_list/session_list_headings.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockAllSessionsCubit() extends MockCubit<AllSessionsState> implements AllSessionsCubit;

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

class _MockSessionWindowService() extends Mock implements SessionWindowService;

void main() {
  const project = ProjectSummary(id: "p1", name: "Project One", path: "/p1", time: null);

  AllSessionsState state({
    required String query,
    required RemoteFailureReason? failure,
    SessionWindowLoadMore? loadMore,
    bool awaitingAnswer = false,
    required List<AllSessionsRow> rows,
    required String? scratchProjectId,
    SessionListChipCounts counts = const SessionListChipCounts(all: 0, running: 0, unread: 0),
    bool isLoading = false,
    SessionListQuickFilter quickFilter = SessionListQuickFilter.all,
  }) => AllSessionsState(
    projectId: null,
    query: query,
    quickFilter: quickFilter,
    rows: rows,
    counts: counts,
    loadMore: loadMore,
    awaitingAnswer: awaitingAnswer,
    failure: failure,
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
    Widget? header,
    TextDirection textDirection = TextDirection.ltr,
    PregoInteractionMode interaction = PregoInteractionMode.touch,
    // The launches the list's launching rows come from.
    SessionLaunchRepository? launches,
  }) async {
    final cubit = _MockAllSessionsCubit();
    whenListen(cubit, updates, initialState: initial);
    when(() => cubit.mode).thenReturn(mode);
    when(cubit.retry).thenAnswer((_) async {});
    when(cubit.loadMore).thenAnswer((_) async {});
    when(() => cubit.setHiddenSessionIds(sessionIds: any(named: "sessionIds"))).thenReturn(null);
    projects = _MockProjectListCubit();
    whenListen(projects, projectUpdates, initialState: projectList);
    when(() => projects.retryLoadProjects()).thenAnswer((_) async {});
    final window = _MockSessionWindowService();
    when(() => window.state).thenAnswer(
      (_) => BehaviorSubject.seeded(
        const SessionWindowLoaded(
          sessions: [],
          counts: SessionPageCounts(all: 0, running: 0, unread: 0),
          nextCursor: null,
          loadMore: SessionWindowLoadMore.idle,
          awaitingAnswer: false,
        ),
      ),
    );
    when(() => window.key).thenReturn((projectId: null, query: null, filter: SessionListQuickFilter.all));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: textDirection,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AllSessionsCubit>.value(value: cubit),
              BlocProvider<ProjectListCubit>.value(value: projects),
              BlocProvider(
                create: (_) => PendingSessionArchiveCubit(
                  cleanupService: SessionCleanupService(repository: MockSessionRepository()),
                ),
              ),
              RepositoryProvider<SessionWindowService>.value(value: window),
              RepositoryProvider(
                create: (_) => switch (launches) {
                  final launches? => inMemorySessionLaunchService(launchRepository: launches),
                  null => idleSessionLaunchService(),
                },
              ),
            ],
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  PregoInteractionScope(
                    mode: interaction,
                    child: AllSessionsList(
                      onSessionTap: ({required row}) {},
                      actionDispatcher: const SessionListActionDispatcher(
                        deleteConfirmation: SessionDeleteConfirmation.sheet,
                        onSessionArchived: null,
                        onSessionDeleted: null,
                        onSessionMarkedUnread: null,
                      ),
                      createActionCubit: ({required projectId, required session}) =>
                          throw StateError("no row to act on"),
                      selectedSessionId: null,
                      disconnectedBuilder: disconnectedBuilder,
                      emptyState: const Text("Nothing here"),
                      header: header,
                      endClearance: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // A running row's loader never settles.
    await tester.pump();
    return cubit;
  }

  /// The opacity [finder] paints at, through every fade above it.
  double paintedOpacity(WidgetTester tester, Finder finder) => tester
      .widgetList(
        find.ancestor(
          of: finder,
          matching: find.byWidgetPredicate(
            (w) => w is FadeTransition || w is SliverFadeTransition || w is Opacity,
            skipOffstage: false,
          ),
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

  /// The opacity [finder] paints at, or null while it is gone.
  double? shownOpacity(WidgetTester tester, Finder finder) =>
      finder.evaluate().isEmpty ? null : paintedOpacity(tester, finder);

  final runningChip = find.byKey(const Key("session-list-filter-running"));

  /// Whether [chip] shows as the selected filter.
  bool? selected(WidgetTester tester, Finder chip) =>
      tester.widget<Semantics>(find.ancestor(of: chip, matching: find.byType(Semantics)).first).properties.toggled;

  const header = SizedBox(key: Key("header"), height: 36, child: Text("All projects"));
  final headerBox = find.byKey(const Key("header"));

  /// How far anything may move in one 5 ms frame: smooth motion stays well
  /// under it, a one-frame snap of a box's height does not.
  const maxStep = 6.0;

  /// The tops of [finders], each null while it is gone, on the frame before
  /// [update] lands and on every 5 ms frame of the 500 ms after.
  Future<List<List<double?>>> topsAcross(
    WidgetTester tester, {
    required StreamController<AllSessionsState> updates,
    required AllSessionsState update,
    required List<Finder> finders,
  }) async {
    List<double?> tops() => [
      for (final finder in finders) finder.evaluate().isEmpty ? null : tester.getTopLeft(finder).dy,
    ];
    final frames = [tops()];
    updates.add(update);
    for (var elapsed = 0; elapsed < 500; elapsed += 5) {
      await tester.pump(const Duration(milliseconds: 5));
      frames.add(tops());
    }
    return [
      for (var index = 0; index < finders.length; index++) [for (final frame in frames) frame[index]],
    ];
  }

  /// Each one-frame change in [readings], such as a box's top, across the
  /// frames it was shown.
  List<double> steps(List<double?> readings) => [
    for (var frame = 1; frame < readings.length; frame++)
      if ((readings[frame - 1], readings[frame]) case (final from?, final to?)) to - from,
  ];

  /// What [read] sees on the frame [update] lands, and 100, 200 and 300 ms
  /// after it.
  Future<List<T>> framesAcross<T>(
    WidgetTester tester, {
    required StreamController<AllSessionsState> updates,
    required AllSessionsState update,
    required T Function() read,
  }) async {
    updates.add(update);
    // With nothing animating, a bare pump would skip the frame before the update arrives.
    await tester.pump(Duration.zero);
    final frames = [read()];
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      frames.add(read());
    }
    return frames;
  }

  /// What [read] sees on the frame [update] lands and on every 10 ms frame of
  /// the 500 ms after, at rest again by then.
  Future<List<T>> everyFrameAcross<T>(
    WidgetTester tester, {
    required StreamController<AllSessionsState> updates,
    required AllSessionsState update,
    required T Function() read,
  }) async {
    updates.add(update);
    await tester.pump(Duration.zero);
    final frames = [read()];
    for (var elapsed = 0; elapsed < 500; elapsed += 10) {
      await tester.pump(const Duration(milliseconds: 10));
      frames.add(read());
    }
    return frames;
  }

  /// The top of [finder], or null while it is gone.
  double? topOf(WidgetTester tester, Finder finder) => finder.evaluate().isEmpty ? null : tester.getTopLeft(finder).dy;

  testWidgets("a project that failed to load gets a retry row instead of the empty state", (tester) async {
    final cubit = await pumpList(
      tester,
      initial: state(
        query: "",
        failure: RemoteFailureReason.networkDown,
        rows: const [],
        scratchProjectId: null,
      ),
    );
    expect(find.text("Couldn’t load sessions"), findsOneWidget);
    expect(find.text("Nothing here"), findsNothing);
    await tester.tap(find.text("Retry"));
    verify(cubit.retry).called(1);
  });

  testWidgets("a query that matches nothing says so instead of the empty state", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "zzz", failure: null, rows: const [], scratchProjectId: null),
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
        failure: null,
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

  for (final textDirection in TextDirection.values) {
    testWidgets("a date heading starts at the list's start inset, as its rows do (${textDirection.name})", (
      tester,
    ) async {
      final today = DateTime.now();
      await pumpList(
        tester,
        textDirection: textDirection,
        initial: state(
          query: "",
          failure: null,
          rows: [row(title: "Archived today", archivedAt: today, updatedAt: today, isRunning: false)],
          scratchProjectId: null,
        ),
      );
      final heading = tester.getRect(find.text("Today"));
      switch (textDirection) {
        case TextDirection.ltr:
          expect(heading.left, 16);
        case TextDirection.rtl:
          expect(heading.right, 800 - 16);
      }
    });
  }

  testWidgets("with nothing to show the empty state fills the list", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "", failure: null, rows: const [], scratchProjectId: null),
    );
    expect(find.text("Nothing here"), findsOneWidget);
  });

  testWidgets("Archived shows a failed project list with Retry, not the empty state", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "", failure: null, rows: const [], scratchProjectId: null),
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
        initial: state(query: "", failure: null, rows: const [], scratchProjectId: null),
        projectList: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text("Computer offline"), findsOneWidget);
      expect(find.text("Nothing here"), findsNothing);
      expect(find.byType(SessionListSkeleton), findsNothing);
    });
  }

  testWidgets("the active list adds the status chips over its rows", (tester) async {
    final now = DateTime.now();
    await pumpList(
      tester,
      mode: AllSessionsMode.active,
      initial: state(
        query: "",
        failure: null,
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
        failure: null,
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

  group("a change at rest", () {
    final now = DateTime.now();
    const failure = RemoteFailureReason.networkDown;
    final failureRow = find.text("Couldn’t load sessions");
    final sessionRow = find.text("Fix the parser");
    AllSessionsState listing({
      required bool withSession,
      required RemoteFailureReason? failure,
      bool isLoading = false,
    }) => state(
      query: "",
      failure: failure,
      rows: [if (withSession) row(title: "Fix the parser", updatedAt: now, archivedAt: null, isRunning: false)],
      scratchProjectId: null,
      counts: SessionListChipCounts(all: withSession ? 1 : 0, running: 0, unread: 0),
      isLoading: isLoading,
    );

    testWidgets("a last session that leaves folds the search field and chips away as the empty state fades in, "
        "and they open again as it returns", (tester) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(
        tester,
        initial: listing(withSession: true, failure: null),
        updates: updates.stream,
        mode: AllSessionsMode.active,
        header: header,
      );
      final headerTop = tester.getTopLeft(headerBox).dy;
      // Under the search field.
      expect(headerTop, greaterThan(20));
      final emptyState = find.text("Nothing here");

      // Archived, as its Undo window opens.
      updates.add(listing(withSession: false, failure: null));
      final headerTops = <double>[headerTop];
      final emptyOpacities = <double>[];
      final shownEmptyTops = <double>[];
      for (var elapsed = 0; elapsed < 500; elapsed += 5) {
        await tester.pump(const Duration(milliseconds: 5));
        headerTops.add(tester.getTopLeft(headerBox).dy);
        if (emptyState.evaluate().isEmpty) continue;
        emptyOpacities.add(paintedOpacity(tester, emptyState));
        // Only seen once the room above it has folded away.
        if (emptyOpacities.last > 0) shownEmptyTops.add(tester.getTopLeft(emptyState).dy);
      }
      expect(steps(headerTops), everyElement(inInclusiveRange(-maxStep, 0)));
      expect(headerTops.last, 0);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key("session-list-filter-all")), findsNothing);
      expect(emptyOpacities.first, 0);
      expect(emptyOpacities.last, 1);
      expect(shownEmptyTops.toSet(), {tester.getBottomLeft(headerBox).dy});

      // Its Undo.
      final [returningTops] = await topsAcross(
        tester,
        updates: updates,
        update: listing(withSession: true, failure: null),
        finders: [headerBox],
      );
      expect(steps(returningTops), everyElement(inInclusiveRange(0, maxStep)));
      expect(returningTops.last, headerTop);
    });

    testWidgets("a project that fails opens its Retry row, easing the rows below down", (tester) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(
        tester,
        initial: listing(withSession: true, failure: null),
        updates: updates.stream,
        mode: AllSessionsMode.active,
      );
      final rowTop = tester.getTopLeft(sessionRow).dy;

      final [rowTops] = await topsAcross(
        tester,
        updates: updates,
        update: listing(withSession: true, failure: failure),
        finders: [sessionRow],
      );
      expect(steps(rowTops), everyElement(inInclusiveRange(0, maxStep)));
      expect(rowTops.last, greaterThan(rowTop + 20));
      expect(paintedOpacity(tester, failureRow), 1);
    });

    testWidgets("a Retry row whose project loads again folds away, easing the rows below up", (tester) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(
        tester,
        initial: listing(withSession: true, failure: failure),
        updates: updates.stream,
        mode: AllSessionsMode.active,
      );
      // It fades in as it first shows.
      await tester.pump(const Duration(milliseconds: 300));
      final rowTop = tester.getTopLeft(sessionRow).dy;

      final [rowTops] = await topsAcross(
        tester,
        updates: updates,
        update: listing(withSession: true, failure: null, isLoading: true),
        finders: [sessionRow],
      );
      expect(steps(rowTops), everyElement(inInclusiveRange(-maxStep, 0)));
      expect(rowTops.last, lessThan(rowTop - 20));
      expect(failureRow, findsNothing);
    });

    // Found while they open from nothing, which takes no room on screen.
    for (final (name, update, opening) in [
      (
        "a session that returns",
        listing(withSession: true, failure: null),
        find.byType(TextField, skipOffstage: false),
      ),
      (
        "a project that fails",
        listing(withSession: false, failure: failure),
        find.text("Couldn’t load sessions", skipOffstage: false),
      ),
    ]) {
      testWidgets("$name fades the empty state out where it stands, then opens what takes its place", (
        tester,
      ) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        // As on a first launch, or before an archive's Undo.
        await pumpList(
          tester,
          initial: listing(withSession: false, failure: null),
          updates: updates.stream,
          mode: AllSessionsMode.active,
          header: header,
        );
        final emptyState = find.text("Nothing here");
        final emptyTop = tester.getTopLeft(emptyState).dy;
        expect(paintedOpacity(tester, emptyState), 1);

        final frames = await everyFrameAcross(
          tester,
          updates: updates,
          update: update,
          read: () => (
            empty: shownOpacity(tester, emptyState),
            top: topOf(tester, emptyState),
            opening: shownOpacity(tester, opening),
            header: tester.getTopLeft(headerBox).dy,
          ),
        );
        final shown = frames.where((frame) => frame.empty != null).toList();
        expect(shown.first.empty, 1);
        expect(steps([for (final frame in shown) frame.empty]), everyElement(lessThanOrEqualTo(0)));
        // Nothing moves under it, as what takes its place waits for it to go.
        for (final frame in shown) {
          expect((frame.top, frame.opening ?? 0, frame.header), (emptyTop, 0, 0));
        }
        expect(frames[25].empty, isNull);
        expect(frames.last.opening, 1);
      });
    }

    for (final (name, update, note) in [
      ("A search", state(query: "zzz", failure: null, rows: const [], scratchProjectId: null), "No matches"),
      (
        "A filter",
        state(
          query: "",
          failure: null,
          rows: const [],
          scratchProjectId: null,
          counts: const SessionListChipCounts(all: 1, running: 0, unread: 0),
          quickFilter: SessionListQuickFilter.running,
        ),
        "No sessions match this filter",
      ),
    ]) {
      testWidgets("$name that leaves no rows fades its note in once they have gone, and out before they return, "
          "where it stands", (tester) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        await pumpList(
          tester,
          initial: listing(withSession: true, failure: null),
          updates: updates.stream,
          mode: AllSessionsMode.active,
        );
        final searchField = find.byType(TextField);
        final fieldTop = tester.getTopLeft(searchField).dy;
        final chipTop = tester.getTopLeft(runningChip).dy;
        final noteText = find.text(note);
        ({double? note, double? top, bool row, double field, double chips}) read() => (
          note: shownOpacity(tester, noteText),
          top: topOf(tester, noteText),
          row: sessionRow.evaluate().isNotEmpty,
          field: tester.getTopLeft(searchField).dy,
          chips: tester.getTopLeft(runningChip).dy,
        );

        final arriving = await everyFrameAcross(tester, updates: updates, update: update, read: read);
        final noteTop = arriving.last.top;
        expect(arriving.first.note, 0);
        expect(steps([for (final frame in arriving) frame.note]), everyElement(greaterThanOrEqualTo(0)));
        expect(arriving.last.note, 1);
        final leaving = await everyFrameAcross(
          tester,
          updates: updates,
          update: listing(withSession: true, failure: null),
          read: read,
        );
        expect(leaving.first.note, 1);
        expect(steps([for (final frame in leaving) frame.note]), everyElement(lessThanOrEqualTo(0)));
        expect(leaving.last.note, isNull);
        expect(leaving.last.row, isTrue);
        for (final frame in [...arriving, ...leaving]) {
          // Seen only where it stands, with no rows above it.
          if ((frame.note ?? 0) > 0) expect((frame.top, frame.row), (noteTop, false));
          expect((frame.field, frame.chips), (fieldTop, chipTop));
        }
      });
    }

    // Running leaves no rows of a project's sessions, as the project switcher
    // moves to a project with none, or back.
    AllSessionsState running({required int sessions}) => state(
      query: "",
      failure: null,
      rows: const [],
      scratchProjectId: null,
      counts: SessionListChipCounts(all: sessions, running: 0, unread: 0),
      quickFilter: SessionListQuickFilter.running,
    );
    final filterNote = find.text("No sessions match this filter");
    final nothingHere = find.text("Nothing here");
    for (final (name, from, to, leaving, arriving) in [
      ("The note", running(sessions: 1), running(sessions: 0), filterNote, nothingHere),
      ("The empty state", running(sessions: 0), running(sessions: 1), nothingHere, filterNote),
    ]) {
      testWidgets("$name fades out where it stands before what replaces it fades in, which then holds still", (
        tester,
      ) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        await pumpList(tester, initial: from, updates: updates.stream, mode: AllSessionsMode.active, header: header);
        final leavingTop = tester.getTopLeft(leaving).dy;
        expect(paintedOpacity(tester, leaving), 1);

        final frames = await everyFrameAcross(
          tester,
          updates: updates,
          update: to,
          read: () => (
            leaving: shownOpacity(tester, leaving),
            leavingTop: topOf(tester, leaving),
            arriving: shownOpacity(tester, arriving),
            arrivingTop: topOf(tester, arriving),
          ),
        );
        expect(steps([for (final frame in frames) frame.leaving]), everyElement(lessThanOrEqualTo(0)));
        expect(frames.last.leaving, isNull);
        // The search field and chips fold or open meanwhile, so what arrives
        // is seen only where it then stands.
        final seen = frames.where((frame) => (frame.arriving ?? 0) > 0).toList();
        expect(seen, isNotEmpty);
        for (final frame in frames) {
          if (frame.leaving != null) expect((frame.leavingTop, frame.arriving ?? 0), (leavingTop, 0));
        }
        expect(seen.map((frame) => frame.arrivingTop).toSet(), {frames.last.arrivingTop});
        expect(steps([for (final frame in seen) frame.arriving]), everyElement(greaterThanOrEqualTo(0)));
        await tester.pump(const Duration(milliseconds: 200));
        expect(paintedOpacity(tester, arriving), 1);
      });
    }

    testWidgets("a note whose text changes cross-fades where it stands, easing the room the new one wraps to", (
      tester,
    ) async {
      // Narrow enough for the filter's note to wrap where "No matches" does not.
      tester.view.physicalSize = const Size(393, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // A query that matches nothing on a Running list with no rows, cleared.
      AllSessionsState running({required String query, required int sessions}) => state(
        query: query,
        failure: null,
        rows: const [],
        scratchProjectId: null,
        counts: SessionListChipCounts(all: sessions, running: 0, unread: 0),
        quickFilter: SessionListQuickFilter.running,
      );
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(
        tester,
        initial: running(query: "zzz", sessions: 0),
        updates: updates.stream,
        mode: AllSessionsMode.active,
        header: header,
      );
      final noMatches = find.text("No matches");
      final filterNote = find.text("No sessions match this filter");
      final noteTop = tester.getTopLeft(noMatches).dy;
      // The room the note holds, whichever text it shows.
      double room() => tester
          .getSize(
            find
                .ancestor(
                  of: noMatches.evaluate().isEmpty ? filterNote : noMatches,
                  matching: find.byWidgetPredicate(
                    (widget) => widget is Padding && widget.padding == const EdgeInsets.all(PregoSpacing.x3l),
                  ),
                )
                .first,
          )
          .height;
      final oneLine = room();

      final frames = await everyFrameAcross(
        tester,
        updates: updates,
        update: running(query: "", sessions: 1),
        read: () => (
          leaving: shownOpacity(tester, noMatches),
          leavingTop: topOf(tester, noMatches),
          arriving: shownOpacity(tester, filterNote),
          arrivingTop: topOf(tester, filterNote),
          room: room(),
        ),
      );
      // Both show as one fades into the other.
      expect([frames[1].leaving, frames[1].arriving], everyElement(inExclusiveRange(0, 1)));
      expect(steps([for (final frame in frames) frame.leaving]), everyElement(lessThanOrEqualTo(0)));
      expect(steps([for (final frame in frames) frame.arriving]), everyElement(greaterThanOrEqualTo(0)));
      expect((frames.last.leaving, frames.last.arriving), (null, 1));
      expect(
        {
          for (final frame in frames) ...[frame.leavingTop, frame.arrivingTop],
        }..remove(null),
        {noteTop},
      );
      final rooms = [for (final frame in frames) frame.room];
      expect(steps(rooms), everyElement(inInclusiveRange(0, maxStep)));
      expect(rooms.last, greaterThan(oneLine));
    });

    testWidgets("under reduced motion the empty state, a note and a filter tapped while loading swap at once", (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(
        tester,
        initial: listing(withSession: false, failure: null),
        updates: updates.stream,
        mode: AllSessionsMode.active,
      );
      final emptyState = find.text("Nothing here");
      final noMatches = find.text("No matches");
      expect(paintedOpacity(tester, emptyState), 1);

      updates.add(listing(withSession: true, failure: null));
      await tester.pump(Duration.zero);
      expect(emptyState, findsNothing);
      expect(paintedOpacity(tester, find.byType(TextField)), 1);

      updates.add(state(query: "zzz", failure: null, rows: const [], scratchProjectId: null));
      await tester.pump(Duration.zero);
      expect(paintedOpacity(tester, noMatches), 1);

      updates.add(listing(withSession: true, failure: null, isLoading: true));
      await tester.pump(Duration.zero);
      expect(noMatches, findsNothing);

      // Running leaves no rows while another project still loads.
      updates.add(
        state(
          query: "",
          failure: null,
          rows: const [],
          scratchProjectId: null,
          counts: const SessionListChipCounts(all: 1, running: 0, unread: 0),
          quickFilter: SessionListQuickFilter.running,
          isLoading: true,
        ),
      );
      await tester.pump(Duration.zero);
      expect(selected(tester, runningChip), isTrue);
      expect(paintedOpacity(tester, runningChip), 1);
      expect(sessionRow, findsNothing);
      expect(find.byType(SessionListSkeleton), findsOneWidget);
    });

    testWidgets("under reduced motion each change shows at once", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(
        tester,
        initial: listing(withSession: true, failure: null),
        updates: updates.stream,
        mode: AllSessionsMode.active,
      );
      final rowTop = tester.getTopLeft(sessionRow).dy;

      updates.add(listing(withSession: true, failure: failure));
      await tester.pump(Duration.zero);
      expect(paintedOpacity(tester, failureRow), 1);
      final failedRowTop = tester.getTopLeft(sessionRow).dy;
      expect(failedRowTop, greaterThan(rowTop + 20));

      updates.add(listing(withSession: false, failure: null));
      await tester.pump(Duration.zero);
      expect(failureRow, findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(paintedOpacity(tester, find.text("Nothing here")), 1);

      updates.add(listing(withSession: true, failure: failure));
      await tester.pump(Duration.zero);
      expect(paintedOpacity(tester, find.byType(TextField)), 1);
      expect(tester.getTopLeft(sessionRow).dy, failedRowTop);
    });
  });

  group("the hand-off from the loading skeleton", () {
    final now = DateTime.now();
    final loading = state(query: "", failure: null, rows: const [], scratchProjectId: null, isLoading: true);
    final empty = state(query: "", failure: null, rows: const [], scratchProjectId: null);
    const failure = RemoteFailureReason.networkDown;
    // Found while it opens from nothing, which takes no room on screen.
    final failureRow = find.text("Couldn’t load sessions", skipOffstage: false);
    AllSessionsState loaded({
      required AllSessionsMode mode,
      required List<String> titles,
      String query = "",
      RemoteFailureReason? failure,
      SessionListChipCounts? counts,
    }) => state(
      query: query,
      failure: failure,
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
      counts: counts ?? SessionListChipCounts(all: titles.length, running: 0, unread: 0),
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
    final skeleton = find.byType(SessionListSkeleton);
    double skeletonOpacity(WidgetTester tester) =>
        skeleton.evaluate().isEmpty ? 0 : paintedOpacity(tester, find.byType(SessionTileSkeleton).first);
    final searchField = find.byType(TextField);

    /// Pumps a loading list until its skeleton has appeared, and returns
    /// where the skeleton stands.
    Future<double> pumpLoading(
      WidgetTester tester, {
      required Stream<AllSessionsState> updates,
      AllSessionsMode mode = AllSessionsMode.archived,
      Widget? header,
      PregoInteractionMode interaction = PregoInteractionMode.touch,
    }) async {
      await pumpList(tester, initial: loading, updates: updates, mode: mode, header: header, interaction: interaction);
      // Its 300 ms appearance delay, then its 200 ms fade in, timed from the
      // frame after the delay.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(skeletonOpacity(tester), 1);
      expect(paintedOpacity(tester, searchField), 1);
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
        // Shown through the load, the field does not fade in again.
        expect(paintedOpacity(tester, searchField), 1);
        if (mode == AllSessionsMode.active) {
          expect(opacityAbove(tester, find.byKey(const Key("session-list-filter-all"))), rowsOpacity(tester));
        }
        expect(tester.getTopLeft(skeleton).dy, skeletonTop);

        await tester.pump(const Duration(milliseconds: 150));
        expect(skeleton, findsNothing);
        expect(paintedOpacity(tester, searchField), 1);
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
      // Both rise together as the search field, with nothing to search,
      // folds away above them.
      expect(paintedOpacity(tester, searchField), inExclusiveRange(0, 1));
      expect(tester.getTopLeft(skeleton).dy, inExclusiveRange(0, skeletonTop));
      expect(tester.getTopLeft(find.text("Nothing here")).dy, tester.getTopLeft(skeleton).dy);

      await tester.pump(const Duration(milliseconds: 150));
      expect(skeleton, findsNothing);
      expect(searchField, findsNothing);
      expect(opacityAbove(tester, find.text("Nothing here")), 1);
      expect(tester.getTopLeft(find.text("Nothing here")).dy, 0);
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
            state(query: "", failure: failure, rows: const [], scratchProjectId: null, isLoading: true),
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
            loaded(mode: AllSessionsMode.archived, titles: [if (withRows) "Fix the parser"], failure: failure),
          );
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // It fades out where it stood, under the failed project.
          expect(skeletonOpacity(tester), inExclusiveRange(0, 1));
          expect(tester.getTopLeft(skeleton).dy, tester.getRect(failurePadding).bottom);
          // The search field stays, so nothing moves; with nothing to search
          // it folds away, raising both together.
          expect(tester.getTopLeft(skeleton).dy, withRows ? skeletonTop : lessThan(skeletonTop));
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
            loaded(mode: AllSessionsMode.archived, titles: [if (withRows) "Fix the parser"], failure: failure),
          );
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(paintedOpacity(tester, failureRow), inExclusiveRange(0, 1));
          if (withRows) expect(paintedOpacity(tester, failureRow), moreOrLessEquals(rowsOpacity(tester)));
          // It fades out over the failed project, where it stood; alone, the
          // search field folds away, raising both together.
          expect(skeletonOpacity(tester), inExclusiveRange(0, 1));
          expect(tester.getTopLeft(skeleton).dy, tester.getRect(failurePadding).top);
          expect(tester.getTopLeft(skeleton).dy, withRows ? skeletonTop : lessThan(skeletonTop));

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

    testWidgets("the search field takes focus and a query while the list loads, keeping both as the rows arrive", (
      tester,
    ) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      final cubit = await pumpList(tester, initial: loading, updates: updates.stream);
      bool focused() => tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

      await tester.enterText(searchField, "parser");
      expect(focused(), isTrue);
      verify(() => cubit.setQuery(query: "parser")).called(1);

      // The load ends with what matches the query.
      updates.add(loaded(mode: AllSessionsMode.archived, titles: ["Fix the parser"], query: "parser"));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(rowsOpacity(tester), 1);
      expect(focused(), isTrue);
      expect(find.text("parser"), findsOneWidget);
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

      expect(find.byType(SessionListSkeleton), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(paintedOpacity(tester, searchField), 1);
      expect(rowsOpacity(tester), 1);
    });

    testWidgets("a later refresh or search does not run a fade again", (tester) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpLoading(tester, updates: updates.stream, mode: AllSessionsMode.active);
      updates.add(
        loaded(mode: AllSessionsMode.active, titles: ["Fix the parser", "Write the docs"], failure: failure),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      for (final update in [
        // A refresh that brings another session.
        loaded(
          mode: AllSessionsMode.active,
          titles: ["Fix the parser", "Write the docs", "Ship it"],
          failure: failure,
        ),
        // A search that narrows the list.
        loaded(mode: AllSessionsMode.active, titles: ["Fix the parser"], query: "parser", failure: failure),
      ]) {
        updates.add(update);
        await tester.pump();
        expect(skeleton, findsNothing);
        expect(paintedOpacity(tester, searchField), 1);
        expect(rowsOpacity(tester), 1);
        expect(paintedOpacity(tester, failureRow), 1);
      }
    });

    testWidgets("chips that show their counts through a load hold still as it hands off", (tester) async {
      // Running leaves no rows while another project still loads.
      AllSessionsState running({required bool isLoading}) => state(
        query: "",
        failure: null,
        rows: const [],
        scratchProjectId: null,
        counts: const SessionListChipCounts(all: 2, running: 0, unread: 0),
        quickFilter: SessionListQuickFilter.running,
        isLoading: isLoading,
      );
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(tester, initial: running(isLoading: true), updates: updates.stream, mode: AllSessionsMode.active);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final runningChip = find.byKey(const Key("session-list-filter-running"));
      expect(skeletonOpacity(tester), 1);
      expect(paintedOpacity(tester, runningChip), 1);

      updates.add(running(isLoading: false));
      await tester.pump(Duration.zero);
      for (var elapsed = 0; elapsed <= 250; elapsed += 10) {
        await tester.pump(const Duration(milliseconds: 10));
        expect(paintedOpacity(tester, runningChip), 1, reason: "at ${elapsed}ms");
      }
      expect(skeleton, findsNothing);
      expect(paintedOpacity(tester, find.text("No sessions match this filter")), 1);
    });

    testWidgets("a filter tapped while a project loads shows at once, holding the chips still as the rows fade out", (
      tester,
    ) async {
      // Another project still loads, and Running leaves no rows.
      AllSessionsState filtered(SessionListQuickFilter filter) => state(
        query: "",
        failure: null,
        rows: [
          if (filter == SessionListQuickFilter.all)
            row(title: "Fix the parser", updatedAt: now, archivedAt: null, isRunning: false),
        ],
        scratchProjectId: null,
        counts: const SessionListChipCounts(all: 1, running: 0, unread: 0),
        quickFilter: filter,
        isLoading: true,
      );
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(
        tester,
        initial: filtered(SessionListQuickFilter.all),
        updates: updates.stream,
        mode: AllSessionsMode.active,
      );
      final allChip = find.byKey(const Key("session-list-filter-all"));
      final chipTop = tester.getTopLeft(runningChip).dy;
      final pills = find.byKey(const ValueKey("skeleton"));
      final listRow = find.text("Fix the parser");

      final frames = await framesAcross(
        tester,
        updates: updates,
        update: filtered(SessionListQuickFilter.running),
        read: () => (
          selected: (all: selected(tester, allChip), running: selected(tester, runningChip)),
          chips: paintedOpacity(tester, runningChip),
          top: tester.getTopLeft(runningChip).dy,
          pills: pills.evaluate().length,
          tappable: allChip.hitTestable().evaluate().length,
          row: shownOpacity(tester, listRow),
          skeleton: skeletonOpacity(tester),
        ),
      );
      // The chips show the new selection from the tap on, as they are, and
      // take taps, while the rows fade into the skeleton.
      for (final (index, frame) in frames.indexed) {
        expect(
          (frame.selected, frame.chips, frame.top, frame.pills, frame.tappable),
          ((all: false, running: true), 1, chipTop, 0, 1),
          reason: "at ${index * 100}ms",
        );
      }
      expect(frames[1].row, inExclusiveRange(0, 1));
      expect(frames[1].skeleton, inExclusiveRange(0, 1));
      expect(frames[3].row, isNull);
      expect(frames[3].skeleton, 1);
    });

    testWidgets("a filter tapped as the chips fade in over their pills shows at once, the chips fading on in place", (
      tester,
    ) async {
      // Another project still loads, and Running leaves no rows.
      AllSessionsState filtered(SessionListQuickFilter filter) => state(
        query: "",
        failure: null,
        rows: [
          if (filter == SessionListQuickFilter.all)
            row(title: "Fix the parser", updatedAt: now, archivedAt: null, isRunning: false),
        ],
        scratchProjectId: null,
        counts: const SessionListChipCounts(all: 1, running: 0, unread: 0),
        quickFilter: filter,
        isLoading: true,
      );
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpLoading(tester, updates: updates.stream, mode: AllSessionsMode.active);
      final allChip = find.byKey(const Key("session-list-filter-all"));
      final pills = find.byKey(const ValueKey("skeleton"));
      updates.add(filtered(SessionListQuickFilter.all));
      await tester.pump(Duration.zero);
      // The hand-off starts on the frame after the rows mount.
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 100));
      final chipsBefore = paintedOpacity(tester, runningChip);
      expect(chipsBefore, inExclusiveRange(0, 1));
      expect(pills, findsOneWidget);
      final chipTop = tester.getTopLeft(runningChip).dy;
      final pillBars = find.descendant(of: pills, matching: find.byType(PregoSkeletonBar));

      final frames = await everyFrameAcross(
        tester,
        updates: updates,
        update: filtered(SessionListQuickFilter.running),
        read: () => (
          selected: (all: selected(tester, allChip), running: selected(tester, runningChip)),
          chips: paintedOpacity(tester, runningChip),
          top: tester.getTopLeft(runningChip).dy,
          pills: pillBars.evaluate().isEmpty ? null : paintedOpacity(tester, pillBars.first),
          tappable: allChip.hitTestable().evaluate().length,
        ),
      );
      // The chips show the tapped filter at once and take taps, fading on in
      // place from where they stood, never brighter by more than a frame's
      // fade, as the pills under them fade on out.
      for (final (index, frame) in frames.indexed) {
        expect(
          (frame.selected, frame.top, frame.tappable),
          ((all: false, running: true), chipTop, 1),
          reason: "at ${index * 10}ms",
        );
      }
      final chips = [chipsBefore, for (final frame in frames) frame.chips];
      expect(steps(chips), everyElement(inInclusiveRange(0, 0.1)));
      expect(chips.last, 1);
      final pillOpacities = [for (final frame in frames) frame.pills];
      expect(pillOpacities.first, inExclusiveRange(0, 1));
      expect(steps(pillOpacities), everyElement(lessThanOrEqualTo(0)));
      expect(pillOpacities.last, isNull);
      expect(skeletonOpacity(tester), 1);
    });

    testWidgets("a filter tapped while a project loads and only a launch is listed shows at once, the chips holding "
        "still", (tester) async {
      final launches = inMemorySessionLaunchRepository();
      // Another project still loads, and has none counted yet.
      AllSessionsState filtered(SessionListQuickFilter filter) => state(
        query: "",
        failure: null,
        rows: const [],
        scratchProjectId: null,
        quickFilter: filter,
        isLoading: true,
      );
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(
        tester,
        initial: filtered(SessionListQuickFilter.all),
        updates: updates.stream,
        mode: AllSessionsMode.active,
        launches: launches,
      );
      launches.start(
        launchId: "launch-1",
        projectId: project.id,
        pluginId: "claude",
        startedAt: DateTime.now(),
        projectName: project.name,
        submission: NewSessionSubmissionSnapshot.text(
          draft: ComposerDraft.typed(text: "Fix the parser"),
          attachments: const [],
        ),
      );
      // The launch's row hands off from the skeleton, the chips over their pills.
      for (var elapsed = 0; elapsed < 700; elapsed += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final allChip = find.byKey(const Key("session-list-filter-all"));
      final launchRow = find.byType(PendingSessionLaunchTile);
      final pills = find.byKey(const ValueKey("skeleton"));
      final chipTop = tester.getTopLeft(runningChip).dy;
      expect(
        (paintedOpacity(tester, runningChip), paintedOpacity(tester, launchRow), pills.evaluate().length),
        (1, 1, 0),
      );

      ({({bool? all, bool? running}) selected, double chips, double top, int pills, int tappable}) chips() => (
        selected: (all: selected(tester, allChip), running: selected(tester, runningChip)),
        chips: paintedOpacity(tester, runningChip),
        top: tester.getTopLeft(runningChip).dy,
        pills: pills.evaluate().length,
        tappable: allChip.hitTestable().evaluate().length,
      );
      final frames = await everyFrameAcross(
        tester,
        updates: updates,
        update: filtered(SessionListQuickFilter.running),
        read: () => (chips: chips(), launch: shownOpacity(tester, launchRow)),
      );
      // The chips show the tapped filter from the tap on, as they are, and
      // take taps, while the launch's row fades into the skeleton.
      for (final (index, frame) in frames.indexed) {
        expect(frame.chips, (
          selected: (all: false, running: true),
          chips: 1,
          top: chipTop,
          pills: 0,
          tappable: 1,
        ), reason: "at ${index * 10}ms");
      }
      expect(frames[10].launch, inExclusiveRange(0, 1));
      expect(frames.last.launch, isNull);
      expect(skeletonOpacity(tester), 1);

      // All again brings the launch's row back, the chips still as they are.
      final back = await everyFrameAcross(
        tester,
        updates: updates,
        update: filtered(SessionListQuickFilter.all),
        read: chips,
      );
      for (final (index, frame) in back.indexed) {
        expect(frame, (
          selected: (all: true, running: false),
          chips: 1,
          top: chipTop,
          pills: 0,
          tappable: 1,
        ), reason: "at ${index * 10}ms");
      }
      expect(paintedOpacity(tester, launchRow), 1);
    });

    for (final arrivesAfter in [100, 300]) {
      testWidgets("counts that arrive ${arrivesAfter}ms into a load that replaced the chips fade them in over their "
          "pills", (tester) async {
        // Running leaves no rows of the next computer's first project while
        // another still loads.
        AllSessionsState running({required List<String> titles, required int sessions, required bool isLoading}) =>
            state(
              query: "",
              failure: null,
              rows: [
                for (final title in titles) row(title: title, updatedAt: now, archivedAt: null, isRunning: true),
              ],
              scratchProjectId: null,
              counts: SessionListChipCounts(all: sessions, running: titles.length, unread: 0),
              quickFilter: SessionListQuickFilter.running,
              isLoading: isLoading,
            );
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        await pumpList(
          tester,
          initial: running(titles: ["Fix the parser"], sessions: 1, isLoading: false),
          updates: updates.stream,
          mode: AllSessionsMode.active,
        );
        final pillBars = find.descendant(
          of: find.byKey(const ValueKey("skeleton")),
          matching: find.byType(PregoSkeletonBar),
        );
        final chipTop = tester.getTopLeft(runningChip).dy;

        // A computer switch, then the next computer's counts.
        updates.add(running(titles: const [], sessions: 0, isLoading: true));
        await tester.pump(Duration.zero);
        final frames = <({double chips, double pills})>[];
        for (var elapsed = 0; elapsed < 600; elapsed += 10) {
          if (elapsed == arrivesAfter) updates.add(running(titles: const [], sessions: 2, isLoading: true));
          await tester.pump(const Duration(milliseconds: 10));
          frames.add((
            chips: shownOpacity(tester, runningChip) ?? 0,
            pills: pillBars.evaluate().isEmpty ? 0 : paintedOpacity(tester, pillBars.first),
          ));
          if (runningChip.evaluate().isNotEmpty) expect(tester.getTopLeft(runningChip).dy, chipTop);
        }
        // Out under their pills, then in over them, never at once.
        for (final readings in [
          [for (final frame in frames) frame.chips],
          [for (final frame in frames) frame.pills],
        ]) {
          expect(steps(readings), everyElement(inInclusiveRange(-0.1, 0.1)));
        }
        expect(frames.last, (chips: 1, pills: 0));
        expect(find.text("Running · 0"), findsOneWidget);
        expect(selected(tester, runningChip), isTrue);
        expect(runningChip.hitTestable(), findsOneWidget);
        expect(skeletonOpacity(tester), 1);
      });
    }

    for (final (name, initial, departing, holdsStill) in [
      ("a note", loaded(mode: AllSessionsMode.active, titles: const [], query: "zzz"), find.text("No matches"), true),
      // The load opens the search field and chips over it, as over an empty
      // state at rest, for the skeleton's room.
      ("the empty state", empty, find.text("Nothing here"), false),
    ]) {
      testWidgets("a load that starts as $name fades out fades it out with the list, before any rows show", (
        tester,
      ) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        await pumpList(tester, initial: initial, updates: updates.stream, mode: AllSessionsMode.active);
        final top = tester.getTopLeft(departing).dy;
        final sessionRow = find.text("Fix the parser");

        // Its sessions return, and a project switch starts a load as it fades.
        updates.add(loaded(mode: AllSessionsMode.active, titles: const ["Fix the parser"]));
        await tester.pump(Duration.zero);
        await tester.pump(const Duration(milliseconds: 60));
        final frames = await everyFrameAcross(
          tester,
          updates: updates,
          update: loading,
          read: () => (
            opacity: shownOpacity(tester, departing),
            top: topOf(tester, departing),
            row: sessionRow.evaluate().length,
          ),
        );
        expect(frames.first.opacity, inExclusiveRange(0, 1));
        expect(steps([for (final frame in frames) frame.opacity]), everyElement(lessThanOrEqualTo(0)));
        for (final frame in frames) {
          if (holdsStill && frame.opacity != null) expect(frame.top, top);
          expect(frame.row, 0);
        }
        expect(frames.last.opacity, isNull);
        expect(skeletonOpacity(tester), 1);
      });
    }

    final oldRow = find.text("Fix the parser");
    final newRow = find.text("Draft the install guide");

    for (final mode in AllSessionsMode.values) {
      testWidgets(
        "a load that replaces the rows, as a computer switch's, fades them into the skeleton (${mode.name})",
        (
          tester,
        ) async {
          final updates = StreamController<AllSessionsState>();
          addTearDown(updates.close);
          await pumpList(
            tester,
            initial: loaded(mode: mode, titles: ["Fix the parser"], failure: failure),
            updates: updates.stream,
            mode: mode,
          );
          // The Retry row fades in as it first shows.
          await tester.pump(const Duration(milliseconds: 300));

          updates.add(loading);
          // With nothing animating, a bare pump would skip the frame before the update arrives.
          await tester.pump(Duration.zero);
          expect(oldRow, findsOneWidget);
          expect(paintedOpacity(tester, oldRow), 1);

          // The rows stay, fading out and taking no taps, as the skeleton
          // fades in over them without waiting out its delay.
          await tester.pump(const Duration(milliseconds: 33));
          expect(oldRow, findsOneWidget);
          expect(paintedOpacity(tester, oldRow), inExclusiveRange(0, 1));
          expect(oldRow.hitTestable(), findsNothing);
          await tester.pump(const Duration(milliseconds: 67));
          expect(paintedOpacity(tester, oldRow), inExclusiveRange(0, 1));
          expect(paintedOpacity(tester, failureRow), moreOrLessEquals(paintedOpacity(tester, oldRow)));
          expect(find.text("Retry").hitTestable(), findsNothing);
          expect(skeletonOpacity(tester), inExclusiveRange(0, 1));
          expect(paintedOpacity(tester, searchField), 1);
          if (mode == AllSessionsMode.active) {
            final allChip = find.byKey(const Key("session-list-filter-all"));
            expect(paintedOpacity(tester, allChip), moreOrLessEquals(paintedOpacity(tester, oldRow)));
            expect(allChip.hitTestable(), findsNothing);
            final pill = find.descendant(of: find.byType(PregoShimmer).first, matching: find.byType(PregoSkeletonBar));
            expect(paintedOpacity(tester, pill.first), moreOrLessEquals(skeletonOpacity(tester)));
          }

          await tester.pump(const Duration(milliseconds: 150));
          expect(oldRow, findsNothing);
          expect(failureRow, findsNothing);
          expect(skeletonOpacity(tester), 1);
          expect(paintedOpacity(tester, searchField), 1);

          // The next computer's rows hand off from the skeleton as a first load's do.
          updates.add(loaded(mode: mode, titles: ["Draft the install guide"]));
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(skeletonOpacity(tester), inExclusiveRange(0, 1));
          expect(paintedOpacity(tester, newRow), inExclusiveRange(0, 1));
          await tester.pump(const Duration(milliseconds: 150));
          expect(skeleton, findsNothing);
          expect(paintedOpacity(tester, newRow), 1);
        },
      );
    }

    testWidgets("a load that ends as the rows it replaces fade out hands off from the skeleton they leave", (
      tester,
    ) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(
        tester,
        initial: loaded(mode: AllSessionsMode.active, titles: ["Fix the parser"]),
        updates: updates.stream,
        mode: AllSessionsMode.active,
      );
      updates.add(loading);
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 100));
      final rowTop = tester.getTopLeft(oldRow).dy;
      var last = skeletonOpacity(tester);
      expect(last, inExclusiveRange(0, 1));

      updates.add(loaded(mode: AllSessionsMode.active, titles: ["Draft the install guide"]));
      var dimming = false;
      for (var elapsed = 0; elapsed <= 400; elapsed += 10) {
        await tester.pump(const Duration(milliseconds: 10));
        final opacity = skeletonOpacity(tester);
        // It brightens until the old rows are gone, then only dims, never
        // snapping either way.
        expect((opacity - last).abs(), lessThan(0.2), reason: "at ${elapsed}ms");
        if (opacity < last) dimming = true;
        if (dimming) expect(opacity, lessThanOrEqualTo(last), reason: "at ${elapsed}ms");
        // The new rows show only once the old ones are gone, in their place.
        expect(oldRow.evaluate().isEmpty || newRow.evaluate().isEmpty, isTrue, reason: "at ${elapsed}ms");
        if (oldRow.evaluate().isNotEmpty) expect(tester.getTopLeft(oldRow).dy, rowTop);
        if (newRow.evaluate().isNotEmpty) expect(tester.getTopLeft(newRow).dy, rowTop);
        last = opacity;
      }
      expect(dimming, isTrue);
      expect(skeleton, findsNothing);
      expect(paintedOpacity(tester, newRow), 1);
    });

    testWidgets("under reduced motion a load that replaces the rows cuts straight to the skeleton", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpList(
        tester,
        initial: loaded(mode: AllSessionsMode.archived, titles: ["Fix the parser"]),
        updates: updates.stream,
      );

      updates.add(loading);
      await tester.pump(Duration.zero);
      expect(oldRow, findsNothing);
      expect(skeletonOpacity(tester), 1);
      expect(paintedOpacity(tester, searchField), 1);
    });

    for (final (name, initial, shown) in [
      ("the empty state", empty, find.text("Nothing here")),
      (
        "Retry rows",
        state(query: "", failure: failure, rows: const [], scratchProjectId: null),
        failureRow,
      ),
    ]) {
      testWidgets("a load that replaces $name fades it into the skeleton as the search field opens", (tester) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        await pumpList(tester, initial: initial, updates: updates.stream);
        // A Retry row fades in as it first shows.
        await tester.pump(const Duration(milliseconds: 300));
        expect(searchField, findsNothing);

        updates.add(loading);
        await tester.pump(Duration.zero);
        await tester.pump(const Duration(milliseconds: 100));
        expect(shown, findsOneWidget);
        expect(paintedOpacity(tester, shown), inExclusiveRange(0, 1));
        expect(find.text("Retry").hitTestable(), findsNothing);
        expect(skeletonOpacity(tester), inExclusiveRange(0, 1));
        expect(paintedOpacity(tester, searchField), inExclusiveRange(0, 1));

        await tester.pump(const Duration(milliseconds: 150));
        expect(shown, findsNothing);
        expect(skeletonOpacity(tester), 1);
        expect(paintedOpacity(tester, searchField), 1);
      });
    }

    group("layout across every frame", () {
      for (final interaction in PregoInteractionMode.values) {
        for (final withHeader in [true, false]) {
          testWidgets(
            "a load that ends with sessions moves nothing (${interaction.name}, ${withHeader ? "header" : "no header"})",
            (tester) async {
              final updates = StreamController<AllSessionsState>();
              addTearDown(updates.close);
              final skeletonTop = await pumpLoading(
                tester,
                updates: updates.stream,
                mode: AllSessionsMode.active,
                header: withHeader ? header : null,
                interaction: interaction,
              );
              final headerTop = withHeader ? tester.getTopLeft(headerBox).dy : null;
              final fieldTop = tester.getTopLeft(searchField).dy;
              final heading = find.byType(SessionListHeadingSkeleton).first;
              final headingRect = tester.getRect(heading);
              final headingStart = tester
                  .getTopLeft(find.descendant(of: heading, matching: find.byType(PregoSkeletonBar)))
                  .dx;
              final rowRect = tester.getRect(find.byType(SessionTileSkeleton).first);
              final pillRect = tester.getRect(
                find.descendant(of: find.byType(PregoShimmer).first, matching: find.byType(PregoSkeletonBar)).first,
              );
              // The height the list sizes its placeholder by is the one it draws.
              expect(
                rowRect.height,
                SessionTileSkeleton.heightOf(pointer: interaction == PregoInteractionMode.pointer),
              );

              final [headerTops, fieldTops, skeletonTops] = await topsAcross(
                tester,
                updates: updates,
                update: loaded(mode: AllSessionsMode.active, titles: ["Fix the parser"]),
                finders: [headerBox, searchField, skeleton],
              );
              expect(headerTops, everyElement(headerTop));
              expect(fieldTops, everyElement(fieldTop));
              expect(skeletonTops.nonNulls, everyElement(skeletonTop));
              expect(skeleton, findsNothing);
              // Each chip, heading and row stands where its placeholder stood.
              expect(tester.getRect(find.byKey(const Key("session-list-filter-all"))), pillRect);
              expect(tester.getRect(find.byType(SessionListHeading)).top, headingRect.top);
              expect(tester.getRect(find.byType(SessionListHeading)).height, headingRect.height);
              expect(tester.getTopLeft(find.text("Today")).dx, headingStart);
              expect(tester.getRect(find.byType(SessionTile)), rowRect);
            },
          );
        }
      }

      testWidgets("a load that replaces the rows moves nothing", (tester) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        final row = find.text("Fix the parser");
        final allChip = find.byKey(const Key("session-list-filter-all"));
        final pills = find.byKey(const ValueKey("skeleton"));
        await pumpList(
          tester,
          initial: loaded(mode: AllSessionsMode.active, titles: ["Fix the parser"]),
          updates: updates.stream,
          mode: AllSessionsMode.active,
          header: header,
        );
        final headerTop = tester.getTopLeft(headerBox).dy;
        final fieldTop = tester.getTopLeft(searchField).dy;
        final chipTop = tester.getTopLeft(allChip).dy;
        final rowTop = tester.getTopLeft(row).dy;

        final [headerTops, fieldTops, chipTops, pillTops, skeletonTops, rowTops] = await topsAcross(
          tester,
          updates: updates,
          update: loading,
          finders: [headerBox, searchField, allChip, pills, skeleton, row],
        );
        expect(headerTops, everyElement(headerTop));
        expect(fieldTops, everyElement(fieldTop));
        // The chips fade out over the pills that hold their places.
        expect(chipTops.nonNulls, everyElement(chipTop));
        expect(pillTops.last, isNotNull);
        expect(pillTops.nonNulls, everyElement(pillTops.last));
        final allPill = find.descendant(of: pills, matching: find.byType(PregoSkeletonBar)).first;
        expect(tester.getTopLeft(allPill).dy, chipTop);
        // The skeleton fades in from where it then stands, over the rows.
        expect(skeletonTops.nonNulls, everyElement(tester.getTopLeft(skeleton).dy));
        expect(skeletonTops.last, lessThanOrEqualTo(rowTop));
        // The rows stay where they are as they fade out, gone once they have.
        expect(rowTops.take(40), everyElement(rowTop));
        expect(rowTops.last, isNull);
      });

      testWidgets("a load that replaces a scrolled list glides it to the top as the rows fade", (tester) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        await pumpList(
          tester,
          initial: loaded(mode: AllSessionsMode.active, titles: [for (var i = 0; i < 20; i++) "Session $i"]),
          updates: updates.stream,
          mode: AllSessionsMode.active,
          header: header,
        );
        final headerTop = tester.getTopLeft(headerBox).dy;
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
            )
            .position;
        position.jumpTo(100);
        await tester.pump();

        final [headerTops, skeletonTops] = await topsAcross(
          tester,
          updates: updates,
          update: loading,
          finders: [headerBox, skeleton],
        );
        final skeletonTop = tester.getTopLeft(skeleton).dy;
        for (final tops in [headerTops, skeletonTops]) {
          expect(steps(tops), everyElement(inInclusiveRange(0, maxStep)));
        }
        // From the fade's end, 200 ms after the update's frame, both rest.
        expect(headerTops.skip(41), everyElement(moreOrLessEquals(headerTop, epsilon: 0.5)));
        expect(skeletonTops.skip(41), everyElement(moreOrLessEquals(skeletonTop, epsilon: 0.5)));
        expect(position.pixels, 0);
      });

      testWidgets("a load that replaces the empty state opens the search field and chips smoothly", (tester) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        final skeletonTop = await pumpLoading(
          tester,
          updates: updates.stream,
          mode: AllSessionsMode.active,
          header: header,
        );
        final headerTop = tester.getTopLeft(headerBox).dy;
        updates.add(empty);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.getTopLeft(headerBox).dy, 0);

        final [headerTops, skeletonTops, emptyTops] = await topsAcross(
          tester,
          updates: updates,
          update: loading,
          finders: [headerBox, skeleton, find.text("Nothing here")],
        );
        for (final tops in [headerTops, skeletonTops, emptyTops]) {
          expect(steps(tops), everyElement(inInclusiveRange(0, maxStep)));
        }
        expect(headerTops.last, headerTop);
        expect(skeletonTops.last, skeletonTop);
        expect(emptyTops.last, isNull);
      });

      testWidgets("counts that wrap the chips onto another line ease the room open", (tester) async {
        // Wide enough for the placeholders' two lines, too narrow for these
        // counts' two.
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(380, 900);
        addTearDown(tester.view.reset);
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        await pumpLoading(tester, updates: updates.stream, mode: AllSessionsMode.active);
        final chipsRoom = find.descendant(
          of: find.byKey(const ValueKey("all-sessions-chips")),
          matching: find.byType(AnimatedSize),
        );
        final loadingHeight = tester.getSize(chipsRoom).height;
        // Only its placeholder carries no count.
        final lastPill = find.text("Unread · 0");
        final lastPillTop = tester.getTopLeft(lastPill).dy;

        final [skeletonTops, pillTops] = await topsAcross(
          tester,
          updates: updates,
          update: loaded(
            mode: AllSessionsMode.active,
            titles: ["Fix the parser"],
            counts: const SessionListChipCounts(all: 1000, running: 100, unread: 100),
          ),
          finders: [skeleton, lastPill],
        );
        expect(tester.getSize(chipsRoom).height, greaterThan(loadingHeight));
        // The placeholders fade out where they stood, and what is below eases
        // down rather than snapping.
        expect(pillTops.nonNulls, everyElement(lastPillTop));
        expect(steps(skeletonTops), everyElement(lessThan(2)));
      });

      testWidgets("the chips' and the list's placeholders fade in together", (tester) async {
        await pumpList(tester, initial: loading, mode: AllSessionsMode.active, header: header);
        final shimmers = find.byType(PregoShimmer);
        expect(shimmers, findsNWidgets(2));
        final seen = <double>{};
        for (var elapsed = 0; elapsed < 600; elapsed += 5) {
          await tester.pump(const Duration(milliseconds: 5));
          final [chips, list] = [
            for (var index = 0; index < 2; index++)
              paintedOpacity(
                tester,
                find.descendant(of: shimmers.at(index), matching: find.byType(PregoSkeletonBar)).first,
              ),
          ];
          expect(list, chips);
          seen.add(chips);
        }
        // Through the whole fade, from unseen to shown.
        expect(seen, containsAll([0.0, 1.0]));
        expect(seen.length, greaterThan(10));
      });

      testWidgets("the list's placeholder is date groups of 3, 2 and 4 rows", (
        tester,
      ) async {
        await pumpLoading(tester, updates: const Stream.empty());
        final pattern = [
          for (final element
              in find
                  .descendant(
                    of: skeleton,
                    matching: find.byWidgetPredicate(
                      (w) => w is SessionListHeadingSkeleton || w is SessionTileSkeleton,
                    ),
                  )
                  .evaluate())
            element.widget is SessionListHeadingSkeleton ? "heading" : "row",
        ].join(" ");
        expect(pattern, "heading row row row heading row row heading row row row row");
      });

      testWidgets("the list's placeholder fills the room left on screen, leaving nothing to scroll", (tester) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        await pumpLoading(tester, updates: updates.stream, mode: AllSessionsMode.active, header: header);
        ScrollPosition position() => tester.state<ScrollableState>(find.byType(Scrollable).first).position;
        Rect shown() => tester.getRect(find.ancestor(of: skeleton, matching: find.byType(ClipRect)).first);
        expect(position().maxScrollExtent, 0);
        expect(shown().bottom, 600);

        // Nor once a Retry row has opened above it.
        updates.add(
          state(query: "", failure: failure, rows: const [], scratchProjectId: null, isLoading: true),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(position().maxScrollExtent, 0);
        expect(shown().bottom, 600);
      });

      testWidgets("a load that ends with no sessions folds the search field and chips away smoothly", (tester) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        final skeletonTop = await pumpLoading(
          tester,
          updates: updates.stream,
          mode: AllSessionsMode.active,
          header: header,
        );
        // The search field and chips above the header.
        final headerTop = tester.getTopLeft(headerBox).dy;
        expect(headerTop, greaterThan(20));

        final [headerTops, skeletonTops, emptyTops] = await topsAcross(
          tester,
          updates: updates,
          update: empty,
          finders: [headerBox, skeleton, find.text("Nothing here")],
        );
        for (final tops in [headerTops, skeletonTops, emptyTops]) {
          expect(steps(tops), everyElement(inInclusiveRange(-maxStep, 0)));
        }
        expect(headerTops.first, headerTop);
        expect(headerTops.last, 0);
        expect(skeletonTops.first, skeletonTop);
        expect(emptyTops.last, tester.getRect(headerBox).bottom);
        expect(find.byType(PregoShimmer), findsNothing);
      });

      for (final withHeader in [true, false]) {
        testWidgets(
          "Retry rows shown while loading stay put as the sessions arrive (${withHeader ? "header" : "no header"})",
          (tester) async {
            final updates = StreamController<AllSessionsState>();
            addTearDown(updates.close);
            await pumpLoading(
              tester,
              updates: updates.stream,
              mode: AllSessionsMode.active,
              header: withHeader ? header : null,
            );
            updates.add(
              state(query: "", failure: failure, rows: const [], scratchProjectId: null, isLoading: true),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));
            final failureTop = tester.getTopLeft(failureRow).dy;
            final skeletonTop = tester.getTopLeft(skeleton).dy;

            // The rows arrive under the Retry row without moving it.
            final [failureTops, skeletonTops, rowTops] = await topsAcross(
              tester,
              updates: updates,
              update: loaded(
                mode: AllSessionsMode.active,
                titles: ["Fix the parser"],
                failure: failure,
              ),
              finders: [failureRow, skeleton, find.text("Fix the parser")],
            );
            expect(failureTops, everyElement(failureTop));
            expect(skeletonTops.nonNulls, everyElement(skeletonTop));
            expect(rowTops.nonNulls, isNotEmpty);
            expect(rowTops.nonNulls, everyElement(rowTops.nonNulls.first));
          },
        );
      }

      testWidgets("a Retry row that shows mid-load opens, easing the skeleton down", (tester) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        final skeletonTop = await pumpLoading(
          tester,
          updates: updates.stream,
          mode: AllSessionsMode.active,
          header: header,
        );

        final [skeletonTops] = await topsAcross(
          tester,
          updates: updates,
          update: state(query: "", failure: failure, rows: const [], scratchProjectId: null, isLoading: true),
          finders: [skeleton],
        );
        expect(steps(skeletonTops), everyElement(inInclusiveRange(0, maxStep)));
        expect(skeletonTops.first, skeletonTop);
        expect(skeletonTops.last, skeletonTop + tester.getSize(failurePadding).height);
        expect(paintedOpacity(tester, failureRow), 1);
      });
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

  group("the page after the rows", () {
    final now = DateTime.now();
    List<AllSessionsRow> rows({required int count}) => [
      for (var index = 0; index < count; index++)
        row(
          title: "Session $index",
          updatedAt: now.subtract(Duration(seconds: index)),
          archivedAt: null,
          isRunning: false,
        ),
    ];
    AllSessionsState page({required int count, required SessionWindowLoadMore? loadMore}) => state(
      query: "",
      failure: null,
      rows: rows(count: count),
      scratchProjectId: null,
      loadMore: loadMore,
      counts: SessionListChipCounts(all: count + 50, running: 0, unread: 0),
    );
    final loader = find.byType(PregoAiLoader);
    List<double> topsOf({required WidgetTester tester, required int count}) => [
      for (var index = 0; index < count; index++) tester.getTopLeft(find.text("Session $index")).dy,
    ];

    testWidgets("rows near the end ask for it under a loader row", (tester) async {
      final cubit = await pumpList(
        tester,
        mode: AllSessionsMode.active,
        initial: page(count: 5, loadMore: SessionWindowLoadMore.idle),
      );
      expect(loader, findsOneWidget);
      verify(cubit.loadMore).called(greaterThan(0));
    });

    testWidgets("rows far from the end ask for nothing yet", (tester) async {
      final cubit = await pumpList(
        tester,
        mode: AllSessionsMode.active,
        initial: page(count: 120, loadMore: SessionWindowLoadMore.idle),
      );
      verifyNever(cubit.loadMore);
    });

    testWidgets("a page on its way is not asked for again", (tester) async {
      final cubit = await pumpList(
        tester,
        mode: AllSessionsMode.active,
        initial: page(count: 5, loadMore: SessionWindowLoadMore.loading),
      );
      expect(loader, findsOneWidget);
      verifyNever(cubit.loadMore);
    });

    testWidgets("without a page after the rows there is no loader row", (tester) async {
      final cubit = await pumpList(
        tester,
        mode: AllSessionsMode.active,
        initial: page(count: 5, loadMore: null),
      );
      expect(loader, findsNothing);
      verifyNever(cubit.loadMore);
    });

    testWidgets("a page that failed offers Retry in the loader row", (tester) async {
      final cubit = await pumpList(
        tester,
        mode: AllSessionsMode.active,
        initial: page(count: 5, loadMore: SessionWindowLoadMore.failed),
      );
      verifyNever(cubit.loadMore);
      await tester.tap(find.text("Retry"));
      verify(cubit.loadMore).called(1);
    });

    for (final more in [true, false]) {
      testWidgets("the page arriving moves no row above it (${more ? "another follows" : "the last page"})", (
        tester,
      ) async {
        final updates = StreamController<AllSessionsState>();
        addTearDown(updates.close);
        await pumpList(
          tester,
          mode: AllSessionsMode.active,
          initial: page(count: 3, loadMore: SessionWindowLoadMore.loading),
          updates: updates.stream,
        );
        final before = topsOf(tester: tester, count: 3);
        final frames = await everyFrameAcross(
          tester,
          updates: updates,
          update: page(count: 6, loadMore: more ? SessionWindowLoadMore.idle : null),
          read: () => topsOf(tester: tester, count: 3),
        );
        expect(frames, everyElement(before));
        if (!more) expect(loader, findsNothing);
      });
    }
  });
}

Widget _offlinePage({required BuildContext context, required ProjectListBridgeDisconnected state}) =>
    const SliverToBoxAdapter(child: Text("Computer offline"));

/// A surface that knows the computer is about to connect.
Widget? _aboutToConnect({required BuildContext context, required ProjectListBridgeDisconnected state}) => null;
