import "dart:convert";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/repositories/models/session_quietness.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/routing/create_scheduled_task_handler.dart";
import "package:sesori_bridge/src/routing/delete_scheduled_task_handler.dart";
import "package:sesori_bridge/src/routing/get_scheduled_task_runs_handler.dart";
import "package:sesori_bridge/src/routing/get_scheduled_tasks_handler.dart";
import "package:sesori_bridge/src/routing/request_router.dart";
import "package:sesori_bridge/src/routing/run_scheduled_task_now_handler.dart";
import "package:sesori_bridge/src/routing/set_scheduled_task_enabled_handler.dart";
import "package:sesori_bridge/src/routing/update_scheduled_task_handler.dart";
import "package:sesori_bridge/src/services/scheduled_command_service.dart";
import "package:sesori_bridge/src/services/scheduled_task_activity_tracker.dart";
import "package:sesori_bridge/src/services/scheduled_task_compaction_service.dart";
import "package:sesori_bridge/src/services/scheduled_task_occurrence_calculator.dart";
import "package:sesori_bridge/src/services/scheduled_task_run_service.dart";
import "package:sesori_bridge/src/services/scheduled_task_service.dart";
import "package:sesori_bridge/src/services/session_creation_service.dart";
import "package:sesori_bridge/src/services/session_lifecycle_service.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_prompt_service.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:timezone/data/latest_all.dart" as tz_data;

