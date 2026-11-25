import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_continuation_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_wake_up_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/models/session_wake_up.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/repositories/session_continuation_repository.dart";
import "package:sesori_bridge/src/repositories/session_wake_up_repository.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/session_interruption_test_support.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

const _daily = ScheduledTaskDefinition(
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
  timeZone: "UTC",
  missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
  runMode: TaskRunMode.newSession(),
  approvalMode: TaskApprovalMode.ask,
);

void main() {
  late AppDatabase db;
  late _CountingTasks tasks;
  late SessionViewService views;
  late SessionWakeUpRepository wakeUps;

  setUp(() {
    db = createTestDatabase();
    addTearDown(db.close);
    tasks = _CountingTasks(dao: ScheduledTaskDao(database: db));
    wakeUps = SessionWakeUpRepository(dao: SessionWakeUpDao(database: db));
    views = SessionViewService(
      wakeUps: wakeUps,
      sessions: FakeSessionRepository(plugin: FakeBridgePlugin()),
      continuations: SessionContinuationRepository(
        dao: SessionContinuationDao(database: db),
        runtime: createAlwaysCurrentTestPluginRuntime(),
      ),
      scheduledTasks: tasks,
      interruptions: const NoSessionInterruptions(),
      pullRequestWatches: createTestPullRequestWatches(database: db),
      resetBuffer: const Duration(minutes: 2),
    );
  });

  Future<void> storeSession({required String sessionId, required String? taskId}) async {
    await recordSessionBinding(
      database: db,
      sessionId: sessionId,
      backendSessionId: "backend_$sessionId",
      pluginId: "fake",
      projectId: "/repo",
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

  test("a single session carries its task's mark", () async {
    final task = await tasks.create(
      definition: _daily,
      nextDueAt: null,
      now: DateTime.utc(2026, 11, 15),
      command: null,
    );
    await storeSession(sessionId: "ses_run", taskId: task.id);

    final session = await views.enrich(session: _session(id: "ses_run"));

    expect(
      session.scheduledTask,
      SessionScheduledTaskMark(taskId: task.id, name: "Morning summary", kind: ScheduledTaskKind.recurring),
    );
  });

  test("a list reads every mark at once and leaves other sessions unmarked", () async {
    final task = await tasks.create(
      definition: _daily,
      nextDueAt: null,
      now: DateTime.utc(2026, 11, 15),
      command: null,
    );
    await storeSession(sessionId: "ses_run_1", taskId: task.id);
    await storeSession(sessionId: "ses_run_2", taskId: task.id);
    await storeSession(sessionId: "ses_plain", taskId: null);

    final sessions = await views.enrichMany(
      sessions: [
        _session(id: "ses_run_1"),
        _session(id: "ses_plain"),
        _session(id: "ses_run_2"),
      ],
    );

    expect([for (final session in sessions) session.scheduledTask?.taskId], [task.id, null, task.id]);
    expect(tasks.markReads, 1);
  });

  test("a deleted task leaves its sessions unmarked", () async {
    final task = await tasks.create(
      definition: _daily,
      nextDueAt: null,
      now: DateTime.utc(2026, 11, 15),
      command: null,
    );
    await storeSession(sessionId: "ses_run", taskId: task.id);
    await tasks.delete(taskId: task.id);

    expect((await views.enrich(session: _session(id: "ses_run"))).scheduledTask, isNull);
  });

  group("wake-ups and arming", () {
    final nine = DateTime.utc(2026, 11, 16, 9);
    final ten = DateTime.utc(2026, 11, 16, 10);

    Future<StoredSessionWakeUp> addWakeUp({
      required DateTime dueAt,
      required WakeUpSchedule schedule,
      WakeUpCommand? command,
    }) => wakeUps.add(
      sessionId: "ses_root",
      label: "Check CI",
      prompt: "Look at the checks",
      command: command,
      schedule: schedule,
      nextDueAt: dueAt,
      createdAt: DateTime.utc(2026, 11, 15),
    );

    Future<String> targetSameSessionTask({required DateTime nextDueAt}) async {
      final task = await tasks.create(
        definition: _sameSession,
        nextDueAt: nextDueAt,
        now: DateTime.utc(2026, 11, 15),
        command: null,
      );
      expect(await tasks.setTargetSession(task: task, sessionId: "ses_root"), isTrue);
      return task.id;
    }

    setUp(() => storeSession(sessionId: "ses_root", taskId: null));

    test("a session with neither is not armed and lists no wake-ups", () async {
      final session = await views.enrich(session: _session(id: "ses_root"));

      expect(session.wakeUps, isEmpty);
      expect(session.arming, const SessionArming.notArmed());
    });

    test("wake-ups are listed soonest first and arm the session with the soonest", () async {
      final repeating = await addWakeUp(dueAt: ten, schedule: const WakeUpSchedule.every(minutes: 30));
      final once = await addWakeUp(
        dueAt: nine,
        schedule: const WakeUpSchedule.once(),
        command: const WakeUpCommand(command: "make check", approval: WakeUpCommandApproval.allowed),
      );

      final session = await views.enrich(session: _session(id: "ses_root"));

      expect(session.wakeUps, [
        SessionWakeUp(
          id: once.id,
          nextDueAt: nine.millisecondsSinceEpoch,
          label: "Check CI",
          repeats: false,
          runsCommand: true,
        ),
        SessionWakeUp(
          id: repeating.id,
          nextDueAt: ten.millisecondsSinceEpoch,
          label: "Check CI",
          repeats: true,
          runsCommand: false,
        ),
      ]);
      expect(session.arming, SessionArming.armed(name: "Check CI", nextAt: nine.millisecondsSinceEpoch));
    });

    test("a same-session task that continues in the session arms it", () async {
      await targetSameSessionTask(nextDueAt: ten);

      expect(
        (await views.enrich(session: _session(id: "ses_root"))).arming,
        SessionArming.armed(name: "Standup", nextAt: ten.millisecondsSinceEpoch),
      );
    });

    test("the sooner of a task run and a wake-up wins", () async {
      await targetSameSessionTask(nextDueAt: nine);
      await addWakeUp(dueAt: ten, schedule: const WakeUpSchedule.once());

      expect(
        (await views.enrich(session: _session(id: "ses_root"))).arming,
        SessionArming.armed(name: "Standup", nextAt: nine.millisecondsSinceEpoch),
      );
    });

    test("a paused task does not arm its session", () async {
      final taskId = await targetSameSessionTask(nextDueAt: nine);
      await tasks.setEnabled(taskId: taskId, enabled: false, nextDueAt: null, now: DateTime.utc(2026, 11, 15, 1));

      expect((await views.enrich(session: _session(id: "ses_root"))).arming, const SessionArming.notArmed());
    });

    test("an archived session is not armed but still lists its wake-ups", () async {
      await targetSameSessionTask(nextDueAt: nine);
      await addWakeUp(dueAt: ten, schedule: const WakeUpSchedule.once());

      final session = await views.enrich(session: _session(id: "ses_root", archivedAt: 1));

      expect(session.arming, const SessionArming.notArmed());
      expect(session.wakeUps, hasLength(1));
    });
  });
}

const _sameSession = ScheduledTaskDefinition(
  name: "Standup",
  prompt: ScheduledTaskPrompt.text(text: "Post the standup"),
  projectId: "/repo",
  pluginId: "fake",
  agent: null,
  model: null,
  variant: null,
  fastMode: false,
  dedicatedWorktree: false,
  schedule: TaskSchedule.daily(time: TaskTimeOfDay(hour: 9, minute: 0)),
  timeZone: "UTC",
  missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
  runMode: TaskRunMode.sameSession(autoCompact: false),
  approvalMode: TaskApprovalMode.ask,
);

class _CountingTasks({required super.dao}) extends ScheduledTaskRepository {
  int markReads = 0;

  @override
  Future<Map<String, SessionScheduledTaskMark>> marksOfSessions({required Set<String> sessionIds}) {
    markReads += 1;
    return super.marksOfSessions(sessionIds: sessionIds);
  }
}

Session _session({required String id, int? archivedAt}) => Session(
  approvalOverride: null,
  autoContinuation: null,
  branchName: null,
  id: id,
  pluginId: "fake",
  projectID: "/repo",
  directory: "/repo",
  parentID: null,
  forkedFrom: null,
  title: null,
  time: archivedAt == null ? null : SessionTime(created: 0, updated: 0, archived: archivedAt),
  promptDefaults: null,
  lastUserActivityAt: null,
  pinOrder: null,
  scheduledTask: null,
  interruption: null,
);
