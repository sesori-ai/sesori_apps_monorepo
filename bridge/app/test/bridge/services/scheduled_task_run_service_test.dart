import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/bridge_settings.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/repositories/mappers/stored_session_mapper.dart";
import "package:sesori_bridge/src/repositories/models/scheduled_task_record.dart";
import "package:sesori_bridge/src/repositories/models/sesori_tool_group_ids.dart";
import "package:sesori_bridge/src/repositories/models/session_compaction_result.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/models/session_quietness.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/models/task_command_edit.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/repositories/trackers/prompt_stamp.dart";
import "package:sesori_bridge/src/routing/sesori_mcp/groups/tasks/scheduled_task_tool.dart";
import "package:sesori_bridge/src/services/scheduled_command_service.dart";
import "package:sesori_bridge/src/services/scheduled_task_activity_tracker.dart";
import "package:sesori_bridge/src/services/scheduled_task_compaction_service.dart";
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
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show buildScheduledCommandContext, buildScheduledRunContext;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show PluginStaleOptionsException, PluginWorkingDirectoryMissingException;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:timezone/data/latest_all.dart" as tz_data;

import "../../helpers/arming_test_support.dart";
import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
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

/// A failed outcome recording what a task like [_daily] tried to use.
ScheduledTaskRunOutcome _failed({
  required TaskRunFailureReason reason,
  String pluginId = "fake",
  PromptModel? model,
  String? projectPath = "/repo",
}) => ScheduledTaskRunOutcome.failed(
  reason: reason,
  attempt: ScheduledTaskRunAttempt(pluginId: pluginId, model: model, projectPath: projectPath),
);

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
  late _FakeBridgeSettings bridgeSettings;
  late ScheduledTaskActivityTracker activity;
  late ScheduledTaskRunService service;
  late RecordingArmingMutations mutations;
  late List<ScheduledTaskRunFailure> failures;
  late DateTime now;
  late Set<String> missingFolders;
  late _FakeCommands commands;

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    now = DateTime.utc(2026, 11, 15, 9, 1);
    repository = ScheduledTaskRepository(dao: ScheduledTaskDao(database: db));
    await db.projectsDao.recordOpenedProject(
      projectId: "/repo",
      path: "/repo",
      displayName: null,
      createdAt: 0,
      updatedAt: 0,
    );
    missingFolders = {};
    sessions = _Sessions(database: db)..projectPathResult = "/repo";
    options = FakeSessionOptionsService();
    creation = _FakeSessionCreation(database: db);
    prompts = _FakePrompts();
    operations = _FakeOperations();
    yolo = _FakeYoloSettings();
    lifecycle = _FakeLifecycle();
    bridgeSettings = _FakeBridgeSettings();
    mutations = RecordingArmingMutations();
    commands = _FakeCommands();
    final clock = Clock(() => now);
    activity = ScheduledTaskActivityTracker(clock: clock);
    service = ScheduledTaskRunService(
      mutations: mutations,
      repository: repository,
      compaction: ScheduledTaskCompactionService(
        repository: repository,
        sessions: sessions,
        operations: operations,
        activity: activity,
        clock: clock,
      ),
      sessionCreation: creation,
      prompts: prompts,
      operations: operations,
      yoloSettings: yolo,
      sessions: sessions,
      bridgeSettings: bridgeSettings,
      projects: singlePluginProjectRepository(
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(missingPaths: missingFolders),
        gitCliApi: FakeGitCliApi(),
      ),
      lifecycle: lifecycle,
      sessionOptions: options,
      calculator: const ScheduledTaskOccurrenceCalculator(),
      commands: commands,
      clock: clock,
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
    String? command,
  }) =>
      repository.create(definition: definition, nextDueAt: nextDueAt, now: DateTime.utc(2026, 11, 1), command: command);

  Future<List<ScheduledTaskRunOutcome>> outcomes(String taskId) async => [
    for (final run in await repository.listRuns(taskId: taskId)) run.outcome,
  ];

  group("due runs", () {
    test("an on-time run starts a session and advances the next due time", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
      ]);
      expect((await repository.get(taskId: task.id))?.nextDueAt, DateTime.utc(2026, 11, 16, 9));
      final (request, link) = creation.calls.single;
      expect(request.parts, [const PromptPart.text(text: "Summarize yesterday")]);
      expect(link, (taskId: task.id, approvalOverride: SessionApprovalMode.yolo));
    });

    test("a run past the grace is marked late, once, however much was missed", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 12, 9));

      await service.runDue();

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: true,
        ),
      ]);
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

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: true,
        ),
      ]);
      final stored = await repository.get(taskId: task.id);
      expect(stored?.completedAt, now);
      expect(stored?.nextDueAt, isNull);
    });

    test("the run row and advanced due time are written before the session is created", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));
      creation.onCreate = () async {
        expect(await outcomes(task.id), [
          const ScheduledTaskRunOutcome.started(session: null, late: false),
        ]);
        expect((await repository.get(taskId: task.id))?.nextDueAt, DateTime.utc(2026, 11, 16, 9));
      };

      await service.runDue();

      expect(creation.calls, hasLength(1));
    });
  });

  group("run note", () {
    setUp(() => sessions.sesoriTools = true);

    test("a text run leads with the note beside the user's prompt when its harness gets Sesori's tools", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(creation.runContexts, [buildScheduledRunContext(taskName: "Morning summary", taskId: task.id)]);
      expect(creation.calls.single.$1.parts, [const PromptPart.text(text: "Summarize yesterday")]);
    });

    test("a same-session run sends the note into its target session", () async {
      final task = await createTask(definition: _sameSession, nextDueAt: DateTime.utc(2026, 11, 15, 9));
      await service.runDue();
      now = now.add(const Duration(days: 1));

      await service.runDue();

      expect(prompts.sends.single.runContext, buildScheduledRunContext(taskName: "Morning summary", taskId: task.id));
      expect(prompts.sends.single.parts, [const PromptPart.text(text: "Summarize yesterday")]);
    });

    test("no note when the harness doesn't get Sesori's tools", () async {
      sessions.sesoriTools = false;
      await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(creation.runContexts, [null]);
    });

    test("no note when the agent-tools setting is off", () async {
      bridgeSettings.settings = const BridgeSettings(agentTools: false);
      await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(creation.runContexts, [null]);
    });

    test("no note when the scheduled-tasks tool group is off", () async {
      bridgeSettings.settings = BridgeSettings(
        agentToolGroups: BridgeAgentToolGroupSettings(disabledIds: {SesoriToolGroupIds.tasks.value}),
      );
      await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(creation.runContexts, [null]);
    });

    test("the note names tools Sesori's server offers", () {
      final note = buildScheduledRunContext(taskName: "Morning summary", taskId: "task_1");

      for (final tool in [ScheduledTaskTool.updateTask, ScheduledTaskTool.getTask, ScheduledTaskTool.listTaskRuns]) {
        expect(note, contains("${tool.wireName} "));
      }
    });

    test("no note for a command prompt", () async {
      await createTask(
        definition: _daily.copyWith(
          prompt: const ScheduledTaskPrompt.command(name: "review", source: CommandSource.skill, arguments: "main"),
        ),
        nextDueAt: DateTime.utc(2026, 11, 15, 9),
      );

      await service.runDue();

      expect(creation.runContexts, [null]);
    });
  });

  group("task commands", () {
    test("a run runs its command in the project folder first, then sends the prompt with its result", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9), command: "git fetch");

      await service.runDue();

      expect(commands.calls.single, (outputKey: "task-${task.id}", command: "git fetch", workingDirectory: "/repo"));
      expect(creation.calls, isEmpty);
      expect(await outcomes(task.id), [const ScheduledTaskRunOutcome.started(session: null, late: false)]);
      await expectLater(
        () => service.runNow(taskId: task.id),
        throwsA(
          isA<ScheduledTaskRequestException>().having((e) => e.code, "code", ScheduledTaskErrorCode.previousRunActive),
        ),
      );

      commands.finish(result: "command exited 0");
      await commands.idle();

      expect(creation.runContexts, [
        buildScheduledCommandContext(command: "git fetch", workingDirectory: "/repo", result: "command exited 0"),
      ]);
      expect(creation.calls.single.$1.parts, [const PromptPart.text(text: "Summarize yesterday")]);
      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
      ]);
    });

    test("the result follows the run note when the harness gets Sesori's tools", () async {
      sessions.sesoriTools = true;
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9), command: "make check");

      await service.runDue();
      commands.finish(result: "command exited 2");
      await commands.idle();

      final runNote = buildScheduledRunContext(taskName: "Morning summary", taskId: task.id);
      final commandNote = buildScheduledCommandContext(
        command: "make check",
        workingDirectory: "/repo",
        result: "command exited 2",
      );
      expect(creation.runContexts, ["$runNote\n$commandNote"]);
    });

    test("a same-session run runs its command in its session's worktree", () async {
      final task = await createTask(definition: _sameSession, nextDueAt: DateTime.utc(2026, 11, 15, 9));
      await service.runDue();
      await db.customStatement("UPDATE sessions_table SET worktree_path = '/worktrees/one' WHERE session_id = 'ses_1'");
      await repository.updateDefinition(
        taskId: task.id,
        definition: _sameSession,
        command: const TaskCommandSet(command: "git status"),
        nextDueAt: DateTime.utc(2026, 11, 16, 9),
        clearTarget: false,
        now: now,
      );
      now = now.add(const Duration(days: 1));

      await service.runDue();
      commands.finish(result: "command exited 0");
      await commands.idle();

      expect(commands.calls.single.workingDirectory, "/worktrees/one");
      expect(
        prompts.sends.single.runContext,
        buildScheduledCommandContext(
          command: "git status",
          workingDirectory: "/worktrees/one",
          result: "command exited 0",
        ),
      );
    });

    test("a run whose command a shutdown stopped sends no prompt", () async {
      await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9), command: "sleep 600");
      await service.runDue();

      final disposed = service.dispose();
      commands.finish(result: "stopped by a bridge shutdown");
      await disposed;

      expect(creation.calls, isEmpty);
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
      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
      ]);
      expect(failures, isEmpty, reason: "a refusal is logged, not pushed");
    });

    test("an archive failure never fails the run", () async {
      lifecycle.error = StateError("export failed");

      final task = await fireWithOlderRuns();

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
      ]);
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

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
      ]);
      expect(await targetOf(task.id), "ses_1");
      expect(creation.calls.single.$2, (taskId: task.id, approvalOverride: SessionApprovalMode.yolo));
      expect(prompts.sends, isEmpty);
    });

    test("the first run arms its new session, and each later fire moves that arming", () async {
      await firstRun();
      expect(mutations.armedSessionIds, ["ses_1"]);

      await service.runDue();
      expect(mutations.armedSessionIds, ["ses_1", "ses_1"]);
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
        command: const TaskCommandUnchanged(),
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
        command: const TaskCommandUnchanged(),
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
        for (var i = 0; i < 3; i++)
          const ScheduledTaskRunOutcome.started(
            session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
            late: false,
          ),
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
          command: const TaskCommandUnchanged(),
        );
      };

      await service.runDue();

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
      ]);
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
        _failed(reason: TaskRunFailureReason.modelUnavailable, model: _model),
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
        _failed(reason: TaskRunFailureReason.startFailed),
      );
      expect(failures.single.reason, TaskRunFailureReason.startFailed);
      expect(await targetOf(task.id), "ses_1");
    });
  });

  group("auto-compact", () {
    final autoCompact = _daily.copyWith(runMode: const TaskRunMode.sameSession(autoCompact: true));

    /// Runs the task's first run at 9:01, with activity in its session then.
    Future<ScheduledTaskRecord> firstRun({ScheduledTaskDefinition? definition}) async {
      final task = await createTask(definition: definition ?? autoCompact, nextDueAt: DateTime.utc(2026, 11, 15, 9));
      await service.runDue();
      activity.recordEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "ses_1", status: SessionStatus.idle()),
      );
      return task;
    }

    Future<void> runDueAt(Duration sinceFirstRun) {
      now = DateTime.utc(2026, 11, 15, 9, 1).add(sinceFirstRun);
      return service.runDue();
    }

    test("a quiet session compacts once, 2 minutes before its cache goes cold", () async {
      sessions
        ..promptCacheLife = const Duration(minutes: 5)
        ..compactionResult = SessionCompactionResult.accepted;
      await firstRun();

      await runDueAt(const Duration(minutes: 2, seconds: 59));
      expect(sessions.compacted, isEmpty);
      await runDueAt(const Duration(minutes: 3));
      await runDueAt(const Duration(minutes: 4));

      expect(sessions.compacted, ["ses_1"]);
      expect(operations.calls.last, ("ses_1", SessionOperation.compactSession));
    });

    test("activity pushes the window back, and an unknown cache life waits 25 minutes", () async {
      sessions.compactionResult = SessionCompactionResult.accepted;
      await firstRun();
      now = DateTime.utc(2026, 11, 15, 9, 21);
      activity.recordEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "ses_1", status: SessionStatus.idle()),
      );

      await runDueAt(const Duration(minutes: 44, seconds: 59));
      expect(sessions.compacted, isEmpty);
      await runDueAt(const Duration(minutes: 45));
      expect(sessions.compacted, ["ses_1"]);
    });

    test("a busy session waits, and a busy answer is asked again on a later pass", () async {
      sessions.compactionResult = SessionCompactionResult.sessionBusy;
      await firstRun();
      sessions.quietness["ses_1"] = SessionQuietness.awaitingUser;

      await runDueAt(const Duration(minutes: 30));
      expect(sessions.compacted, isEmpty);
      sessions.quietness.remove("ses_1");
      await runDueAt(const Duration(minutes: 31));
      await runDueAt(const Duration(minutes: 32));
      expect(sessions.compacted, ["ses_1", "ses_1"]);
    });

    test("a prompt of the user's own, or auto-compact off, leaves the session alone", () async {
      await firstRun();
      await repository.recordUserPrompted(sessionId: "ses_1", at: now);
      await createTask(definition: _sameSession, nextDueAt: DateTime.utc(2026, 11, 15, 9));
      await service.runDue();

      await runDueAt(const Duration(hours: 1));

      expect(sessions.compacted, isEmpty);
    });

    test("a run due before the window compacts first and fires late, never missed, once it ends", () async {
      sessions.compactionResult = SessionCompactionResult.accepted;
      final task = await firstRun(definition: autoCompact.copyWith(missedRunPolicy: TaskMissedRunPolicy.waitForNext));

      await runDueAt(const Duration(days: 1));
      expect(sessions.compacted, ["ses_1"]);
      sessions.quietness["ses_1"] = SessionQuietness.working;
      await runDueAt(const Duration(days: 1, minutes: 5));
      expect(await outcomes(task.id), hasLength(1));
      sessions.quietness.remove("ses_1");
      await runDueAt(const Duration(days: 1, minutes: 6));

      expect(
        (await outcomes(task.id)).first,
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: true,
        ),
      );
      expect(prompts.sends.single.sessionId, "ses_1");
      expect(sessions.compacted, ["ses_1"]);
    });

    test("a run seen past the grace after a compaction that held nothing follows its policy", () async {
      sessions
        ..promptCacheLife = const Duration(minutes: 5)
        ..compactionResult = SessionCompactionResult.accepted;
      final task = await firstRun(definition: autoCompact.copyWith(missedRunPolicy: TaskMissedRunPolicy.waitForNext));
      // The session stays busy until 8:52 the next day, then compacts at 8:55,
      // 5 minutes before its next run.
      sessions.quietness["ses_1"] = SessionQuietness.working;
      await runDueAt(const Duration(hours: 12));
      sessions.quietness.remove("ses_1");
      now = DateTime.utc(2026, 11, 16, 8, 52);
      activity.recordEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "ses_1", status: SessionStatus.idle()),
      );
      await runDueAt(const Duration(hours: 23, minutes: 54));
      expect(sessions.compacted, ["ses_1"]);

      // The bridge slept through the next due time.
      await runDueAt(const Duration(days: 1, minutes: 30));

      expect((await outcomes(task.id)).first, const ScheduledTaskRunOutcome.missed());
      expect(prompts.sends, isEmpty);
    });

    test("a compaction still going 10 minutes after it was asked for skips the run", () async {
      sessions.compactionResult = SessionCompactionResult.accepted;
      final task = await firstRun();
      await runDueAt(const Duration(days: 1));
      sessions.quietness["ses_1"] = SessionQuietness.working;

      await runDueAt(const Duration(days: 1, minutes: 9));
      expect(await outcomes(task.id), hasLength(1));
      await runDueAt(const Duration(days: 1, minutes: 10));
      expect((await outcomes(task.id)).first, const ScheduledTaskRunOutcome.skipped());
    });

    test("an edit that clears the target leaves the old session alone and the next run starts fresh", () async {
      sessions.compactionResult = SessionCompactionResult.accepted;
      final task = await firstRun();
      await repository.updateDefinition(
        taskId: task.id,
        definition: autoCompact.copyWith(dedicatedWorktree: true),
        nextDueAt: DateTime.utc(2026, 11, 16, 9),
        clearTarget: true,
        now: now,
        command: const TaskCommandUnchanged(),
      );

      await runDueAt(const Duration(hours: 1));
      await runDueAt(const Duration(days: 1));

      expect(sessions.compacted, isEmpty);
      expect(creation.calls, hasLength(2));
      expect((await repository.get(taskId: task.id))?.targetSessionId, "ses_2");
    });

    test("an edit that clears the target while the compaction waits for the lane leaves the session alone", () async {
      sessions.compactionResult = SessionCompactionResult.accepted;
      final task = await firstRun();
      operations.whileQueued = () => repository.updateDefinition(
        taskId: task.id,
        definition: autoCompact.copyWith(dedicatedWorktree: true),
        nextDueAt: DateTime.utc(2026, 11, 16, 9),
        clearTarget: true,
        now: now,
        command: const TaskCommandUnchanged(),
      );

      await runDueAt(const Duration(hours: 1));

      expect(operations.calls.last, ("ses_1", SessionOperation.compactSession));
      expect(sessions.compacted, isEmpty);
    });

    test("a harness that can't compact fires the due run straight away", () async {
      final task = await firstRun();

      await runDueAt(const Duration(days: 1));

      expect(sessions.compacted, ["ses_1"]);
      expect(
        (await outcomes(task.id)).first,
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
      );
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
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_2", projectId: "/repo"),
          late: false,
        ),
        const ScheduledTaskRunOutcome.skipped(),
        const ScheduledTaskRunOutcome.skipped(),
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
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
      expect(
        history.last,
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
      );
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

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_2", projectId: "/repo"),
          late: false,
        ),
      ]);
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
        _failed(reason: TaskRunFailureReason.modelUnavailable, model: _model),
      ]);
      expect(failures.single.reason, TaskRunFailureReason.modelUnavailable);
    });

    test("a missing project fails the run without creating a session", () async {
      final task = await createTask(
        definition: _daily.copyWith(projectId: "/forgotten"),
        nextDueAt: DateTime.utc(2026, 11, 15, 9),
      );

      await service.runDue();

      expect(await outcomes(task.id), [
        _failed(reason: TaskRunFailureReason.projectMissing, projectPath: null),
      ]);
      expect(creation.calls, isEmpty);
      expect(failures.single.reason, TaskRunFailureReason.projectMissing);
      expect(failures.single.taskName, "Morning summary");
    });

    test("a project whose folder was deleted fails the run as projectMissing without creating a session", () async {
      missingFolders.add("/repo");
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(await outcomes(task.id), [
        _failed(reason: TaskRunFailureReason.projectMissing),
      ]);
      expect(creation.calls, isEmpty);
      expect(failures.single.reason, TaskRunFailureReason.projectMissing);
    });

    test("a harness reporting the working folder missing at start fails the run as projectMissing", () async {
      creation.error = const PluginWorkingDirectoryMissingException(
        operation: "spawn Claude",
        path: "/repo",
        cause: null,
      );
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(await outcomes(task.id), [
        _failed(reason: TaskRunFailureReason.projectMissing),
      ]);
      expect(failures.single.reason, TaskRunFailureReason.projectMissing);
    });

    test("a harness that is not running fails the run", () async {
      final task = await createTask(
        definition: _daily.copyWith(pluginId: "other"),
        nextDueAt: DateTime.utc(2026, 11, 15, 9),
      );

      await service.runDue();

      expect(await outcomes(task.id), [
        _failed(reason: TaskRunFailureReason.harnessUnavailable, pluginId: "other"),
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
        _failed(reason: TaskRunFailureReason.modelUnavailable, model: _model),
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

      expect(await outcomes(task.id), [
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
      ]);
      expect(options.explicitRefreshes, hasLength(1));
    });

    test("a create error marks the reserved run failed", () async {
      creation.error = StateError("backend down");
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 15, 9));

      await service.runDue();

      expect(await outcomes(task.id), [
        _failed(reason: TaskRunFailureReason.startFailed),
      ]);
      expect(failures.single.reason, TaskRunFailureReason.startFailed);
      expect((await repository.get(taskId: task.id))?.nextDueAt, DateTime.utc(2026, 11, 16, 9));
    });
  });

  group("Run now", () {
    test("a run that can't start answers the tap and sends no push", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 16, 9));
      missingFolders.add("/repo");
      final blocked = await service.runNow(taskId: task.id);
      missingFolders.remove("/repo");
      creation.error = StateError("backend down");
      final refused = await service.runNow(taskId: task.id);

      expect(blocked.outcome, _failed(reason: TaskRunFailureReason.projectMissing));
      expect(refused.outcome, _failed(reason: TaskRunFailureReason.startFailed));
      expect(failures, isEmpty);
    });

    test("starts a run without moving the next due time", () async {
      final task = await createTask(nextDueAt: DateTime.utc(2026, 11, 16, 9));

      final run = await service.runNow(taskId: task.id);

      expect(
        run.outcome,
        const ScheduledTaskRunOutcome.started(
          session: ScheduledTaskRunSession(id: "ses_1", projectId: "/repo"),
          late: false,
        ),
      );
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
  final List<String?> runContexts = [];
  Object? error;
  Future<void> Function()? onCreate;

  @override
  Future<Session> createScheduledRunSession({
    required CreateSessionRequest request,
    required ScheduledRunSessionLink scheduledRun,
    required String? runContext,
  }) async {
    await onCreate?.call();
    calls.add((request, scheduledRun));
    runContexts.add(runContext);
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
  pinOrder: null,
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
class _FakeBridgeSettings() implements BridgeSettingsRepository {
  BridgeSettings settings = const BridgeSettings();

  @override
  BridgeSettings get currentSettings => settings;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  String? runContext,
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
    required BridgePromptMark? mark,
    required String? runContext,
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
      runContext: runContext,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOperations() implements SessionOperationDispatcher {
  final List<(String, SessionOperation)> calls = [];

  /// Runs while the operation waits for its lane, before its body.
  Future<void> Function()? whileQueued;

  @override
  Future<T> dispatch<T>({
    required String sessionId,
    required SessionOperation operation,
    required Future<T> Function() body,
  }) {
    calls.add((sessionId, operation));
    final whileQueued = this.whileQueued;
    if (whileQueued == null) return body();
    return whileQueued().then((_) => body());
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

typedef _CommandCall = ({String outputKey, String command, String workingDirectory});

/// Holds every command until [finish], as a running one would.
class _FakeCommands() implements ScheduledCommandService {
  final List<_CommandCall> calls = [];
  final Completer<String> _result = Completer<String>();
  final List<Future<void>> _afterRuns = [];

  void finish({required String result}) => _result.complete(result);

  /// Lets the run service finish what it does after the command.
  Future<void> idle() async {
    await Future.wait(_afterRuns);
    await pumpEventQueue();
  }

  @override
  Future<String> run({required String outputKey, required String command, required String workingDirectory}) {
    calls.add((outputKey: outputKey, command: command, workingDirectory: workingDirectory));
    _afterRuns.add(_result.future);
    return _result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
