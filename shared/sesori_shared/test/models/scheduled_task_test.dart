import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const definition = ScheduledTaskDefinition(
    name: "Morning triage",
    prompt: ScheduledTaskPrompt.command(name: "triage", source: CommandSource.skill, arguments: "open issues"),
    projectId: "project-1",
    pluginId: "claude",
    agent: null,
    model: PromptModel(providerID: "anthropic", modelID: "claude-opus"),
    variant: null,
    fastMode: false,
    dedicatedWorktree: true,
    schedule: TaskSchedule.weekly(
      days: {TaskWeekday.monday, TaskWeekday.thursday},
      time: TaskTimeOfDay(hour: 9, minute: 30),
    ),
    timeZone: "Europe/Bucharest",
    missedRunPolicy: TaskMissedRunPolicy.waitForNext,
    runMode: TaskRunMode.sameSession(autoCompact: true),
    approvalMode: TaskApprovalMode.approveAll,
  );

  Map<String, dynamic> roundTrip(Map<String, dynamic> json) => jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

  test("a task survives the wire unchanged", () {
    const task = ScheduledTask(
      id: "task-1",
      definition: definition,
      enabled: true,
      nextRunAt: ScheduledTaskInstant(at: 1763278200000, offsetMinutes: 120),
      lastRun: ScheduledTaskRun(
        id: "run-1",
        scheduledFor: ScheduledTaskInstant(at: 1763019000000, offsetMinutes: 120),
        outcome: ScheduledTaskRunOutcome.started(sessionId: null, late: true),
      ),
    );

    expect(ScheduledTask.fromJson(roundTrip(task.toJson())), task);
  });

  test("every request and response round-trips", () {
    expect(
      CreateScheduledTaskRequest.fromJson(roundTrip(const CreateScheduledTaskRequest(definition: definition).toJson())),
      const CreateScheduledTaskRequest(definition: definition),
    );
    const update = UpdateScheduledTaskRequest(taskId: "task-1", definition: definition);
    expect(UpdateScheduledTaskRequest.fromJson(roundTrip(update.toJson())), update);
    const enabled = SetScheduledTaskEnabledRequest(taskId: "task-1", enabled: false);
    expect(SetScheduledTaskEnabledRequest.fromJson(roundTrip(enabled.toJson())), enabled);
    const runs = ScheduledTaskRunListResponse(
      items: [
        ScheduledTaskRun(
          id: "run-2",
          scheduledFor: ScheduledTaskInstant(at: 1, offsetMinutes: -300),
          outcome: ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.modelUnavailable),
        ),
        ScheduledTaskRun(
          id: "run-1",
          scheduledFor: ScheduledTaskInstant(at: 0, offsetMinutes: -300),
          outcome: ScheduledTaskRunOutcome.skipped(),
        ),
      ],
    );
    expect(ScheduledTaskRunListResponse.fromJson(roundTrip(runs.toJson())), runs);
  });

  group("a newer peer's values decode instead of failing the list", () {
    Map<String, dynamic> definitionJson() => roundTrip(definition.toJson());

    test("unknown schedule, run mode and prompt kinds", () {
      final json = definitionJson()
        ..["schedule"] = {"kind": "monthly", "day": 3}
        ..["runMode"] = {"kind": "branchPerRun"}
        ..["prompt"] = {"kind": "withAttachments"};

      final decoded = ScheduledTaskDefinition.fromJson(json);

      expect(decoded.schedule, isA<TaskScheduleUnknown>());
      expect(decoded.runMode, isA<TaskRunModeUnknown>());
      expect(decoded.prompt, isA<ScheduledTaskPromptUnknown>());
    });

    test("unknown enum values", () {
      final json = definitionJson()
        ..["missedRunPolicy"] = "catchUpAll"
        ..["approvalMode"] = "approveEdits";

      final decoded = ScheduledTaskDefinition.fromJson(json);

      expect(decoded.missedRunPolicy, TaskMissedRunPolicy.unknown);
      expect(decoded.approvalMode, TaskApprovalMode.unknown);
    });

    test("unknown outcomes, failure reasons, mark kinds and error codes", () {
      expect(ScheduledTaskRunOutcome.fromJson({"kind": "cancelled"}), isA<ScheduledTaskRunOutcomeUnknown>());
      expect(
        ScheduledTaskRunOutcome.fromJson({"kind": "failed", "reason": "quotaExhausted"}),
        const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.unknown),
      );
      expect(
        SessionScheduledTaskMark.fromJson({"taskId": "t", "name": "n", "kind": "chained"}).kind,
        ScheduledTaskKind.unknown,
      );
      expect(ScheduledTaskErrorResponse.fromJson({"code": "tooManyTasks"}).code, ScheduledTaskErrorCode.unknown);
    });
  });

  test("a session from a bridge before scheduled tasks has no mark", () {
    final session = Session.fromJson({
      "id": "s",
      "projectID": "p",
      "directory": "/repo",
    });

    expect(session.scheduledTask, isNull);
  });

  test("a run session carries its task mark", () {
    const session = Session(
      id: "s",
      projectID: "p",
      directory: "/repo",
      parentID: null,
      title: null,
      time: null,
      promptDefaults: null,
      branchName: null,
      lastUserActivityAt: null,
      autoContinuation: null,
      approvalOverride: null,
      pinOrder: null,
      scheduledTask: SessionScheduledTaskMark(taskId: "task-1", name: "Morning triage", kind: ScheduledTaskKind.once),
      interruption: null,
      forkedFrom: null,
    );

    expect(Session.fromJson(roundTrip(session.toJson())).scheduledTask, session.scheduledTask);
  });
}
