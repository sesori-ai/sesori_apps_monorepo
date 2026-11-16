import "package:mocktail/mocktail.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/scheduled_task_repository.dart";

class MockScheduledTaskRepository() extends Mock implements ScheduledTaskRepository;

/// A task with fixture data: a daily task at 09:00 UTC unless [schedule] says
/// otherwise.
ScheduledTask scheduledTaskFixture({
  required String id,
  String name = "Morning summary",
  TaskSchedule schedule = const TaskSchedule.daily(time: TaskTimeOfDay(hour: 9, minute: 0)),
  TaskRunMode runMode = const TaskRunMode.newSession(),
  bool enabled = true,
  ScheduledTaskInstant? nextRunAt,
}) => ScheduledTask(
  id: id,
  definition: ScheduledTaskDefinition(
    name: name,
    prompt: const ScheduledTaskPrompt.text(text: "Summarize yesterday"),
    projectId: "fixture-project",
    pluginId: "fixture",
    agent: null,
    model: null,
    variant: null,
    fastMode: false,
    dedicatedWorktree: false,
    schedule: schedule,
    timeZone: "UTC",
    missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
    runMode: runMode,
    approvalMode: TaskApprovalMode.ask,
  ),
  enabled: enabled,
  nextRunAt: nextRunAt,
  lastRun: null,
);
