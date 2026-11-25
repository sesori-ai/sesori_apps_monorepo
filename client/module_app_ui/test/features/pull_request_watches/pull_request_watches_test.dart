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

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

PullRequestWatchListItem _item({
  required int number,
  required String title,
  required PullRequestWatchStatus status,
  bool autoMerge = false,
}) => PullRequestWatchListItem(
  sessionId: "session-1",
  sessionTitle: "Fixture session",
  projectId: "project-1",
  watch: SessionPullRequestWatch(
    repository: "acme/web",
    number: number,
    title: title,
    url: "https://github.com/acme/web/pull/$number",
    autoMerge: autoMerge,
    status: status,
  ),
);

const _ciFailing = PullRequestWatchStatus.needsYou(reasons: [PullRequestWatchNeed.ciFailing]);

void main() {
  late MockPullRequestWatchRepository repository;
  late MockSessionRepository sessions;
  late MockConnectionService connection;
  late StreamController<SseEvent> events;

  setUp(() {
    repository = MockPullRequestWatchRepository();
    sessions = MockSessionRepository();
    connection = MockConnectionService();
    events = StreamController<SseEvent>.broadcast();
    final statuses = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
    when(() => connection.events).thenAnswer((_) => events.stream);
    when(() => connection.status).thenAnswer((_) => statuses);
    when(() => connection.currentStatus).thenAnswer((_) => statuses.value);
    addTearDown(statuses.close);
    addTearDown(events.close);
  });

  void answerList(List<PullRequestWatchListItem> watches) =>
      when(() => repository.listWatches()).thenAnswer((_) async => PullRequestWatchListSuccess(watches: watches));

  Future<void> changeTo(WidgetTester tester, List<PullRequestWatchListItem> watches) async {
    answerList(watches);
    events.add(SseEvent(data: const SesoriSseEvent.pullRequestWatchesChanged()));
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    final cubit = PullRequestWatchListCubit(
      repository: repository,
      sessionRepository: sessions,
      connectionService: connection,
    );
    addTearDown(cubit.close);
    final projects = _MockProjectListCubit();
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(projects: [], folderProjects: [], scratchProject: null),
    );
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<PullRequestWatchListCubit>.value(value: cubit),
          BlocProvider<ProjectListCubit>.value(value: projects),
        ],
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("the home button shows only while pull requests are watched, with a count of those needing the user", (
    tester,
  ) async {
    answerList([]);
    await pump(tester, PullRequestWatchesButton(size: PregoButtonsIconGlassSize.lg, onPressed: () {}));
    expect(find.byKey(const Key("home-pull-requests")), findsNothing);

    await changeTo(tester, [_item(number: 1, title: "Bump deps", status: const PullRequestWatchStatus.waiting())]);
    expect(find.byKey(const Key("home-pull-requests")), findsOneWidget);
    expect(find.bySemanticsLabel("Pull requests"), findsOneWidget);

    await changeTo(tester, [_item(number: 1, title: "Bump deps", status: _ciFailing)]);
    expect(find.text("1"), findsOneWidget);
    expect(find.bySemanticsLabel("Pull requests, 1 needs you"), findsOneWidget);
  });

  testWidgets("rows group by status and change in place while the list is open", (tester) async {
    answerList([
      _item(number: 2, title: "Bump deps", status: const PullRequestWatchStatus.waiting(), autoMerge: true),
      _item(number: 1, title: "Add search", status: _ciFailing),
    ]);
    await pump(
      tester,
      PullRequestWatchesList(
        sessionId: null,
        onOpenSession: ({
          required projectId,
          required projectName,
          required sessionId,
          required sessionTitle,
        }) {},
      ),
    );

    expect(find.text("Needs you"), findsOneWidget);
    expect(find.text("Waiting"), findsOneWidget);
    expect(find.textContaining("CI failing"), findsOneWidget);
    expect(find.byKey(const Key("pull-request-watch-auto-merge-mark")), findsOneWidget);
    final needsYouTop = tester.getTopLeft(find.text("Add search")).dy;

    await changeTo(tester, [
      _item(number: 2, title: "Bump deps", status: const PullRequestWatchStatus.waiting(), autoMerge: true),
      _item(number: 1, title: "Add search", status: const PullRequestWatchStatus.ready()),
    ]);
    // Still under Needs you, where the user saw it; only its status changed.
    expect(find.text("Needs you"), findsOneWidget);
    expect(find.text("Ready"), findsNothing);
    expect(find.textContaining("ready"), findsOneWidget);
    expect(tester.getTopLeft(find.text("Add search")).dy, needsYouTop);
  });

  testWidgets("a failed stop keeps the row and says why", (tester) async {
    answerList([_item(number: 1, title: "Add search", status: _ciFailing)]);
    when(
      () => sessions.stopPullRequestWatch(
        sessionId: any(named: "sessionId"),
        repository: any(named: "repository"),
        number: any(named: "number"),
      ),
    ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    await pump(
      tester,
      PullRequestWatchesList(
        sessionId: null,
        onOpenSession: ({
          required projectId,
          required projectName,
          required sessionId,
          required sessionTitle,
        }) {},
      ),
    );

    await tester.longPress(find.text("Add search"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Stop"));
    await tester.pumpAndSettle();

    expect(find.text("Add search"), findsOneWidget);
    expect(find.text("Could not stop watching the pull request. Reconnect and try again."), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
