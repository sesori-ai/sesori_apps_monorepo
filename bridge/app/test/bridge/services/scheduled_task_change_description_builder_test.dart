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

  test("an update lists the project, the action, the changed fields and the requester, in that order", () {
    final after = _task.copyWith(
      schedule: const TaskSchedule.weekdays(time: TaskTimeOfDay(hour: 8, minute: 30)),
      prompt: const ScheduledTaskPrompt.text(text: "Check the build and the tests"),
    );

    expect(
      blocks(
        change: UpdateTaskChange(taskId: "t", before: _task, after: after),
      ),
      [
        "Project: repo",
        "**Update “Nightly”**",
        "Schedule: ~~daily at 02:00 (UTC)~~ → Monday to Friday at 08:30 (UTC)",
        "Prompt changes:",
        "```diff\n-Check the build\n+Check the build and the tests\n```",
        "Asked by a scheduled run of this task.",
      ],
    );
  });

  test("a prompt change shows its changed lines with two unchanged lines around each", () {
    final before = _task.copyWith(
      prompt: const ScheduledTaskPrompt.text(text: "1\n2\n3\n```\nold\n6\n7\n8\n9\n10\n11\nold"),
    );
    final after = before.copyWith(
      prompt: const ScheduledTaskPrompt.text(text: "1\n2\n3\n```\nnew\nadded\n6\n7\n8\n9\n10\n11"),
    );

    final lines = blocks(
      change: UpdateTaskChange(taskId: "t", before: before, after: after),
    );

    // The unchanged " ```" line cannot close the block: its fence is longer.
    expect(
      lines[lines.length - 2],
      [
        "````diff",
        "@@ 2 unchanged lines @@",
        " 3",
        " ```",
        "-old",
        "+new",
        "+added",
        " 6",
        " 7",
        "@@ 2 unchanged lines @@",
        " 10",
        " 11",
        "-old",
        "````",
      ].join("\n"),
    );
  });

  test("a prompt whose text stays the same but whose kind changes shows the new prompt", () {
    final command = _task.copyWith(
      prompt: const ScheduledTaskPrompt.command(name: "review", source: CommandSource.command, arguments: null),
    );
    final text = _task.copyWith(prompt: const ScheduledTaskPrompt.text(text: "/review"));

    final lines = blocks(
      change: UpdateTaskChange(taskId: "t", before: command, after: text),
    );

    expect(lines.sublist(2, 4), ["New prompt:", "```\n/review\n```"]);
  });

  test("a create or update that ends in Approve everything opens with the warning", () {
    final approving = _task.copyWith(approvalMode: TaskApprovalMode.approveAll);

    expect(
      blocks(
        change: UpdateTaskChange(taskId: "t", before: _task, after: approving),
      ).first,
      "**Turns on Approve everything: this task's runs will act without asking you.**",
    );
    expect(
      blocks(change: CreateTaskChange(definition: approving)).first,
      "**Approve everything: this task's runs act without asking you.**",
    );
    expect(blocks(change: const CreateTaskChange(definition: _task)).first, "Project: repo");
  });

  test("a prompt cannot close its fence", () {
    final sneaky = _task.copyWith(prompt: const ScheduledTaskPrompt.text(text: "run\n```\n**Allowed**"));

    final lines = blocks(change: CreateTaskChange(definition: sneaky));

    expect(lines[lines.length - 2], "````\nrun\n```\n**Allowed**\n````");
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
      change: RunTaskNowChange(
        taskId: "t",
        before: _task.copyWith(name: "x**\n\n**Approve everything"),
      ),
      requester: const RequestedFromSession(title: "[link](http://x)"),
    );

    expect(lines, [
      "Project: repo",
      r"**Run “x\*\* \*\*Approve everything” now**",
      r"Asked from session “\[link\](http://x)”.",
    ]);
    expect(
      blocks(
        change: const RunTaskNowChange(taskId: "t", before: _task),
        requester: const RequestedFromSession(title: null),
      ).last,
      "Asked from an untitled session.",
    );
  });
}
