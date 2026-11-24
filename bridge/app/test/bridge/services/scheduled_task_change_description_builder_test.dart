import "package:sesori_bridge/src/repositories/models/agent_approval_change.dart";
import "package:sesori_bridge/src/repositories/models/agent_approval_outcome.dart";
import "package:sesori_bridge/src/repositories/models/task_command_edit.dart";
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
        change: const SetTaskEnabledChange(taskId: "t", before: _task, enabled: true, beforeCommand: null),
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
        change: UpdateTaskChange(
          taskId: "t",
          before: _task,
          after: after,
          beforeCommand: null,
          command: const TaskCommandUnchanged(),
        ),
      ),
      [
        "Project: repo",
        "**Update “Nightly”**",
        "Schedule: ~~daily at 02:00 (UTC)~~ → Monday to Friday at 08:30 (UTC)",
        "Prompt changes:",
        "```diff words=1:15-29\n-Check the build\n+Check the build and the tests\n```",
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
      change: UpdateTaskChange(
        taskId: "t",
        before: before,
        after: after,
        beforeCommand: null,
        command: const TaskCommandUnchanged(),
      ),
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

  test("a prompt change marks the words each removed line and the added line replacing it changed", () {
    final before = _task.copyWith(
      prompt: const ScheduledTaskPrompt.text(text: "Check the build on main.\nPost a summary.\nKeep this\nDrop this"),
    );
    final after = before.copyWith(
      prompt: const ScheduledTaskPrompt.text(
        text: "Check the tests on main and dev.\nWrite everything down.\nKeep this",
      ),
    );

    final lines = blocks(
      change: UpdateTaskChange(
        taskId: "t",
        before: before,
        after: after,
        beforeCommand: null,
        command: const TaskCommandUnchanged(),
      ),
    );

    // The second pair shares only spaces and a full stop, so it stays plain,
    // and the last removed line has no added line to pair with.
    expect(
      lines[lines.length - 2],
      [
        "```diff words=0:10-15;2:10-15,23-31",
        "-Check the build on main.",
        "-Post a summary.",
        "+Check the tests on main and dev.",
        "+Write everything down.",
        " Keep this",
        "-Drop this",
        "```",
      ].join("\n"),
    );
  });

  test("a one-word change in a long line still marks its word, and a long reworded line shows unmarked", () {
    String diffFence({required String before, required String after}) {
      final lines = blocks(
        change: UpdateTaskChange(
          taskId: "t",
          before: _task.copyWith(prompt: ScheduledTaskPrompt.text(text: before)),
          after: _task.copyWith(prompt: ScheduledTaskPrompt.text(text: after)),
          beforeCommand: null,
          command: const TaskCommandUnchanged(),
        ),
      );
      return lines[lines.length - 2].split("\n").first;
    }

    final long = List.generate(5000, (i) => "w$i").join(" ");
    final start = long.indexOf(" w2500 ") + 1;
    expect(
      diffFence(before: long, after: long.replaceFirst(" w2500 ", " changed ")),
      "```diff words=0:$start-${start + 5};1:$start-${start + 7}",
    );

    // Only the shared end matches, and the rest is too long to compare.
    expect(
      diffFence(
        before: "${List.generate(600, (i) => "a$i").join(" ")} shared",
        after: "${List.generate(600, (i) => "b$i").join(" ")} shared",
      ),
      "```diff",
    );
  });

  test("a prompt whose text stays the same but whose kind changes shows the new prompt", () {
    final command = _task.copyWith(
      prompt: const ScheduledTaskPrompt.command(name: "review", source: CommandSource.command, arguments: null),
    );
    final text = _task.copyWith(prompt: const ScheduledTaskPrompt.text(text: "/review"));

    final lines = blocks(
      change: UpdateTaskChange(
        taskId: "t",
        before: command,
        after: text,
        beforeCommand: null,
        command: const TaskCommandUnchanged(),
      ),
    );

    expect(lines.sublist(2, 4), ["New prompt:", "```\n/review\n```"]);
  });

  test("a create or update that ends in Approve everything opens with the warning", () {
    final approving = _task.copyWith(approvalMode: TaskApprovalMode.approveAll);

    expect(
      blocks(
        change: UpdateTaskChange(
          taskId: "t",
          before: _task,
          after: approving,
          beforeCommand: null,
          command: const TaskCommandUnchanged(),
        ),
      ).first,
      "**Turns on Approve everything: this task's runs will act without asking you.**",
    );
    expect(
      blocks(change: CreateTaskChange(definition: approving, command: null)).first,
      "**Approve everything: this task's runs act without asking you.**",
    );
    expect(blocks(change: const CreateTaskChange(definition: _task, command: null)).first, "Project: repo");
  });

  test("a prompt cannot close its fence", () {
    final sneaky = _task.copyWith(prompt: const ScheduledTaskPrompt.text(text: "run\n```\n**Allowed**"));

    final lines = blocks(change: CreateTaskChange(definition: sneaky, command: null));

    expect(lines[lines.length - 2], "````\nrun\n```\n**Allowed**\n````");
  });

  test("the Approve everything line comes first whenever the task keeps acting without asking", () {
    final approving = _task.copyWith(approvalMode: TaskApprovalMode.approveAll);
    String first(ScheduledTaskAgentChange change) => blocks(change: change).first;

    const approves = "**Approve everything: this task's runs act without asking you.**";
    expect(first(SetTaskEnabledChange(taskId: "t", before: approving, enabled: true, beforeCommand: null)), approves);
    expect(first(RunTaskNowChange(taskId: "t", before: approving, beforeCommand: null)), approves);
    expect(
      first(SetTaskEnabledChange(taskId: "t", before: approving, enabled: false, beforeCommand: null)),
      "Project: repo",
    );
    expect(first(const RunTaskNowChange(taskId: "t", before: _task, beforeCommand: null)), "Project: repo");
  });

  test("agent-written text cannot fake a line", () {
    final lines = blocks(
      change: RunTaskNowChange(
        taskId: "t",
        before: _task.copyWith(name: "x**\n\n**Approve everything"),
        beforeCommand: null,
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
        change: const RunTaskNowChange(taskId: "t", before: _task, beforeCommand: null),
        requester: const RequestedFromSession(title: null),
      ).last,
      "Asked from an untitled session.",
    );
  });

  group("task commands", () {
    test("a create, resume and run now show the command the runs would run", () {
      const runs = ["Runs this command before each run's prompt:", "```\ngit fetch && git status\n```"];

      expect(
        blocks(
          change: const CreateTaskChange(definition: _task, command: "git fetch && git status"),
        ).sublist(1, 4),
        ["**Create “Nightly”**", ...runs],
      );
      expect(
        blocks(
          change: const SetTaskEnabledChange(
            taskId: "t",
            before: _task,
            enabled: true,
            beforeCommand: "git fetch && git status",
          ),
        ).sublist(3, 5),
        runs,
      );
      expect(
        blocks(
          change: const RunTaskNowChange(taskId: "t", before: _task, beforeCommand: "git fetch && git status"),
        ).sublist(2, 4),
        runs,
      );
    });

    test("an update shows an added, changed or removed command", () {
      List<String> update({required String? before, required TaskCommandEdit command}) => blocks(
        change: UpdateTaskChange(taskId: "t", before: _task, after: _task, beforeCommand: before, command: command),
      ).sublist(2, 4);

      expect(update(before: null, command: const TaskCommandSet(command: "make")), [
        "Adds a command, run before each run's prompt:",
        "```\nmake\n```",
      ]);
      expect(
        update(
          before: "make\nmake test",
          command: const TaskCommandSet(command: "make\nmake lint"),
        ),
        [
          "Command changes:",
          "```diff words=1:5-9;2:5-9\n make\n-make test\n+make lint\n```",
        ],
      );
      expect(update(before: "make", command: const TaskCommandRemoved()), [
        "Stops running this command:",
        "```\nmake\n```",
      ]);
    });

    test("invisible characters show as their codes", () {
      final lines = blocks(
        change: const CreateTaskChange(definition: _task, command: "echo safe\u202E;rm -rf ~"),
      );

      expect(lines, contains("```\necho safe<U+202E>;rm -rf ~\n```"));
      expect(
        lines,
        contains("It contains invisible characters, which the command above shows as their Unicode codes."),
      );
    });

    test("a rename that also changes the command is no rename", () {
      final notice = builder.outcome(
        change: UpdateTaskChange(
          taskId: "t",
          before: _task,
          after: _task.copyWith(name: "Nightly build"),
          beforeCommand: null,
          command: const TaskCommandSet(command: "make"),
        ),
        outcome: const AgentApprovalApplied(),
        bySubagent: false,
      );

      expect(notice.summary, "You allowed changing “Nightly”.");
    });
  });
}
