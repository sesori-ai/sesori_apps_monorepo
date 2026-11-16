import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_continuation_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/repositories/session_continuation_repository.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/plugin_runtime_test_support.dart";
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

  setUp(() {
    db = createTestDatabase();
    addTearDown(db.close);
    tasks = _CountingTasks(dao: ScheduledTaskDao(database: db));
    views = SessionViewService(
      sessions: FakeSessionRepository(plugin: FakeBridgePlugin()),
      continuations: SessionContinuationRepository(
        dao: SessionContinuationDao(database: db),
        runtime: createAlwaysCurrentTestPluginRuntime(),
      ),
      scheduledTasks: tasks,
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
    final task = await tasks.create(definition: _daily, nextDueAt: null, now: DateTime.utc(2026, 11, 15));
    await storeSession(sessionId: "ses_run", taskId: task.id);

    final session = await views.enrich(session: _session(id: "ses_run"));

    expect(
      session.scheduledTask,
      SessionScheduledTaskMark(taskId: task.id, name: "Morning summary", kind: ScheduledTaskKind.recurring),
    );
  });

  test("a list reads every mark at once and leaves other sessions unmarked", () async {
    final task = await tasks.create(definition: _daily, nextDueAt: null, now: DateTime.utc(2026, 11, 15));
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
    final task = await tasks.create(definition: _daily, nextDueAt: null, now: DateTime.utc(2026, 11, 15));
    await storeSession(sessionId: "ses_run", taskId: task.id);
    await tasks.delete(taskId: task.id);

    expect((await views.enrich(session: _session(id: "ses_run"))).scheduledTask, isNull);
  });
}

class _CountingTasks({required super.dao}) extends ScheduledTaskRepository {
  int markReads = 0;

  @override
  Future<Map<String, SessionScheduledTaskMark>> marksOfSessions({required Set<String> sessionIds}) {
    markReads += 1;
    return super.marksOfSessions(sessionIds: sessionIds);
  }
}

Session _session({required String id}) => Session(
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
  time: null,
  promptDefaults: null,
  lastUserActivityAt: null,
  scheduledTask: null,
);
