import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_database.dart";

void main() {
  late AppDatabase db;
  late ScheduledTaskRepository repository;
  final now = DateTime.utc(2026, 11, 15, 10);

  const definition = ScheduledTaskDefinition(
    name: "Nightly review",
    prompt: ScheduledTaskPrompt.command(name: "review", source: CommandSource.skill, arguments: "--all"),
    projectId: "/repo",
    pluginId: "fake",
    agent: "build",
    model: PromptModel(providerID: "anthropic", modelID: "claude"),
    variant: SessionVariant(id: "high"),
    fastMode: true,
    dedicatedWorktree: true,
    schedule: TaskSchedule.weekly(
      days: {TaskWeekday.monday, TaskWeekday.friday},
      time: TaskTimeOfDay(hour: 9, minute: 30),
    ),
    timeZone: "Europe/Bucharest",
    missedRunPolicy: TaskMissedRunPolicy.waitForNext,
    runMode: TaskRunMode.sameSession(autoCompact: true),
    approvalMode: TaskApprovalMode.approveAll,
  );

  setUp(() {
    db = createTestDatabase();
    addTearDown(db.close);
    repository = ScheduledTaskRepository(dao: ScheduledTaskDao(database: db));
  });

  Future<String> recordRun({
    required String taskId,
    required ScheduledTaskRunOutcome outcome,
    required int minute,
  }) async {
    final run = await repository.recordRun(
      taskId: taskId,
      scheduledFor: ScheduledTaskInstant(at: minute, offsetMinutes: 120),
      outcome: outcome,
      firedAt: now.add(Duration(minutes: minute)),
    );
    return run.id;
  }

  test("a stored task reads back with the same definition and bridge state", () async {
    final dueAt = DateTime.utc(2026, 11, 16, 7, 30);
    final created = await repository.create(definition: definition, nextDueAt: dueAt, now: now);

    final read = await repository.get(taskId: created.id);
    expect(read?.definition, definition);
    expect(read?.enabled, isTrue);
    expect(read?.nextDueAt, dueAt);
    expect(read?.targetSessionId, isNull);
    expect(read?.completedAt, isNull);
    expect(read?.updatedAt, now);
    expect((await repository.listUncompleted()).map((task) => task.id), [created.id]);
  });

  test("run history keeps the newest rows, newest first, with their outcomes", () async {
    final task = await repository.create(definition: definition, nextDueAt: null, now: now);
    await recordRun(
      taskId: task.id,
      outcome: const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.modelUnavailable),
      minute: 1,
    );
    await recordRun(
      taskId: task.id,
      outcome: const ScheduledTaskRunOutcome.started(sessionId: null, late: true),
      minute: 2,
    );

    final runs = await repository.listRuns(taskId: task.id);
    expect(runs.map((run) => run.outcome), [
      const ScheduledTaskRunOutcome.started(sessionId: null, late: true),
      const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.modelUnavailable),
    ]);
    expect(runs.first.scheduledFor, const ScheduledTaskInstant(at: 2, offsetMinutes: 120));
    expect((await repository.latestRuns(taskIds: {task.id}))[task.id], runs.first);
  });

  test("trimming never deletes the newest started run, however many skips follow it", () async {
    final task = await repository.create(definition: definition, nextDueAt: null, now: now);
    final startedId = await recordRun(
      taskId: task.id,
      outcome: const ScheduledTaskRunOutcome.started(sessionId: null, late: false),
      minute: 0,
    );
    final skippedIds = [
      for (var minute = 1; minute <= 25; minute++)
        await recordRun(taskId: task.id, outcome: const ScheduledTaskRunOutcome.skipped(), minute: minute),
    ];

    final kept = (await repository.listRuns(taskId: task.id)).map((run) => run.id).toList();
    expect(kept, [...skippedIds.reversed.take(ScheduledTaskRepository.runHistoryLimit), startedId]);
  });

  test("trimming drops an older started run once a newer one exists", () async {
    final task = await repository.create(definition: definition, nextDueAt: null, now: now);
    final olderStartedId = await recordRun(
      taskId: task.id,
      outcome: const ScheduledTaskRunOutcome.started(sessionId: null, late: false),
      minute: 0,
    );
    for (var minute = 1; minute <= 20; minute++) {
      await recordRun(taskId: task.id, outcome: const ScheduledTaskRunOutcome.missed(), minute: minute);
    }
    await recordRun(
      taskId: task.id,
      outcome: const ScheduledTaskRunOutcome.started(sessionId: null, late: false),
      minute: 21,
    );

    final kept = (await repository.listRuns(taskId: task.id)).map((run) => run.id);
    expect(kept, hasLength(ScheduledTaskRepository.runHistoryLimit));
    expect(kept, isNot(contains(olderStartedId)));
  });

  test("trimming one task's history leaves other tasks' rows alone", () async {
    final first = await repository.create(definition: definition, nextDueAt: null, now: now);
    final second = await repository.create(definition: definition, nextDueAt: null, now: now);
    await recordRun(taskId: second.id, outcome: const ScheduledTaskRunOutcome.skipped(), minute: 0);
    for (var minute = 1; minute <= 25; minute++) {
      await recordRun(taskId: first.id, outcome: const ScheduledTaskRunOutcome.skipped(), minute: minute);
    }

    expect(await repository.listRuns(taskId: second.id), hasLength(1));
  });
}
