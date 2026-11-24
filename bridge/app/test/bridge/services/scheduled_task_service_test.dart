import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/services/scheduled_task_occurrence_calculator.dart";
import "package:sesori_bridge/src/services/scheduled_task_request_exception.dart";
import "package:sesori_bridge/src/services/scheduled_task_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:timezone/data/latest_all.dart" as tz_data;

import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";
import "../../helpers/arming_test_support.dart";

void main() {
  setUpAll(tz_data.initializeTimeZones);

  late AppDatabase db;
  late ScheduledTaskRepository repository;
  late FakeSessionRepository sessionRepository;
  late ScheduledTaskService service;
  late RecordingArmingMutations mutations;
  late DateTime now;
  late int changeCount;

  // Bucharest is UTC+2 in November, so 09:00 there is 07:00 UTC.
  const bucharestOffset = 120;
  const definition = ScheduledTaskDefinition(
    name: "Morning summary",
    prompt: ScheduledTaskPrompt.text(text: "Summarize yesterday"),
    projectId: "/repo",
    pluginId: "fake",
    agent: null,
    model: null,
    variant: null,
    fastMode: false,
    dedicatedWorktree: false,
    schedule: TaskSchedule.daily(time: TaskTimeOfDay(hour: 9, minute: 0)),
    timeZone: "Europe/Bucharest",
    missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
    runMode: TaskRunMode.sameSession(autoCompact: false),
    approvalMode: TaskApprovalMode.ask,
  );

  setUp(() {
    db = createTestDatabase();
    addTearDown(db.close);
    now = DateTime.utc(2026, 11, 15, 10);
    repository = ScheduledTaskRepository(dao: ScheduledTaskDao(database: db));
    sessionRepository = FakeSessionRepository(plugin: FakeBridgePlugin())..projectPathResult = "/repo";
    mutations = RecordingArmingMutations();
    service = ScheduledTaskService(
      mutations: mutations,
      repository: repository,
      sessionRepository: sessionRepository,
      calculator: const ScheduledTaskOccurrenceCalculator(),
      clock: Clock(() => now),
    );
    addTearDown(service.dispose);
    changeCount = 0;
    service.changes.listen((_) => changeCount++);
  });

  Future<void> flushChanges() => Future<void>.delayed(Duration.zero);

  Future<ScheduledTaskErrorCode?> refusalOf(Future<Object?> Function() action) async {
    try {
      await action();
      return null;
    } on ScheduledTaskRequestException catch (error) {
      return error.code;
    }
  }

  Future<void> targetSession({required String taskId}) async {
    await insertTestSession(
      db: db,
      sessionId: "s1",
      backendSessionId: "backend-s1",
      pluginId: "fake",
      projectId: "/repo",
      isDedicated: false,
      createdAt: 1,
      worktreePath: null,
      baseBranch: null,
      baseCommit: null,
      agent: null,
      agentModel: null,
    );
    await db.customStatement("UPDATE scheduled_tasks SET target_session_id = 's1' WHERE id = ?", [taskId]);
  }

  test("create stores an enabled task due at its first time after now, in its zone", () async {
    final task = await service.create(definition: definition);
    await flushChanges();

    expect(task.enabled, isTrue);
    expect(
      task.nextRunAt,
      ScheduledTaskInstant(at: DateTime.utc(2026, 11, 16, 7).millisecondsSinceEpoch, offsetMinutes: bucharestOffset),
    );
    expect(task.lastRun, isNull);
    expect(changeCount, 1);
    expect((await service.list()).items, [task]);
  });

  test("a one-off task is due at its own time", () async {
    final task = await service.create(
      definition: definition.copyWith(
        schedule: const TaskSchedule.once(
          at: TaskLocalDateTime(year: 2026, month: 11, day: 15, hour: 13, minute: 0),
        ),
      ),
    );

    expect(task.nextRunAt?.at, DateTime.utc(2026, 11, 15, 11).millisecondsSinceEpoch);
  });

  group("create refuses", () {
    final cases = <String, (ScheduledTaskDefinition, ScheduledTaskErrorCode)>{
      "a blank name": (definition.copyWith(name: "  "), ScheduledTaskErrorCode.emptyName),
      "a blank prompt": (
        definition.copyWith(prompt: const ScheduledTaskPrompt.text(text: " \n")),
        ScheduledTaskErrorCode.emptyPrompt,
      ),
      "a command without a name": (
        definition.copyWith(
          prompt: const ScheduledTaskPrompt.command(name: "", source: CommandSource.command, arguments: null),
        ),
        ScheduledTaskErrorCode.emptyPrompt,
      ),
      "a prompt kind it does not know": (
        definition.copyWith(prompt: const ScheduledTaskPrompt.unknown()),
        ScheduledTaskErrorCode.unsupportedByBridge,
      ),
      "a schedule kind it does not know": (
        definition.copyWith(schedule: const TaskSchedule.unknown()),
        ScheduledTaskErrorCode.unsupportedByBridge,
      ),
      "a run mode it does not know": (
        definition.copyWith(runMode: const TaskRunMode.unknown()),
        ScheduledTaskErrorCode.unsupportedByBridge,
      ),
      "an approval mode it does not know": (
        definition.copyWith(approvalMode: TaskApprovalMode.unknown),
        ScheduledTaskErrorCode.unsupportedByBridge,
      ),
      "an unknown zone": (definition.copyWith(timeZone: "Mars/Olympus"), ScheduledTaskErrorCode.unknownTimeZone),
      "an unknown harness": (definition.copyWith(pluginId: "missing"), ScheduledTaskErrorCode.unknownHarness),
      "more than 12 hours between runs": (
        definition.copyWith(
          schedule: const TaskSchedule.everyHours(
            hours: 13,
            start: TaskLocalDateTime(year: 2026, month: 11, day: 15, hour: 8, minute: 0),
          ),
        ),
        ScheduledTaskErrorCode.hoursOutOfRange,
      ),
      "no hours between runs": (
        definition.copyWith(
          schedule: const TaskSchedule.everyHours(
            hours: 0,
            start: TaskLocalDateTime(year: 2026, month: 11, day: 15, hour: 8, minute: 0),
          ),
        ),
        ScheduledTaskErrorCode.hoursOutOfRange,
      ),
      "a day the month does not have": (
        definition.copyWith(
          schedule: const TaskSchedule.once(
            at: TaskLocalDateTime(year: 2027, month: 2, day: 29, hour: 8, minute: 0),
          ),
        ),
        ScheduledTaskErrorCode.invalidSchedule,
      ),
      "a year DateTime cannot hold": (
        definition.copyWith(
          schedule: const TaskSchedule.once(
            at: TaskLocalDateTime(year: 300000, month: 1, day: 1, hour: 8, minute: 0),
          ),
        ),
        ScheduledTaskErrorCode.invalidSchedule,
      ),
      "an hour past 23": (
        definition.copyWith(schedule: const TaskSchedule.daily(time: TaskTimeOfDay(hour: 24, minute: 0))),
        ScheduledTaskErrorCode.invalidSchedule,
      ),
      "a weekly schedule without days": (
        definition.copyWith(
          schedule: const TaskSchedule.weekly(days: {}, time: TaskTimeOfDay(hour: 9, minute: 0)),
        ),
        ScheduledTaskErrorCode.invalidSchedule,
      ),
      "a one-off time that has passed": (
        definition.copyWith(
          schedule: const TaskSchedule.once(
            at: TaskLocalDateTime(year: 2026, month: 11, day: 15, hour: 12, minute: 0),
          ),
        ),
        ScheduledTaskErrorCode.onceTimeInPast,
      ),
    };
    for (final MapEntry(key: description, value: (invalid, code)) in cases.entries) {
      test(description, () async {
        expect(await refusalOf(() => service.create(definition: invalid)), code);
        await flushChanges();
        expect((await service.list()).items, isEmpty);
        expect(changeCount, 0);
      });
    }

    test("a project it does not know", () async {
      sessionRepository.projectPathResult = null;
      expect(await refusalOf(() => service.create(definition: definition)), ScheduledTaskErrorCode.unknownProject);
    });
  });

  test("pausing clears the next time and resuming computes it from now", () async {
    final task = await service.create(definition: definition);

    final paused = await service.setEnabled(taskId: task.id, enabled: false);
    expect(paused.enabled, isFalse);
    expect(paused.nextRunAt, isNull);

    now = DateTime.utc(2026, 11, 20, 8);
    final resumed = await service.setEnabled(taskId: task.id, enabled: true);
    expect(resumed.nextRunAt?.at, DateTime.utc(2026, 11, 21, 7).millisecondsSinceEpoch);
    await flushChanges();
    expect(changeCount, 3);
  });

  test("setting the enabled state it already has changes nothing", () async {
    final task = await service.create(definition: definition);
    now = DateTime.utc(2026, 11, 17, 12);

    final unchanged = await service.setEnabled(taskId: task.id, enabled: true);
    await flushChanges();
    expect(unchanged.nextRunAt, task.nextRunAt);
    expect(changeCount, 1);
  });

  test("an edit recomputes the next time, and a paused task stays paused", () async {
    final task = await service.create(definition: definition);
    final later = definition.copyWith(schedule: const TaskSchedule.daily(time: TaskTimeOfDay(hour: 13, minute: 0)));

    final edited = await service.update(taskId: task.id, definition: later);
    expect(edited.definition, later);
    expect(edited.nextRunAt?.at, DateTime.utc(2026, 11, 15, 11).millisecondsSinceEpoch);

    await service.setEnabled(taskId: task.id, enabled: false);
    final pausedEdit = await service.update(taskId: task.id, definition: definition);
    expect(pausedEdit.enabled, isFalse);
    expect(pausedEdit.nextRunAt, isNull);
  });

  group("a same-session task's session", () {
    Future<String?> targetOf({required String taskId}) async => (await repository.get(taskId: taskId))?.targetSessionId;

    test("survives an edit that keeps where it runs", () async {
      final task = await service.create(definition: definition);
      await targetSession(taskId: task.id);

      await service.update(
        taskId: task.id,
        definition: definition.copyWith(name: "Renamed", fastMode: true),
      );
      expect(await targetOf(taskId: task.id), "s1");
    });

    final moves = <String, ScheduledTaskDefinition>{
      "project": definition.copyWith(projectId: "/other"),
      "harness": definition.copyWith(pluginId: "fake-2"),
      "worktree switch": definition.copyWith(dedicatedWorktree: true),
      "run mode": definition.copyWith(runMode: const TaskRunMode.newSession()),
    };
    for (final MapEntry(key: field, value: moved) in moves.entries) {
      test("is cleared by a $field change", () async {
        final task = await service.create(definition: definition);
        await targetSession(taskId: task.id);
        sessionRepository.eligiblePluginIds = {"fake", "fake-2"};

        await service.update(taskId: task.id, definition: moved);
        expect(await targetOf(taskId: task.id), isNull);
        // The session it no longer continues in loses its arming.
        expect(mutations.armedSessionIds, ["s1"]);
      });
    }

    test("hears of each edit, pause, resume and delete as its arming", () async {
      final task = await service.create(definition: definition);
      expect(mutations.armedSessionIds, isEmpty);
      await targetSession(taskId: task.id);

      await service.update(
        taskId: task.id,
        definition: definition.copyWith(name: "Renamed"),
      );
      await service.setEnabled(taskId: task.id, enabled: false);
      await service.setEnabled(taskId: task.id, enabled: true);
      await service.delete(taskId: task.id);

      expect(mutations.armedSessionIds, ["s1", "s1", "s1", "s1"]);
    });
  });

  test("the list shows each task's newest run and leaves out done one-off tasks", () async {
    final recurring = await service.create(definition: definition);
    final run = await repository.recordRun(
      taskId: recurring.id,
      scheduledFor: const ScheduledTaskInstant(at: 1, offsetMinutes: bucharestOffset),
      outcome: const ScheduledTaskRunOutcome.skipped(),
      firedAt: now,
    );
    final done = await service.create(definition: definition.copyWith(name: "Done"));
    await db.customStatement("UPDATE scheduled_tasks SET completed_at = 1 WHERE id = ?", [done.id]);

    final items = (await service.list()).items;
    expect(items.map((task) => task.id), [recurring.id]);
    expect(items.single.lastRun, run);
    expect(
      await refusalOf(() => service.update(taskId: done.id, definition: definition)),
      ScheduledTaskErrorCode.taskNotFound,
    );
    expect((await service.listRuns(taskId: done.id)).items, isEmpty);
  });

  test("deleting a task removes it, and a missing task is refused", () async {
    final task = await service.create(definition: definition);

    await service.delete(taskId: task.id);
    await flushChanges();
    expect((await service.list()).items, isEmpty);
    expect(changeCount, 2);

    expect(await refusalOf(() => service.delete(taskId: task.id)), ScheduledTaskErrorCode.taskNotFound);
    expect(await refusalOf(() => service.listRuns(taskId: task.id)), ScheduledTaskErrorCode.taskNotFound);
    expect(
      await refusalOf(() => service.setEnabled(taskId: task.id, enabled: false)),
      ScheduledTaskErrorCode.taskNotFound,
    );
  });
}
