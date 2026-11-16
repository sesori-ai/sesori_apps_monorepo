import "dart:convert";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/routing/create_scheduled_task_handler.dart";
import "package:sesori_bridge/src/routing/delete_scheduled_task_handler.dart";
import "package:sesori_bridge/src/routing/get_scheduled_task_runs_handler.dart";
import "package:sesori_bridge/src/routing/get_scheduled_tasks_handler.dart";
import "package:sesori_bridge/src/routing/request_router.dart";
import "package:sesori_bridge/src/routing/set_scheduled_task_enabled_handler.dart";
import "package:sesori_bridge/src/routing/update_scheduled_task_handler.dart";
import "package:sesori_bridge/src/services/scheduled_task_occurrence_calculator.dart";
import "package:sesori_bridge/src/services/scheduled_task_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:timezone/data/latest_all.dart" as tz_data;

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  setUpAll(tz_data.initializeTimeZones);

  late RequestRouter router;

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
    final db = createTestDatabase();
    addTearDown(db.close);
    final service = ScheduledTaskService(
      repository: ScheduledTaskRepository(dao: ScheduledTaskDao(database: db)),
      sessionRepository: FakeSessionRepository(plugin: FakeBridgePlugin())..projectPathResult = "/repo",
      calculator: const ScheduledTaskOccurrenceCalculator(),
      clock: Clock.fixed(DateTime.utc(2026, 11, 15, 10)),
    );
    addTearDown(service.dispose);
    router = RequestRouter(
      handlers: [
        GetScheduledTasksHandler(scheduledTaskService: service),
        CreateScheduledTaskHandler(scheduledTaskService: service),
        UpdateScheduledTaskHandler(scheduledTaskService: service),
        SetScheduledTaskEnabledHandler(scheduledTaskService: service),
        DeleteScheduledTaskHandler(scheduledTaskService: service),
        GetScheduledTaskRunsHandler(scheduledTaskService: service),
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
}
