import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/mappers/stored_session_mapper.dart";
import "package:sesori_bridge/src/repositories/models/scheduled_task_record.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/models/session_quietness.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/scheduled_task_occurrence_calculator.dart";
import "package:sesori_bridge/src/services/scheduled_task_request_exception.dart";
import "package:sesori_bridge/src/services/scheduled_task_run_failure.dart";
import "package:sesori_bridge/src/services/scheduled_task_run_service.dart";
import "package:sesori_bridge/src/services/session_creation_service.dart";
import "package:sesori_bridge/src/services/session_lifecycle_service.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_options_service.dart";
import "package:sesori_bridge/src/services/session_prompt_service.dart";
import "package:sesori_bridge/src/services/stale_session_prompt_options_exception.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginStaleOptionsException;
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

final _sameSession = _daily.copyWith(runMode: const TaskRunMode.sameSession(autoCompact: false));

const _model = PromptModel(providerID: "anthropic", modelID: "opus");

void main() {
  setUpAll(tz_data.initializeTimeZones);

  late AppDatabase db;
  late ScheduledTaskRepository repository;
  late _Sessions sessions;
  late FakeSessionOptionsService options;
  late _FakeSessionCreation creation;
  late _FakePrompts prompts;
  late _FakeOperations operations;
  late _FakeYoloSettings yolo;
  late _FakeLifecycle lifecycle;
  late ScheduledTaskRunService service;
  late List<ScheduledTaskRunFailure> failures;
  late DateTime now;

  setUp(() {
    db = createTestDatabase();
    addTearDown(db.close);
    now = DateTime.utc(2026, 11, 15, 9, 1);
    repository = ScheduledTaskRepository(dao: ScheduledTaskDao(database: db));
    sessions = _Sessions(database: db)..projectPathResult = "/repo";
    options = FakeSessionOptionsService();
    creation = _FakeSessionCreation(database: db);
    prompts = _FakePrompts();
    operations = _FakeOperations();
    yolo = _FakeYoloSettings();
    lifecycle = _FakeLifecycle();
    service = ScheduledTaskRunService(
      repository: repository,
      sessionCreation: creation,
      prompts: prompts,
      operations: operations,
      yoloSettings: yolo,
      sessions: sessions,
      lifecycle: lifecycle,
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
  });

  group("archiving old runs", () {
    // The fire's own session first, then older runs, newest first.
    const older = ["old_1", "old_2", "old_3", "old_4", "old_5", "old_6", "old_7", "old_8", "old_9"];

    Future<ScheduledTaskRecord> fireWithOlderRuns({ScheduledTaskDefinition definition = _daily}) async {
      final task = await createTask(definition: definition, nextDueAt: DateTime.utc(2026, 11, 15, 9));
      sessions.archivableScheduledRunSessionIds[task.id] = ["ses_1", ...older];
      sessions.quietness["ses_1"] = SessionQuietness.working;
      await service.runDue();
      // Archiving runs apart from the fire; disposing waits for it.
      await service.dispose();
      return task;
    }

    test("a new-session run archives finished runs beyond the newest five", () async {
      await fireWithOlderRuns();

      expect(lifecycle.archived, ["old_6", "old_7", "old_8", "old_9"]);
    });

    test("runs still working or waiting on the user stay and do not count among the five", () async {
      sessions.quietness["old_2"] = SessionQuietness.working;
      sessions.quietness["old_4"] = SessionQuietness.awaitingUser;
      sessions.quietness["old_8"] = SessionQuietness.unknown;

      await fireWithOlderRuns();

      expect(lifecycle.archived, ["old_9"]);
    });

    test("a run whose worktree cleanup is refused stays, and the rest are still archived", () async {
      lifecycle.refused.add("old_7");

      final task = await fireWithOlderRuns();

      expect(lifecycle.archived, ["old_6", "old_8", "old_9"]);
      expect(lifecycle.calls, everyElement((deleteWorktree: true, force: false)));
      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: false)]);
      expect(failures, isEmpty, reason: "a refusal is logged, not pushed");
    });

    test("an archive failure never fails the run", () async {
      lifecycle.error = StateError("export failed");

      final task = await fireWithOlderRuns();

      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: false)]);
      expect(failures, isEmpty);
    });

    test("a same-session task archives nothing", () async {
      await fireWithOlderRuns(definition: _sameSession);

      expect(lifecycle.calls, isEmpty);
    });
  });

  group("same-session tasks", () {
    Future<ScheduledTaskRecord> firstRun({ScheduledTaskDefinition? definition}) async {
      final task = await createTask(definition: definition ?? _sameSession, nextDueAt: DateTime.utc(2026, 11, 15, 9));
      await service.runDue();
      now = now.add(const Duration(days: 1));
      return task;
    }

    Future<String?> targetOf(String taskId) async => (await repository.get(taskId: taskId))?.targetSessionId;

    test("the first run creates the session and targets it", () async {
      final task = await firstRun();

      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: false)]);
      expect(await targetOf(task.id), "ses_1");
      expect(creation.calls.single.$2, (taskId: task.id, approvalOverride: SessionApprovalMode.yolo));
      expect(prompts.sends, isEmpty);
    });

    test("later runs send on the target's lane with the task's current options and approval mode", () async {
      options.dynamicOutcome = _offering(models: ["opus"], stale: false);
      final task = await firstRun();
      final edited = _sameSession.copyWith(
        agent: "build",
        model: _model,
        variant: const SessionVariant(id: "high"),
        fastMode: true,
        approvalMode: TaskApprovalMode.ask,
      );
      await repository.updateDefinition(
        taskId: task.id,
        definition: edited,
        nextDueAt: DateTime.utc(2026, 11, 16, 9),
        clearTarget: false,
        now: now,
      );

      await service.runDue();
      await repository.updateDefinition(
        taskId: task.id,
        definition: edited.copyWith(
          prompt: const ScheduledTaskPrompt.command(name: "review", source: CommandSource.skill, arguments: "main"),
        ),
        nextDueAt: null,
        clearTarget: false,
        now: now.add(const Duration(minutes: 1)),
      );
      now = now.add(ScheduledTaskRunService.startupGrace);
      await service.runNow(taskId: task.id);

      expect(creation.calls, hasLength(1));
      expect(operations.calls, [("ses_1", SessionOperation.sendPrompt), ("ses_1", SessionOperation.sendCommand)]);
      expect(yolo.overrides, [("ses_1", SessionApprovalMode.ask), ("ses_1", SessionApprovalMode.ask)]);
      final [text, command] = prompts.sends;
      expect(text.sessionId, "ses_1");
      expect(text.parts, [const PromptPart.text(text: "Summarize yesterday")]);
      expect(text.command, isNull);
      expect((text.agent, text.model, text.variant, text.fastMode), ("build", _model, edited.variant, true));
      expect((command.command, command.commandSource), ("review", CommandSource.skill));
      expect(command.parts, [const PromptPart.text(text: "main")]);
      expect(await outcomes(task.id), [
        for (var i = 0; i < 3; i++) const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: false),
      ]);
    });

    test("an archived target is replaced by a fresh session", () async {
      final task = await firstRun();
      await db.sessionDao.setArchived(sessionId: "ses_1", archivedAt: 2, updatedAt: 2, projectionUpdatedAt: 2);

      await service.runDue();

      expect(creation.calls, hasLength(2));
      expect(await targetOf(task.id), "ses_2");
      expect(prompts.sends, isEmpty);
    });

    test("a deleted target is replaced by a fresh session", () async {
      final task = await firstRun();
      await db.sessionDao.deleteSession(sessionId: "ses_1");
      expect(await targetOf(task.id), isNull);

      await service.runDue();

      expect(creation.calls, hasLength(2));
      expect(await targetOf(task.id), "ses_2");
    });

    test("an edit made while the first run starts its session keeps the target it left", () async {
      final task = await createTask(definition: _sameSession, nextDueAt: DateTime.utc(2026, 11, 15, 9));
      creation.onCreate = () async {
        await repository.updateDefinition(
          taskId: task.id,
          definition: _sameSession.copyWith(name: "Renamed"),
          nextDueAt: DateTime.utc(2026, 11, 16, 9),
          clearTarget: false,
          now: now,
        );
      };

      await service.runDue();

      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(sessionId: "ses_1", late: false)]);
      expect(await targetOf(task.id), isNull);
    });

    test("a run is skipped while the target is busy", () async {
      final task = await firstRun();
      sessions.quietness["ses_1"] = SessionQuietness.working;

      await service.runDue();

      expect((await outcomes(task.id)).first, const ScheduledTaskRunOutcome.skipped());
      await expectLater(service.runNow(taskId: task.id), _refusedWith(ScheduledTaskErrorCode.previousRunActive));
      expect(prompts.sends, isEmpty);
      expect(yolo.overrides, isEmpty);
    });

    test("a Run now right after a continued run is refused before the harness reports the turn", () async {
      final task = await firstRun();
      await service.runDue();

      // The target still reads quiet: its busy status has not arrived yet.
      now = now.add(const Duration(seconds: 3));
      await expectLater(service.runNow(taskId: task.id), _refusedWith(ScheduledTaskErrorCode.previousRunActive));
      expect(prompts.sends, hasLength(1));
    });

    test("a model the harness no longer offers fails the run without prompting the target", () async {
      options.dynamicOutcome = _offering(models: ["opus"], stale: false);
      final task = await firstRun(definition: _sameSession.copyWith(model: _model));
      options.dynamicOutcome = _offering(models: [], stale: false);

      await service.runDue();

      expect(
        (await outcomes(task.id)).first,
        const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.modelUnavailable),
      );
      expect(prompts.sends, isEmpty);
      expect(await targetOf(task.id), "ses_1");
    });

    test("a refused send fails the run and keeps the target", () async {
      final task = await firstRun();
      prompts.error = StateError("backend down");

      await service.runDue();

      expect(
        (await outcomes(task.id)).first,
        const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.startFailed),
      );
      expect(failures.single.reason, TaskRunFailureReason.startFailed);
      expect(await targetOf(task.id), "ses_1");
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
    test("a new-session run refused for a stale variant starts with it corrected", () async {
      creation.onCreate = () async {
        if (creation.calls.isEmpty) creation.error = _staleOptions();
        if (creation.calls.length == 1) creation.error = null;
      };
      prompts.correctedSettings = (
        variant: const SessionVariant(id: "high"),
        fastMode: false,
        agent: null,
        model: _model,
      );
      final task = await createTask(
        definition: _daily.copyWith(
          model: _model,
          variant: const SessionVariant(id: "removed"),
        ),
        nextDueAt: DateTime.utc(2026, 11, 15, 9),
      );

      await service.runDue();

      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(sessionId: "ses_2", late: false)]);
      expect(creation.calls.map((call) => call.$1.variant?.id), ["removed", "high"]);
      expect(prompts.correctionScopes, [("fake", "/repo")]);
      expect(failures, isEmpty);
    });

    test("a run the correction can't answer, such as a stale model, still fails as modelUnavailable", () async {
      creation.error = _staleOptions();
      final task = await createTask(
        definition: _daily.copyWith(model: _model),
        nextDueAt: DateTime.utc(2026, 11, 15, 9),
      );

      await service.runDue();

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.modelUnavailable),
      ]);
      expect(failures.single.reason, TaskRunFailureReason.modelUnavailable);
    });

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
      now = now.add(const Duration(minutes: 5));

      await expectLater(service.runNow(taskId: task.id), _refusedWith(ScheduledTaskErrorCode.previousRunActive));
      expect(creation.calls, hasLength(1));
    });

    test("a second tap right after a run started is refused before the harness reports the turn", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 16, 9));
      // A slow create must not use up the grace.
      creation.onCreate = () async => now = now.add(const Duration(minutes: 1));
      await service.runNow(taskId: task.id);
      creation.onCreate = null;

      // The session still reads quiet: its busy status has not arrived yet.
      now = now.add(const Duration(seconds: 3));
      await expectLater(service.runNow(taskId: task.id), _refusedWith(ScheduledTaskErrorCode.previousRunActive));

      now = now.add(ScheduledTaskRunService.startupGrace);
      await service.runNow(taskId: task.id);
      expect(creation.calls, hasLength(2));
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
    return _session(id: id, approvalOverride: scheduledRun.approvalOverride);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _session({required String id, required SessionApprovalMode? approvalOverride}) => Session(
  approvalOverride: approvalOverride,
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
  interruption: null,
);

