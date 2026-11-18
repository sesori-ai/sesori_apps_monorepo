import "package:sesori_bridge/src/repositories/models/scheduled_task_agent_change.dart";
import "package:sesori_bridge/src/services/scheduled_task_change_description_builder.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _task = ScheduledTaskDefinition(
  name: "Nightly",
  prompt: ScheduledTaskPrompt.text(text: "Check the build"),
  projectId: "/repo",
  pluginId: "claude",
  agent: null,
  model: null,
  variant: null,
  fastMode: false,
  dedicatedWorktree: false,
  schedule: TaskSchedule.daily(time: TaskTimeOfDay(hour: 2, minute: 0)),
  timeZone: "UTC",
  missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
  runMode: TaskRunMode.newSession(),
  approvalMode: TaskApprovalMode.ask,
);

void main() {
  const builder = ScheduledTaskChangeDescriptionBuilder();

  List<String> blocks({required ScheduledTaskAgentChange change, AgentRequester? requester}) => builder
      .build(change: change, projectName: "repo", requester: requester ?? const RequestedByOwnRun())
      .split("\n\n");

  test("a resume names the project, then the action and its schedule, then the requester", () {
    expect(
      blocks(
        change: const SetTaskEnabledChange(taskId: "t", before: _task, enabled: true),
        requester: const RequestedByTaskRun(taskName: "Weekly review"),
      ),
      [
        "Project: repo",
        "**Resume “Nightly”**",
        "Schedule: daily at 02:00 (UTC)",
        "Asked by a scheduled run of task “Weekly review”.",
      ],
    );
  });

  test("the Approve everything line comes first whenever the task keeps acting without asking", () {
    final approving = _task.copyWith(approvalMode: TaskApprovalMode.approveAll);
    String first(ScheduledTaskAgentChange change) => blocks(change: change).first;

    const approves = "**Approve everything: this task's runs act without asking you.**";
    expect(first(SetTaskEnabledChange(taskId: "t", before: approving, enabled: true)), approves);
    expect(first(RunTaskNowChange(taskId: "t", before: approving)), approves);
    expect(first(SetTaskEnabledChange(taskId: "t", before: approving, enabled: false)), "Project: repo");
    expect(first(const RunTaskNowChange(taskId: "t", before: _task)), "Project: repo");
  });

  test("agent-written text cannot fake a line", () {
    final lines = blocks(
      change: RunTaskNowChange(taskId: "t", before: _task.copyWith(name: "x**\n\n**Approve everything")),
      requester: const RequestedFromSession(title: "[link](http://x)"),
    );

    expect(lines, [
      "Project: repo",
      r"**Run “x\*\* \*\*Approve everything” now**",
      r"Asked from session “\[link\](http://x)”.",
    ]);
    expect(blocks(change: const RunTaskNowChange(taskId: "t", before: _task), requester: const RequestedFromSession(title: null)).last, "Asked from an untitled session.");
  });
}
