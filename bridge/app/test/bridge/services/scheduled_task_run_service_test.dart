import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/models/scheduled_task_record.dart";
import "package:sesori_bridge/src/repositories/models/session_quietness.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/scheduled_task_occurrence_calculator.dart";
import "package:sesori_bridge/src/services/scheduled_task_request_exception.dart";
import "package:sesori_bridge/src/services/scheduled_task_run_failure.dart";
import "package:sesori_bridge/src/services/scheduled_task_run_service.dart";
import "package:sesori_bridge/src/services/session_creation_service.dart";
import "package:sesori_bridge/src/services/session_options_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:timezone/data/latest_all.dart" as tz_data;

import "../../helpers/fake_session_options_service.dart";
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
  approvalMode: TaskApprovalMode.approveAll,
);

const _model = PromptModel(providerID: "anthropic", modelID: "opus");

void main() {
  setUpAll(tz_data.initializeTimeZones);

  late ScheduledTaskRepository repository;
  late FakeSessionRepository sessions;
  late FakeSessionOptionsService options;
  late _FakeSessionCreation creation;
  late ScheduledTaskRunService service;
  late List<ScheduledTaskRunFailure> failures;
  late DateTime now;

  setUp(() {
    final db = createTestDatabase();
    addTearDown(db.close);
    now = DateTime.utc(2026, 11, 15, 9, 1);
    repository = ScheduledTaskRepository(dao: ScheduledTaskDao(database: db));
    sessions = FakeSessionRepository(plugin: FakeBridgePlugin())..projectPathResult = "/repo";
    options = FakeSessionOptionsService();
    creation = _FakeSessionCreation(database: db);
    service = ScheduledTaskRunService(
      repository: repository,
      sessionCreation: creation,
      sessions: sessions,
      sessionOptions: options,
      calculator: const ScheduledTaskOccurrenceCalculator(),
      clock: Clock(() => now),
    );
    failures = [];
    final subscription = service.failures.listen(failures.add);
    addTearDown(() async {
      await subscription.cancel();
      await service.dispose();
    });
  });

  Future<ScheduledTaskRecord> createTask({
    ScheduledTaskDefinition definition = _daily,
    required DateTime? nextDueAt,
  }) => repository.create(definition: definition, nextDueAt: nextDueAt, now: DateTime.utc(2026, 11, 1));

  Future<List<ScheduledTaskRunOutcome>> outcomes(String taskId) async => [
    for (final run in await repository.listRuns(taskId: taskId)) run.outcome,
  ];

  group("due runs", () {
    test("an on-time run starts a session and advances the next due time", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: false)]);
      expect((await repository.get(taskId: task.id))?.nextDueAt, DateTime.utc(2026, 11, 16, 9));
      final (request, link) = creation.calls.single;
      expect(request.parts, [const PromptPart.text(text: "Summarize yesterday")]);
      expect(link, (taskId: task.id, approvalOverride: SessionApprovalMode.yolo));
    });

    test("a run past the grace is marked late, once, however much was missed", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 12, 9));

      await service.runDue();

      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: true)]);
      expect((await repository.get(taskId: task.id))?.nextDueAt, DateTime.utc(2026, 11, 16, 9));
    });

    test("waitForNext records a missed run past the grace and starts nothing", () async {
      final task = await createTask(
        definition: _daily.copyWith(missedRunPolicy: TaskMissedRunPolicy.waitForNext),
        nextDueAt: DateTime.utc(2026, 11, 15, 8),
      );

      await service.runDue();

      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.missed()]);
      expect(creation.calls, isEmpty);
      expect((await repository.get(taskId: task.id))?.nextDueAt, DateTime.utc(2026, 11, 16, 9));
    });

    test("a late one-off task runs late whatever its policy, then is done", () async {
      const at = TaskLocalDateTime(year: 2026, month: 11, day: 14, hour: 9, minute: 0);
      final task = await createTask(
        definition: _daily.copyWith(
          schedule: const TaskSchedule.once(at: at),
          missedRunPolicy: TaskMissedRunPolicy.waitForNext,
        ),
        nextDueAt: DateTime.utc(2026, 11, 14, 9),
      );

      await service.runDue();
      await service.runDue();

      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: true)]);
      final stored = await repository.get(taskId: task.id);
      expect(stored?.completedAt, now);
      expect(stored?.nextDueAt, isNull);
    });

    test("the run row and advanced due time are written before the session is created", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));
      creation.onCreate = () async {
        expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(sessionId: null, late: false)]);
        expect((await repository.get(taskId: task.id))?.nextDueAt, DateTime.utc(2026, 11, 16, 9));
      };

      await service.runDue();

      expect(creation.calls, hasLength(1));
    });

    test("same-session tasks are not fired yet and stay due", () async {
      final task = await createTask(
        definition: _daily.copyWith(runMode: const TaskRunMode.sameSession(autoCompact: false)),
        nextDueAt: DateTime.utc(2026, 11, 15, 9),
      );

      await service.runDue();

      expect(await outcomes(task.id), isEmpty);
      expect((await repository.get(taskId: task.id))?.nextDueAt, DateTime.utc(2026, 11, 15, 9));
      await expectLater(service.runNow(taskId: task.id), _refusedWith(ScheduledTaskErrorCode.unsupportedByBridge));
    });
  });

  group("overlap", () {
    test("a run is skipped while the previous run's session is working or waiting on the user", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));
      await service.runDue();

      for (final state in [SessionQuietness.working, SessionQuietness.awaitingUser]) {
        sessions.quietness["ses_1"] = state;
        now = now.add(const Duration(days: 1));
        await service.runDue();
      }
      sessions.quietness["ses_1"] = SessionQuietness.unknown;
      now = now.add(const Duration(days: 1));
      await service.runDue();

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(sessionId: "ses_2", late: false),
        const ScheduledTaskRunOutcome.skipped(),
        const ScheduledTaskRunOutcome.skipped(),
        const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: false),
      ]);
    });

    test("skips beyond the history limit still keep the running session blocking", () async {
      final hourly = _daily.copyWith(
        schedule: const TaskSchedule.everyHours(
          hours: 1,
          start: TaskLocalDateTime(year: 2026, month: 11, day: 1, hour: 0, minute: 0),
        ),
      );
      final task = await createTask(definition: hourly, nextDueAt: DateTime.utc(2026, 11, 15, 9));
      await service.runDue();
      sessions.quietness["ses_1"] = SessionQuietness.working;

      for (var hour = 1; hour <= 25; hour++) {
        now = DateTime.utc(2026, 11, 15, 9 + hour, 1);
        await service.runDue();
      }

      final history = await outcomes(task.id);
      // The newest rows are all skips; the started run is kept beyond them.
      expect(history, hasLength(ScheduledTaskRepository.runHistoryLimit + 1));
      expect(history.whereType<ScheduledTaskRunSkipped>(), hasLength(20));
      expect(history.last, const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: false));
      expect(creation.calls, hasLength(1));
    });
  });

  group("failures", () {
    test("a missing project fails the run without creating a session", () async {
      sessions.projectPathResult = null;
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.projectMissing),
      ]);
      expect(creation.calls, isEmpty);
      expect(failures.single.reason, TaskRunFailureReason.projectMissing);
      expect(failures.single.taskName, "Morning summary");
    });

    test("a harness that is not running fails the run", () async {
      final task = await createTask(
        definition: _daily.copyWith(pluginId: "other"),
        nextDueAt: DateTime.utc(2026, 11, 15, 9),
      );

      await service.runDue();

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.harnessUnavailable),
      ]);
    });

    test("a model the harness no longer offers fails the run with no fallback", () async {
      options.dynamicOutcome = _offering(models: [], stale: false);
      final task = await createTask(
        definition: _daily.copyWith(model: _model),
        nextDueAt: DateTime.utc(2026, 11, 15, 9),
      );

      await service.runDue();

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.modelUnavailable),
      ]);
      expect(creation.calls, isEmpty);
      expect(options.explicitRefreshes, isEmpty);
    });

    test("a stale option list missing the model is refreshed once before deciding", () async {
      options
        ..dynamicOutcome = _offering(models: [], stale: true)
        ..refreshOutcome = _offering(models: ["opus"], stale: false);
      final task = await createTask(
        definition: _daily.copyWith(model: _model),
        nextDueAt: DateTime.utc(2026, 11, 15, 9),
      );

      await service.runDue();

      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: false)]);
      expect(options.explicitRefreshes, hasLength(1));
    });

    test("a create error marks the reserved run failed", () async {
      creation.error = StateError("backend down");
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.startFailed),
      ]);
      expect(failures.single.reason, TaskRunFailureReason.startFailed);
      expect((await repository.get(taskId: task.id))?.nextDueAt, DateTime.utc(2026, 11, 16, 9));
    });
  });

  group("Run now", () {
    test("starts a run without moving the next due time", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 16, 9));

      final run = await service.runNow(taskId: task.id);

      expect(run.outcome, const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: false));
      expect((await repository.get(taskId: task.id))?.nextDueAt, DateTime.utc(2026, 11, 16, 9));
    });

    test("is refused while the previous run is still going", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 16, 9));
      await service.runNow(taskId: task.id);
      sessions.quietness["ses_1"] = SessionQuietness.working;

      await expectLater(service.runNow(taskId: task.id), _refusedWith(ScheduledTaskErrorCode.previousRunActive));
      expect(creation.calls, hasLength(1));
    });

    test("is refused for a missing task", () async {
      await expectLater(service.runNow(taskId: "stk_gone"), _refusedWith(ScheduledTaskErrorCode.taskNotFound));
    });
  });
}