class _FakeLifecycle() implements SessionLifecycleService {
  final List<({bool deleteWorktree, bool force})> calls = [];
  final List<String> archived = [];
  final Set<String> refused = {};
  Object? error;

  @override
  Future<ArchiveStatusUpdate> updateArchiveStatus({
    required String sessionId,
    required bool archived,
    required bool deleteWorktree,
    required bool force,
  }) async {
    calls.add((deleteWorktree: deleteWorktree, force: force));
    if (error case final error?) throw error;
    if (refused.contains(sessionId)) {
      throw SessionArchiveConflictException(
        rejection: const SessionCleanupRejection(issues: [CleanupIssue.unstagedChanges()]),
      );
    }
    this.archived.add(sessionId);
    return ArchiveStatusUpdate(
      session: _session(id: sessionId, approvalOverride: null),
      changed: true,
      projectId: "/repo",
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Reads stored sessions from the test database the session fakes write.
class _Sessions({required final AppDatabase _database}) extends FakeSessionRepository {
  this : super(plugin: FakeBridgePlugin());

  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async =>
      (await _database.sessionDao.getSession(sessionId: sessionId))?.toStoredSession();
}

typedef _Send = ({
  String sessionId,
  List<PromptPart> parts,
  SessionVariant? variant,
  bool fastMode,
  String? agent,
  PromptModel? model,
  String? command,
  CommandSource? commandSource,
});

class _FakePrompts() implements SessionPromptService {
  final List<_Send> sends = [];
  final List<(String, String)> correctionScopes = [];
  Object? error;

  /// What the stale-refusal recovery resends with; null rethrows, as for a
  /// model the catalog no longer offers.
  PromptSettings? correctedSettings;

  @override
  Future<T> sendWithSettingsIn<T>({
    required String pluginId,
    required String projectId,
    required PromptSettings settings,
    required Future<T> Function(PromptSettings settings) send,
  }) async {
    correctionScopes.add((pluginId, projectId));
    try {
      return await send(settings);
    } on StaleSessionPromptOptionsException {
      final corrected = correctedSettings;
      if (corrected == null) rethrow;
      return await send(corrected);
    }
  }

  @override
  Future<void> sendPromptAlreadyReserved({
    required String sessionId,
    required String promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required CommandSource? commandSource,
    required MessageHandoff? handoff,
  }) async {
    if (error case final error?) throw error;
    sends.add((
      sessionId: sessionId,
      parts: parts,
      variant: variant,
      fastMode: fastMode,
      agent: agent,
      model: model,
      command: command,
      commandSource: commandSource,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOperations() implements SessionOperationDispatcher {
  final List<(String, SessionOperation)> calls = [];

  @override
  Future<T> dispatch<T>({
    required String sessionId,
    required SessionOperation operation,
    required Future<T> Function() body,
  }) {
    calls.add((sessionId, operation));
    return body();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeYoloSettings() implements YoloSettingsService {
  final List<(String, SessionApprovalMode?)> overrides = [];

  @override
  Future<Session> setSessionOverride({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) async {
    overrides.add((sessionId, approvalOverride));
    return _session(id: sessionId, approvalOverride: approvalOverride);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StaleSessionPromptOptionsException _staleOptions() => StaleSessionPromptOptionsException(
  cause: const PluginStaleOptionsException(
    operation: "createSession",
    message: "no longer offers the selected variant",
  ),
  causeStackTrace: StackTrace.current,
  agent: null,
  model: _model,
  variant: null,
);