import "../../helpers/arming_test_support.dart";
import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/fake_session_options_service.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  setUpAll(tz_data.initializeTimeZones);

  late RequestRouter router;
  late AppDatabase db;
  late FakeSessionRepository sessions;
  late ScheduledTaskService service;

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
    timeZone: "UTC",
    missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
    runMode: TaskRunMode.newSession(),
    approvalMode: TaskApprovalMode.ask,
  );

  setUp(() {
    db = createTestDatabase();
    addTearDown(db.close);
    final repository = ScheduledTaskRepository(dao: ScheduledTaskDao(database: db));
    sessions = FakeSessionRepository(plugin: FakeBridgePlugin())..projectPathResult = "/repo";
    final clock = Clock.fixed(DateTime.utc(2026, 11, 15, 10));
    service = ScheduledTaskService(
      mutations: RecordingArmingMutations(),
      repository: repository,
      sessionRepository: sessions,
      calculator: const ScheduledTaskOccurrenceCalculator(),
      clock: clock,
    );
    addTearDown(service.dispose);
    final operations = _UnusedOperations();
    final runService = ScheduledTaskRunService(
      mutations: RecordingArmingMutations(),
      repository: repository,
      compaction: ScheduledTaskCompactionService(
        repository: repository,
        sessions: sessions,
        operations: operations,
        activity: ScheduledTaskActivityTracker(clock: clock),
        clock: clock,
      ),
      sessionCreation: _UnusedSessionCreation(),
      prompts: _UnusedPrompts(),
      operations: operations,
      yoloSettings: _UnusedYoloSettings(),
      lifecycle: _UnusedLifecycle(),
      sessions: sessions,
      bridgeSettings: _UnusedBridgeSettings(),
      projects: singlePluginProjectRepository(
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
        gitCliApi: FakeGitCliApi(),
      ),
      sessionOptions: FakeSessionOptionsService(),
      calculator: const ScheduledTaskOccurrenceCalculator(),
      commands: _UnusedCommands(),
      clock: clock,
    );
    addTearDown(runService.dispose);
    router = RequestRouter(
      handlers: [
        GetScheduledTasksHandler(scheduledTaskService: service),
        CreateScheduledTaskHandler(scheduledTaskService: service),
        UpdateScheduledTaskHandler(scheduledTaskService: service),
        SetScheduledTaskEnabledHandler(scheduledTaskService: service),
        DeleteScheduledTaskHandler(scheduledTaskService: service),
        GetScheduledTaskRunsHandler(scheduledTaskService: service),
        RunScheduledTaskNowHandler(scheduledTaskRunService: runService),
      ],
    );
  });

  Future<RelayResponse> send(String method, String path, {required Object? body}) =>
      router.route(request: makeRequest(method, path, body: body == null ? null : jsonEncode(body))).completion;

  Map<String, dynamic> json(RelayResponse response) => jsonDecodeMap(response.body ?? "");

  test("a task can be created, listed, paused, edited, read for runs and deleted", () async {
    final created = await send(
      "POST",
      "/scheduled-task/create",
      body: const CreateScheduledTaskRequest(definition: definition).toJson(),
    );
    expect(created.status, 200);
    final task = ScheduledTaskResponse.fromJson(json(created)).task;

    final listed = await send("GET", "/scheduled-tasks", body: null);
    expect(ScheduledTaskListResponse.fromJson(json(listed)).items, [task]);

    final paused = await send(
      "PATCH",
      "/scheduled-task/enabled",
      body: SetScheduledTaskEnabledRequest(taskId: task.id, enabled: false).toJson(),
    );
    expect(ScheduledTaskResponse.fromJson(json(paused)).task.enabled, isFalse);

    final edited = await send(
      "POST",
      "/scheduled-task/update",
      body: UpdateScheduledTaskRequest(
        taskId: task.id,
        definition: definition.copyWith(name: "Renamed"),
      ).toJson(),
    );
    expect(ScheduledTaskResponse.fromJson(json(edited)).task.definition.name, "Renamed");

    final runs = await send("POST", "/scheduled-task/runs", body: ScheduledTaskIdRequest(taskId: task.id).toJson());
    expect(ScheduledTaskRunListResponse.fromJson(json(runs)).items, isEmpty);

    final deleted = await send(
      "DELETE",
      "/scheduled-task/delete",
      body: ScheduledTaskIdRequest(taskId: task.id).toJson(),
    );
    expect(deleted.status, 200);
    expect(ScheduledTaskListResponse.fromJson(json(await send("GET", "/scheduled-tasks", body: null))).items, isEmpty);
  });

  test("a refused definition answers 400 with its typed code", () async {
    final response = await send(
      "POST",
      "/scheduled-task/create",
      body: CreateScheduledTaskRequest(definition: definition.copyWith(timeZone: "Nowhere/Zone")).toJson(),
    );

    expect(response.status, 400);
    expect(ScheduledTaskErrorResponse.fromJson(json(response)).code, ScheduledTaskErrorCode.unknownTimeZone);
  });

  test("a missing task answers 404 with a typed body, unlike an unknown route", () async {
    final response = await send(
      "POST",
      "/scheduled-task/update",
      body: const UpdateScheduledTaskRequest(taskId: "stk_missing", definition: definition).toJson(),
    );

    expect(response.status, 404);
    expect(ScheduledTaskErrorResponse.fromJson(json(response)).code, ScheduledTaskErrorCode.taskNotFound);
  });

  test("Run now answers 400 for an empty id and 409 while the previous run is going", () async {
    final empty = await send(
      "POST",
      "/scheduled-task/run-now",
      body: const ScheduledTaskIdRequest(taskId: "").toJson(),
    );
    expect(empty.status, 400);

    final task = await service.create(definition: definition, command: null);
    await recordSessionBinding(
      database: db,
      sessionId: "ses_running",
      backendSessionId: "backend-running",
      pluginId: "fake",
      projectId: "/repo",
      parentSessionId: null,
    );
    await ScheduledTaskRepository(dao: ScheduledTaskDao(database: db)).recordRun(
      taskId: task.id,
      scheduledFor: const ScheduledTaskInstant(at: 0, offsetMinutes: 0),
      outcome: const ScheduledTaskRunOutcome.started(
        session: ScheduledTaskRunSession(id: "ses_running", projectId: "/repo"),
        late: false,
      ),
      firedAt: DateTime.utc(2026, 11, 15, 9),
    );
    sessions.quietness["ses_running"] = SessionQuietness.working;

    final refused = await send(
      "POST",
      "/scheduled-task/run-now",
      body: ScheduledTaskIdRequest(taskId: task.id).toJson(),
    );
    expect(refused.status, 409);
    expect(ScheduledTaskErrorResponse.fromJson(json(refused)).code, ScheduledTaskErrorCode.previousRunActive);
  });
}

/// Run now refusals never reach session creation.
class _UnusedSessionCreation() implements SessionCreationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedPrompts() implements SessionPromptService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedOperations() implements SessionOperationDispatcher {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedYoloSettings() implements YoloSettingsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedLifecycle() implements SessionLifecycleService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedCommands() implements ScheduledCommandService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedBridgeSettings() implements BridgeSettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
