import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

final _recurring = scheduledTaskFixture(id: "daily", name: "Morning summary");
final _once = scheduledTaskFixture(
  id: "once",
  name: "Release notes",
  schedule: const TaskSchedule.once(at: TaskLocalDateTime(year: 2026, month: 12, day: 1, hour: 9, minute: 0)),
  nextRunAt: ScheduledTaskInstant(at: DateTime.utc(2026, 12, 1, 9).millisecondsSinceEpoch, offsetMinutes: 0),
);

class _FixedTimeZoneSource({required final String zone}) implements DeviceTimeZoneSource {
  @override
  Future<String> currentZoneName() async => zone;
}

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

ScheduledTaskRun _run({required String id, required ScheduledTaskRunOutcome outcome}) => ScheduledTaskRun(
  id: id,
  scheduledFor: ScheduledTaskInstant(at: DateTime.utc(2026, 11, 2, 9).millisecondsSinceEpoch, offsetMinutes: 0),
  outcome: outcome,
);

void main() {
  late MockScheduledTaskRepository repository;
  late MockConnectionService connection;

  setUp(() {
    repository = MockScheduledTaskRepository();
    connection = MockConnectionService();
    final statuses = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
    when(() => connection.events).thenAnswer((_) => const Stream.empty());
    when(() => connection.status).thenAnswer((_) => statuses);
    addTearDown(statuses.close);
  });

  Future<void> pump({
    required WidgetTester tester,
    required Widget child,
    List<ProjectSummary> projects = const [],
  }) async {
    final projectList = _MockProjectListCubit();
    whenListen(
      projectList,
      const Stream<ProjectListState>.empty(),
      initialState: ProjectListState.loaded(projects: projects, folderProjects: projects, scratchProject: null),
    );
    // A router, so the task page's sheets close the way they do in the app.
    final router = GoRouter(
      routes: [GoRoute(path: "/", builder: (_, _) => child)],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => testBridgeKindCubit(kind: null)),
          BlocProvider<ProjectListCubit>.value(value: projectList),
        ],
        child: MaterialApp.router(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpList({
    required WidgetTester tester,
    required ScheduledTaskResult<List<ScheduledTask>> tasks,
    VoidCallback? onNewTask,
    String deviceTimeZone = "UTC",
  }) {
    when(() => repository.listTasks()).thenAnswer((_) async => tasks);
    return pump(
      tester: tester,
      child: ScheduledTasksView(
        createCubit: () => ScheduledTasksCubit(
          repository: repository,
          connectionService: connection,
          timeZoneSource: _FixedTimeZoneSource(zone: deviceTimeZone),
        ),
        exit: ScheduledPageExit.back,
        onExit: () {},
        onOpenTask: ({required taskId}) {},
        onNewTask: onNewTask ?? () {},
      ),
    );
  }

  group("Scheduled page", () {
    testWidgets("shows only Recurring when no task runs one time", (tester) async {
      await pumpList(
        tester: tester,
        tasks: ScheduledTaskSuccess(value: [_recurring]),
      );
      expect(find.text("Recurring"), findsOneWidget);
      expect(find.text("Once"), findsNothing);
      expect(find.byKey(const ValueKey("scheduled-task-switch-daily")), findsOneWidget);
    });

    testWidgets("shows only Once when every task runs one time", (tester) async {
      await pumpList(
        tester: tester,
        tasks: ScheduledTaskSuccess(value: [_once]),
      );
      expect(find.text("Recurring"), findsNothing);
      expect(find.text("Once"), findsOneWidget);
      expect(find.byKey(const ValueKey("scheduled-task-switch-once")), findsNothing);
    });

    testWidgets("lists Recurring above Once", (tester) async {
      await pumpList(
        tester: tester,
        tasks: ScheduledTaskSuccess(value: [_once, _recurring]),
      );
      expect(tester.getTopLeft(find.text("Recurring")).dy, lessThan(tester.getTopLeft(find.text("Once")).dy));
    });

    testWidgets("says so when the computer has no tasks", (tester) async {
      await pumpList(
        tester: tester,
        tasks: const ScheduledTaskSuccess(value: []),
      );
      expect(find.byKey(const Key("scheduled-tasks-empty")), findsOneWidget);
      expect(find.text("Recurring"), findsNothing);
      expect(find.text("Once"), findsNothing);
    });

    testWidgets("asks to update an older computer", (tester) async {
      await pumpList(tester: tester, tasks: const ScheduledTaskBridgeOutdated());
      expect(find.text("Update this computer to schedule tasks"), findsOneWidget);
    });

    testWidgets("the + opens New task", (tester) async {
      var opened = 0;
      await pumpList(
        tester: tester,
        tasks: ScheduledTaskSuccess(value: [_recurring]),
        onNewTask: () => opened++,
      );
      await tester.tap(find.byKey(const Key("scheduled-tasks-new")));
      expect(opened, 1);
    });

    testWidgets("names no zone for a paused never-run task in the device's zone", (tester) async {
      await pumpList(
        tester: tester,
        tasks: ScheduledTaskSuccess(value: [scheduledTaskFixture(id: "paused", enabled: false)]),
      );
      expect(find.text("Every day at 9:00\u202FAM"), findsOneWidget);
    });

    testWidgets("names the zone of a paused never-run task in another zone", (tester) async {
      await pumpList(
        tester: tester,
        tasks: ScheduledTaskSuccess(value: [scheduledTaskFixture(id: "paused", enabled: false)]),
        deviceTimeZone: "Europe/Bucharest",
      );
      expect(find.text("Every day at 9:00\u202FAM (UTC)"), findsOneWidget);
    });

    testWidgets("the + on an older computer says how to update it", (tester) async {
      var opened = 0;
      await pumpList(tester: tester, tasks: const ScheduledTaskBridgeOutdated(), onNewTask: () => opened++);
      await tester.tap(find.byKey(const Key("scheduled-tasks-new")));
      await tester.pumpAndSettle();
      expect(find.text("Update Sesori Bridge"), findsOneWidget);
      expect(opened, 0);
    });
  });

  group("Task page", () {
    Future<void> pumpTask({
      required WidgetTester tester,
      required ScheduledTask task,
      VoidCallback? onEdit,
      List<ScheduledTaskRun> runs = const [],
      List<ProjectSummary> projects = const [],
      OpenScheduledTaskRunSession? onOpenSession,
    }) {
      when(() => repository.listTasks()).thenAnswer((_) async => ScheduledTaskSuccess(value: [task]));
      when(() => repository.listRuns(taskId: task.id)).thenAnswer((_) async => ScheduledTaskSuccess(value: runs));
      return pump(
        tester: tester,
        projects: projects,
        child: ScheduledTaskDetailView(
          createCubit: () => ScheduledTaskDetailCubit(
            repository: repository,
            connectionService: connection,
            timeZoneSource: _FixedTimeZoneSource(zone: "UTC"),
            taskId: task.id,
          ),
          onBack: () {},
          onDeleted: () {},
          onEdit: onEdit ?? () {},
          onOpenSession: onOpenSession ?? ({required projectId, required projectName, required sessionId}) {},
        ),
      );
    }

    Finder runRow({required String id}) => find.byKey(ValueKey("scheduled-task-run-$id"));
    Finder arrowIn({required String id}) => find.descendant(
      of: runRow(id: id),
      matching: find.byIcon(TablerRegular.chevron_right),
    );

    testWidgets("the command a task runs first shows read-only, and a task without one has no row", (tester) async {
      await pumpTask(
        tester: tester,
        task: scheduledTaskFixture(id: "with", command: "git fetch --prune"),
      );
      expect(find.text("Runs first"), findsOneWidget);
      expect(find.text("git fetch --prune"), findsOneWidget);

      await pumpTask(
        tester: tester,
        task: scheduledTaskFixture(id: "without"),
      );
      expect(find.text("Runs first"), findsNothing);
    });

    testWidgets("a run opens its session in the project it is in, even after the task moved away", (tester) async {
      final opened = <(String, String?, String)>[];
      await pumpTask(
        tester: tester,
        task: _recurring,
        runs: [
          _run(
            id: "ran",
            outcome: const ScheduledTaskRunOutcome.started(
              session: ScheduledTaskRunSession(id: "s1", projectId: "old-project"),
              late: false,
            ),
          ),
        ],
        projects: const [
          ProjectSummary(id: "fixture-project", name: "Sesori", path: "/code/sesori", time: null),
          ProjectSummary(id: "old-project", name: "Website", path: "/code/website", time: null),
        ],
        onOpenSession: ({required projectId, required projectName, required sessionId}) =>
            opened.add((projectId, projectName, sessionId)),
      );
      expect(arrowIn(id: "ran"), findsOneWidget);
      await tester.tap(runRow(id: "ran"));
      expect(opened, [("old-project", "Website", "s1")]);
    });

    testWidgets("a run whose session was deleted has no arrow and says so when tapped", (tester) async {
      var opened = 0;
      await pumpTask(
        tester: tester,
        task: _recurring,
        runs: [
          _run(
            id: "gone",
            outcome: const ScheduledTaskRunOutcome.started(session: null, late: false),
          ),
        ],
        onOpenSession: ({required projectId, required projectName, required sessionId}) => opened++,
      );
      expect(arrowIn(id: "gone"), findsNothing);
      await tester.tap(runRow(id: "gone"));
      await tester.pump();
      expect(find.text("This run’s session was deleted."), findsOneWidget);
      expect(opened, 0);
      await tester.pumpAndSettle(const Duration(seconds: 10));
    });

    testWidgets("a failed run names what it tried to use, not what the task names now", (tester) async {
      var edits = 0;
      // The task was edited after the run, so it names another model now.
      final task = _recurring.copyWith(
        definition: _recurring.definition.copyWith(
          pluginId: Harness.claude.name,
          model: const PromptModel(providerID: "anthropic", modelID: "claude-new"),
        ),
      );
      await pumpTask(
        tester: tester,
        task: task,
        onEdit: () => edits++,
        runs: [
          _run(
            id: "failed",
            outcome: const ScheduledTaskRunOutcome.failed(
              reason: TaskRunFailureReason.modelUnavailable,
              attempt: ScheduledTaskRunAttempt(
                pluginId: "claude",
                model: PromptModel(providerID: "anthropic", modelID: "claude-old"),
                projectPath: "/code/sesori",
              ),
            ),
          ),
          _run(id: "skipped", outcome: const ScheduledTaskRunOutcome.skipped()),
        ],
      );
      expect(find.text("Couldn’t start: its model isn’t offered anymore"), findsOneWidget);
      expect(arrowIn(id: "failed"), findsOneWidget);
      expect(arrowIn(id: "skipped"), findsNothing);

      await tester.tap(runRow(id: "failed"));
      await tester.pumpAndSettle();
      expect(find.text("Claude Code didn’t offer claude-old anymore."), findsOneWidget);
      expect(find.textContaining("claude-new"), findsNothing);
      expect(find.text("Pick another model in the task editor."), findsOneWidget);

      await tester.tap(find.byKey(const Key("scheduled-task-run-failure-edit")));
      await tester.pumpAndSettle();
      expect(edits, 1);
      expect(find.text("Claude Code didn’t offer claude-old anymore."), findsNothing);
    });

    testWidgets("a run that didn't start offers no editor", (tester) async {
      await pumpTask(
        tester: tester,
        task: _recurring,
        runs: [
          _run(
            id: "failed",
            outcome: const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.startFailed, attempt: null),
          ),
        ],
      );
      await tester.tap(runRow(id: "failed"));
      await tester.pumpAndSettle();
      expect(find.text("Run now tries again."), findsOneWidget);
      expect(find.byKey(const Key("scheduled-task-run-failure-edit")), findsNothing);
      await tester.tap(find.byKey(const Key("scheduled-task-run-failure-close")));
      await tester.pumpAndSettle();
      expect(find.text("Run now tries again."), findsNothing);
    });

    testWidgets("Run now spins until the run starts, and a second tap meanwhile says so", (tester) async {
      final answer = Completer<ScheduledTaskResult<ScheduledTaskRun>>();
      when(() => repository.runNow(taskId: _recurring.id)).thenAnswer((_) => answer.future);
      await pumpTask(tester: tester, task: _recurring);
      final runNow = find.byKey(const Key("scheduled-task-run-now"));
      Finder spinner() => find.descendant(of: runNow, matching: find.byType(PregoActivityIndicator));
      final rowSize = tester.getSize(runNow);

      await tester.tap(runNow);
      await tester.pump(const Duration(milliseconds: 300));
      expect(spinner(), findsOneWidget);
      expect(find.descendant(of: runNow, matching: find.byIcon(TablerRegular.player_play)), findsNothing);
      expect(tester.getSize(runNow), rowSize);

      await tester.tap(runNow);
      await tester.pump();
      expect(find.text("Already starting the run…"), findsOneWidget);
      verify(() => repository.runNow(taskId: _recurring.id)).called(1);

      answer.complete(
        ScheduledTaskSuccess(
          value: _run(id: "now", outcome: const ScheduledTaskRunOutcome.started(session: null, late: false)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("Run started"), findsOneWidget);
      expect(spinner(), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 10));
    });

    testWidgets("offers Edit and Rename for a task this app can edit", (tester) async {
      var edits = 0;
      await pumpTask(tester: tester, task: _recurring, onEdit: () => edits++);
      expect(find.byKey(const Key("scheduled-task-rename")), findsOneWidget);
      expect(find.byKey(const Key("scheduled-task-read-only")), findsNothing);
      await tester.tap(find.byKey(const Key("scheduled-task-edit")));
      expect(edits, 1);
    });

    testWidgets("shows a task from a newer app read-only, still runnable and deletable", (tester) async {
      await pumpTask(
        tester: tester,
        task: scheduledTaskFixture(id: "newer", schedule: const TaskSchedule.unknown()),
      );
      expect(find.byKey(const Key("scheduled-task-read-only")), findsOneWidget);
      expect(find.byKey(const Key("scheduled-task-rename")), findsNothing);
      expect(find.byKey(const Key("scheduled-task-edit")), findsNothing);
      expect(find.byKey(const Key("scheduled-task-run-now")), findsOneWidget);
      expect(find.byKey(const Key("scheduled-task-delete")), findsOneWidget);
    });
  });
}
