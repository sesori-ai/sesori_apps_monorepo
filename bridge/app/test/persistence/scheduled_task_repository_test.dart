import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/models/scheduled_task_record.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";
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

  test("a task completed meanwhile is neither edited nor re-enabled", () async {
    final task = await repository.create(definition: definition, nextDueAt: null, now: now);
    await db.customStatement("UPDATE scheduled_tasks SET completed_at = 1 WHERE id = ?", [task.id]);

    final edited = await repository.updateDefinition(
      taskId: task.id,
      definition: definition.copyWith(name: "Renamed"),
      nextDueAt: null,
      clearTarget: false,
      now: now,
    );
    final enabled = await repository.setEnabled(taskId: task.id, enabled: false, nextDueAt: null, now: now);

    expect(edited, isNull);
    expect(enabled, isNull);
    expect((await repository.get(taskId: task.id))?.definition.name, definition.name);
  });

  test("tasks follow their project when it is merged into another", () async {
    final task = await repository.create(definition: definition, nextDueAt: null, now: now);

    await ScheduledTaskDao(database: db).moveTasksToProject(fromProjectIds: {"/repo"}, toProjectId: "/survivor");

    expect((await repository.get(taskId: task.id))?.definition.projectId, "/survivor");
  });

  test("run history keeps the newest rows, newest first, with their outcomes", () async {
    final task = await repository.create(definition: definition, nextDueAt: null, now: now);
    const failed = ScheduledTaskRunOutcome.failed(
      reason: TaskRunFailureReason.modelUnavailable,
      attempt: ScheduledTaskRunAttempt(
        pluginId: "claude",
        model: PromptModel(providerID: "anthropic", modelID: "opus"),
        projectPath: "/repo",
      ),
    );
    await recordRun(
      taskId: task.id,
      outcome: failed,
      minute: 1,
    );
    await recordRun(
      taskId: task.id,
      outcome: const ScheduledTaskRunOutcome.started(sessionId: null, projectId: null, late: true),
      minute: 2,
    );

    final runs = await repository.listRuns(taskId: task.id);
    expect(runs.map((run) => run.outcome), [
      const ScheduledTaskRunOutcome.started(sessionId: null, projectId: null, late: true),
      failed,
    ]);
    expect(runs.first.scheduledFor, const ScheduledTaskInstant(at: 2, offsetMinutes: 120));
    expect((await repository.latestRuns(taskIds: {task.id}))[task.id], runs.first);
  });

  test("trimming never deletes the newest started run, however many skips follow it", () async {
    final task = await repository.create(definition: definition, nextDueAt: null, now: now);
    final startedId = await recordRun(
      taskId: task.id,
      outcome: const ScheduledTaskRunOutcome.started(sessionId: null, projectId: null, late: false),
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
      outcome: const ScheduledTaskRunOutcome.started(sessionId: null, projectId: null, late: false),
      minute: 0,
    );
    for (var minute = 1; minute <= 20; minute++) {
      await recordRun(taskId: task.id, outcome: const ScheduledTaskRunOutcome.missed(), minute: minute);
    }
    await recordRun(
      taskId: task.id,
      outcome: const ScheduledTaskRunOutcome.started(sessionId: null, projectId: null, late: false),
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

  test("a fire reserves its run only against the task as it was read", () async {
    final dueAt = DateTime.utc(2026, 11, 16, 7, 30);
    final read = await repository.create(definition: definition, nextDueAt: dueAt, now: now);
    await repository.setEnabled(
      taskId: read.id,
      enabled: false,
      nextDueAt: null,
      now: now.add(const Duration(seconds: 1)),
    );

    Future<ScheduledTaskRun?> reserve({required ScheduledTaskRecord task}) => repository.reserveRun(
      task: task,
      nextDueAt: dueAt.add(const Duration(days: 3)),
      completedAt: null,
      scheduledFor: ScheduledTaskInstant(at: dueAt.millisecondsSinceEpoch, offsetMinutes: 120),
      outcome: const ScheduledTaskRunOutcome.started(sessionId: null, projectId: null, late: false),
      firedAt: dueAt,
    );

    expect(await reserve(task: read), isNull);
    expect(await repository.listRuns(taskId: read.id), isEmpty);
    expect((await repository.get(taskId: read.id))?.nextDueAt, isNull);

    final current = await repository.get(taskId: read.id);
    expect(await reserve(task: current ?? fail("task is gone")), isNotNull);
    expect((await repository.get(taskId: read.id))?.nextDueAt, dueAt.add(const Duration(days: 3)));
  });

  group("scheduled run sessions", () {
    Future<void> runSession({required String sessionId, required String? taskId, String projectId = "/repo"}) async {
      await recordSessionBinding(
        database: db,
        sessionId: sessionId,
        backendSessionId: "backend_$sessionId",
        pluginId: "fake",
        projectId: projectId,
        parentSessionId: null,
      );
      if (taskId != null) {
        await db.sessionDao.setScheduledRun(
          sessionId: sessionId,
          scheduledTaskId: taskId,
          approvalOverride: SessionApprovalMode.ask,
        );
      }
    }

    Future<String> startedRun({required String taskId, required String sessionId, required int minute}) async {
      final runId = await recordRun(
        taskId: taskId,
        outcome: const ScheduledTaskRunOutcome.started(sessionId: null, projectId: null, late: false),
        minute: minute,
      );
      await repository.setRunSession(runId: runId, sessionId: sessionId);
      return runId;
    }

    test("marks name each run session's task and whether it repeats, in one read", () async {
      final recurring = await repository.create(definition: definition, nextDueAt: null, now: now);
      final once = await repository.create(
        definition: definition.copyWith(
          name: "Release notes",
          schedule: const TaskSchedule.once(
            at: TaskLocalDateTime(year: 2026, month: 11, day: 20, hour: 9, minute: 0),
          ),
        ),
        nextDueAt: null,
        now: now,
      );
      await runSession(sessionId: "ses_recurring", taskId: recurring.id);
      await runSession(sessionId: "ses_once", taskId: once.id);
      await runSession(sessionId: "ses_plain", taskId: null);

      expect(await repository.marksOfSessions(sessionIds: {"ses_recurring", "ses_once", "ses_plain", "ses_gone"}), {
        "ses_recurring": SessionScheduledTaskMark(
          taskId: recurring.id,
          name: "Nightly review",
          kind: ScheduledTaskKind.recurring,
        ),
        "ses_once": SessionScheduledTaskMark(taskId: once.id, name: "Release notes", kind: ScheduledTaskKind.once),
      });
    });

    test("a started run names the project its session is in, even after the task moved away", () async {
      final task = await repository.create(definition: definition, nextDueAt: null, now: now);
      await runSession(sessionId: "ses_1", taskId: task.id, projectId: "/elsewhere");
      await startedRun(taskId: task.id, sessionId: "ses_1", minute: 1);
      await recordRun(
        taskId: task.id,
        outcome: const ScheduledTaskRunOutcome.started(sessionId: null, projectId: null, late: false),
        minute: 2,
      );

      final runs = await repository.listRuns(taskId: task.id);
      expect(runs.map((run) => run.outcome), [
        const ScheduledTaskRunOutcome.started(sessionId: null, projectId: null, late: false),
        const ScheduledTaskRunOutcome.started(sessionId: "ses_1", projectId: "/elsewhere", late: false),
      ]);
    });

    test("a run is unattended until the user prompts its session, and each new run starts unattended", () async {
      final task = await repository.create(definition: definition, nextDueAt: null, now: now);
      await runSession(sessionId: "ses_1", taskId: task.id);
      expect(await repository.isUnattendedRun(sessionId: "ses_1"), isFalse, reason: "no run went to it yet");

      await startedRun(taskId: task.id, sessionId: "ses_1", minute: 1);
      expect(await repository.isUnattendedRun(sessionId: "ses_1"), isTrue);

      await repository.recordUserPrompted(sessionId: "ses_1", at: now);
      expect(await repository.isUnattendedRun(sessionId: "ses_1"), isFalse);

      final nextRunId = await startedRun(taskId: task.id, sessionId: "ses_1", minute: 2);
      expect(await repository.isUnattendedRun(sessionId: "ses_1"), isTrue);

      await repository.recordUserPrompted(sessionId: "ses_1", at: now.add(const Duration(minutes: 3)));
      await repository.recordUserPrompted(sessionId: "ses_1", at: now.add(const Duration(minutes: 9)));
      final runs = await ScheduledTaskDao(database: db).listRunsForTasks(taskIds: {task.id});
      expect(
        {for (final (:run, sessionProjectId: _) in runs) run.id: run.userPromptedAt},
        containsPair(nextRunId, now.add(const Duration(minutes: 3)).millisecondsSinceEpoch),
        reason: "the first prompt of the user's own is kept",
      );
    });

    test("archive candidates are only a task's unarchived, unpinned sessions", () async {
      final task = await repository.create(definition: definition, nextDueAt: null, now: now);
      final other = await repository.create(definition: definition, nextDueAt: null, now: now);
      for (final sessionId in ["ses_1", "ses_2", "ses_3", "ses_4"]) {
        await runSession(sessionId: sessionId, taskId: task.id);
      }
      await runSession(sessionId: "ses_other", taskId: other.id);
      await db.sessionDao.setPinned(sessionId: "ses_2", pinned: true);
      await db.sessionDao.setArchived(sessionId: "ses_3", archivedAt: 5, updatedAt: 5, projectionUpdatedAt: 5);

      expect(await db.sessionDao.listUnarchivedUnpinnedScheduledRunSessionIds(scheduledTaskId: task.id), [
        "ses_4",
        "ses_1",
      ]);
    });
  });
}