Matcher _refusedWith(ScheduledTaskErrorCode code) =>
    throwsA(isA<ScheduledTaskRequestException>().having((error) => error.code, "code", code));

SessionOptionsOutcome _offering({required List<String> models, required bool stale}) => SessionOptionsAvailable(
  response: SessionOptionsResponse(
    agents: const Agents(agents: []),
    providers: ProviderListResponse(
      items: [
        ProviderInfo(
          id: _model.providerID,
          name: "Anthropic",
          models: {
            for (final id in models)
              id: ProviderModel(
                id: id,
                providerID: _model.providerID,
                name: id,
                variants: const [],
                defaultVariant: null,
                family: null,
                fastMode: null,
                releaseDate: null,
              ),
          },
          defaultModelID: null,
        ),
      ],
      connectedOnly: true,
    ),
    commands: const CommandListResponse(items: []),
    lastUsedPromptDefaults: null,
    stale: stale,
  ),
);

class _FakeSessionCreation({required final AppDatabase _database}) implements SessionCreationService {
  final List<(CreateSessionRequest, ScheduledRunSessionLink)> calls = [];
  Object? error;
  Future<void> Function()? onCreate;

  @override
  Future<Session> createScheduledRunSession({
    required CreateSessionRequest request,
    required ScheduledRunSessionLink scheduledRun,
  }) async {
    await onCreate?.call();
    calls.add((request, scheduledRun));
    if (error case final error?) throw error;
    final id = "ses_${calls.length}";
    await recordSessionBinding(
      database: _database,
      sessionId: id,
      backendSessionId: "backend_$id",
      pluginId: request.pluginId,
      projectId: request.projectId,
      parentSessionId: null,
    );
    return Session(
      approvalOverride: scheduledRun.approvalOverride,
      autoContinuation: null,
      branchName: null,
      id: id,
      pluginId: request.pluginId,
      projectID: request.projectId,
      directory: request.projectId,
      parentID: null,
      title: null,
      time: null,
      promptDefaults: null,
      lastUserActivityAt: null,
      scheduledTask: null,
      forkedFrom: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
