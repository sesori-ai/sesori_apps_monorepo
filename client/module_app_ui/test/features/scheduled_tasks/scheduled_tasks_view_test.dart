import "dart:async";

import "package:flutter_test/flutter_test.dart";
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

  Future<void> pump({required WidgetTester tester, required Widget child}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpList({required WidgetTester tester, required ScheduledTaskResult<List<ScheduledTask>> tasks}) {
    when(() => repository.listTasks()).thenAnswer((_) async => tasks);
    return pump(
      tester: tester,
      child: ScheduledTasksView(
        createCubit: () => ScheduledTasksCubit(repository: repository, connectionService: connection),
        exit: ScheduledPageExit.back,
        onExit: () {},
        onOpenTask: ({required taskId}) {},
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
  });

  group("Task page", () {
    Future<void> pumpTask({required WidgetTester tester, required ScheduledTask task}) {
      when(() => repository.listTasks()).thenAnswer((_) async => ScheduledTaskSuccess(value: [task]));
      when(() => repository.listRuns(taskId: task.id)).thenAnswer((_) async => const ScheduledTaskSuccess(value: []));
      return pump(
        tester: tester,
        child: ScheduledTaskDetailView(
          createCubit: () =>
              ScheduledTaskDetailCubit(repository: repository, connectionService: connection, taskId: task.id),
          onBack: () {},
          onDeleted: () {},
        ),
      );
    }

    testWidgets("offers Rename for a task this app can edit", (tester) async {
      await pumpTask(tester: tester, task: _recurring);
      expect(find.byKey(const Key("scheduled-task-rename")), findsOneWidget);
      expect(find.byKey(const Key("scheduled-task-read-only")), findsNothing);
    });

    testWidgets("shows a task from a newer app read-only, still runnable and deletable", (tester) async {
      await pumpTask(
        tester: tester,
        task: scheduledTaskFixture(id: "newer", schedule: const TaskSchedule.unknown()),
      );
      expect(find.byKey(const Key("scheduled-task-read-only")), findsOneWidget);
      expect(find.byKey(const Key("scheduled-task-rename")), findsNothing);
      expect(find.byKey(const Key("scheduled-task-run-now")), findsOneWidget);
      expect(find.byKey(const Key("scheduled-task-delete")), findsOneWidget);
    });
  });
}
