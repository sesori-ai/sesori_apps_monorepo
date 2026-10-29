import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  const unfiltered = (projectId: null, query: null, filter: SessionListQuickFilter.all);
  final existing = testSession(id: "existing");
  final created = testSession(id: "created");
  late BehaviorSubject<SessionWindowState> windowState;
  late SessionWindowKey key;
  late SessionLaunchRepository launches;
  late ProjectLaunchRowsCubit cubit;

  SessionWindowLoaded loaded(List<Session> sessions, {String? nextCursor, bool awaitingAnswer = false}) =>
      SessionWindowLoaded(
        sessions: sessions,
        counts: SessionPageCounts(all: sessions.length, running: 0, unread: 0),
        nextCursor: nextCursor,
        loadMore: SessionWindowLoadMore.idle,
        awaitingAnswer: awaitingAnswer,
      );

  setUp(() {
    key = unfiltered;
    windowState = BehaviorSubject.seeded(loaded([existing], nextCursor: "page-2"));
    final window = _MockSessionWindowService();
    when(() => window.state).thenAnswer((_) => windowState.stream);
    when(() => window.key).thenAnswer((_) => key);
    launches = inMemorySessionLaunchRepository();
    cubit = ProjectLaunchRowsCubit(
      window: window,
      launchService: inMemorySessionLaunchService(launchRepository: launches),
      initialRows: const {},
    );
  });
  tearDown(() async {
    await cubit.close();
    await windowState.close();
  });

  void launch() => launches.start(
    launchId: "launch-1",
    projectId: "project-1",
    pluginId: "claude",
    startedAt: DateTime.utc(2026, 10, 7, 12),
    projectName: "Sesori",
    submission: NewSessionSubmissionSnapshot.text(
      draft: ComposerDraft.typed(text: "Fix the bug"),
      attachments: const [],
    ),
  );

  List<String> placeholders() => [
    for (final row in cubit.state["project-1"]?.placeholders ?? const <LaunchingSession>[]) row.launchId,
  ];

  test("a launch's session takes the row's place from the window's first page", () async {
    launch();
    await pumpEventQueue();
    expect(placeholders(), ["launch-1"]);

    launches.promote(launchId: "launch-1", session: created);
    await pumpEventQueue();
    expect(cubit.state["project-1"]?.heldSessionIds, {"created"}, reason: "its session has not arrived yet");

    windowState.add(loaded([created, existing], nextCursor: "page-2"));
    await pumpEventQueue();
    expect(cubit.state["project-1"]?.placeholders, isEmpty);
    expect(cubit.state["project-1"]?.rowKeys, {"created": "launch-1"});
  });

  test("a page appended while a launch waits is neither held nor settles it", () async {
    final older = testSession(id: "older");
    launch();
    await pumpEventQueue();

    windowState.add(loaded([existing, older]));
    await pumpEventQueue();

    expect(placeholders(), ["launch-1"]);
    expect(cubit.state["project-1"]?.heldSessionIds, isEmpty);
  });

  test("a launch keeps its row while searching and settles once the search clears", () async {
    launch();
    await pumpEventQueue();
    key = (projectId: null, query: "bug", filter: SessionListQuickFilter.all);
    windowState.add(loaded(const [], awaitingAnswer: true));
    await pumpEventQueue();

    launches.promote(launchId: "launch-1", session: created);
    windowState.add(loaded(const []));
    await pumpEventQueue();
    expect(placeholders(), ["launch-1"], reason: "the search hides the launch's session, not its launch");

    key = unfiltered;
    windowState.add(loaded([existing], awaitingAnswer: true));
    await pumpEventQueue();
    expect(placeholders(), ["launch-1"], reason: "rows narrowed from the search may lack the session");

    windowState.add(loaded([created, existing]));
    await pumpEventQueue();
    expect(cubit.state["project-1"]?.placeholders, isEmpty);
    expect(cubit.state["project-1"]?.rowKeys, {"created": "launch-1"});
  });

  test("a project filter keeps the other projects' launching rows", () async {
    launch();
    await pumpEventQueue();
    key = (projectId: "project-2", query: null, filter: SessionListQuickFilter.all);
    windowState.add(loaded([testSession(id: "elsewhere").copyWith(projectID: "project-2")]));
    await pumpEventQueue();

    expect(placeholders(), ["launch-1"]);
    expect(cubit.state["project-1"]?.listedSessionIds, ["existing"], reason: "project-1 is not listed meanwhile");
  });
}

class _MockSessionWindowService() extends Mock implements SessionWindowService;
