import "package:sesori_shared/sesori_shared.dart" show PromptModel, ScheduledTaskErrorCode, SessionVariant;
import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../../../../repositories/models/sesori_tool_group_ids.dart";
import "../../../../repositories/models/task_command_edit.dart";
import "../../../../services/scheduled_task_agent_service.dart";
import "../../models/sesori_mcp_tool_arguments.dart";
import "../in_app_tool_texts.dart";
import "scheduled_task_tool.dart";
import "scheduled_task_tool_result_formatter.dart";

/// Reading the scheduled tasks on this computer, and proposing changes the
/// user allows or rejects.
class ScheduledTaskToolGroup({
  required final ScheduledTaskAgentService _agent,
  required final ScheduledTaskToolResultFormatter _formatter,
}) implements SesoriToolGroup {
  /// Messages read for one transcript page before trimming it to size.
  static const int _transcriptMessages = 20;

  static const SesoriToolArgumentParser _arguments = SesoriToolArgumentParser(
    nestedPlaces: {},
    kindFields: {
      "schedule": {
        "once": ["at"],
        "daily": ["time"],
        "weekdays": ["time"],
        "weekly": ["days", "time"],
        "everyHours": ["hours", "start"],
      },
      "run_mode": {
        "newSession": [],
        "sameSession": ["autoCompact"],
      },
    },
  );

  static const String _appliesToNextRun =
      "Sent to the user for approval. If they allow it, it applies to the next run. $answerFollowsText";
  static const String _appliesOnAllow =
      "Sent to the user for approval. Nothing happens unless they allow it. $answerFollowsText";

  @override
  SesoriToolGroupId get id => SesoriToolGroupIds.tasks;

  @override
  String get title => "Scheduled tasks";

  @override
  String get summary => "Agents can read your scheduled tasks and their runs, and ask you to change them.";

  @override
  String get instructions =>
      "For the scheduled tasks on this computer, start with list_tasks; get_task without a task_id shows this "
      "session's own task when it is a scheduled run. Tools that change a task only send the user a request to "
      "allow; Sesori messages this session with their answer, so don't poll for it.";

  @override
  List<SesoriToolDefinition> get tools => [for (final tool in ScheduledTaskTool.values) tool.definition];

  @override
  Future<SesoriToolResult> call({
    required String tool,
    required SesoriToolCaller caller,
    required Map<String, Object?> arguments,
  }) async {
    final known = ScheduledTaskTool.values.firstWhere((candidate) => candidate.wireName == tool);
    switch (known) {
      case ScheduledTaskTool.listTasks:
        final args = _arguments.parse(json: arguments, fromJson: ListTasksArguments.fromJson);
        return switch (await _agent.listTasks(caller: caller, projectId: args.projectId)) {
          final AgentTaskList list => SesoriToolSuccess(text: _formatter.taskList(list: list)),
          AgentTaskListUnknownProject() => throw const InvalidToolArguments(
            reason: "project_id is not a known project; leave it out to list every task.",
          ),
        };
      case ScheduledTaskTool.getTask:
        final args = _arguments.parse(json: arguments, fromJson: GetTaskArguments.fromJson);
        return switch (await _agent.getTask(caller: caller, taskId: args.taskId)) {
          final AgentTaskFound found => SesoriToolSuccess(text: _formatter.task(found: found)),
          AgentTaskNotScheduledRun() => const SesoriToolFailure(
            text: "This session is not a scheduled task run. Pass a task_id from list_tasks.",
          ),
          AgentTaskNotFound(:final taskId) => SesoriToolFailure(text: _taskNotFound(taskId: taskId)),
        };
      case ScheduledTaskTool.listTaskRuns:
        final args = _arguments.parse(json: arguments, fromJson: TaskIdArguments.fromJson);
        return switch (await _agent.listTaskRuns(taskId: args.taskId)) {
          final AgentTaskRuns runs => SesoriToolSuccess(
            text: _formatter.runs(taskId: args.taskId, runs: runs),
          ),
          AgentTaskRunsTaskNotFound(:final taskId) => SesoriToolFailure(text: _taskNotFound(taskId: taskId)),
        };
      case ScheduledTaskTool.getTaskRunTranscript:
        final args = _arguments.parse(json: arguments, fromJson: GetTaskRunTranscriptArguments.fromJson);
        return await _transcript(args: args);
      case ScheduledTaskTool.createTask:
        final args = _arguments.parse(json: arguments, fromJson: CreateTaskArguments.fromJson);
        final proposal = await _agent.proposeCreate(
          caller: caller,
          projectId: args.projectId,
          task: AgentNewTask(
            name: args.name,
            promptText: args.prompt,
            schedule: args.schedule,
            timeZone: args.timeZone,
            missedRunPolicy: args.missedRunPolicy,
            runMode: args.runMode,
            model: _model(text: args.model),
            variant: _variant(id: args.effort),
            approvalMode: args.approvalMode,
            command: optionalToolText(value: args.command),
          ),
        );
        return _proposal(proposal: proposal, sent: _appliesToNextRun);
      case ScheduledTaskTool.updateTask:
        final args = _arguments.parse(json: arguments, fromJson: UpdateTaskArguments.fromJson);
        final proposal = await _agent.proposeUpdate(
          caller: caller,
          taskId: args.taskId,
          edits: AgentTaskEdits(
            name: args.name,
            promptText: args.prompt,
            commandArguments: args.commandArguments,
            schedule: args.schedule,
            timeZone: args.timeZone,
            missedRunPolicy: args.missedRunPolicy,
            runMode: args.runMode,
            model: _model(text: args.model),
            variant: _variant(id: args.effort),
            approvalMode: args.approvalMode,
            command: switch ((optionalToolText(value: args.command), args.removeCommand)) {
              (null, false) => const TaskCommandUnchanged(),
              (final command?, false) => TaskCommandSet(command: command),
              (null, true) => const TaskCommandRemoved(),
              (_?, true) => throw const InvalidToolArguments(reason: "Pass command or remove_command, not both."),
            },
          ),
        );
        return _proposal(proposal: proposal, sent: _appliesToNextRun);
      case ScheduledTaskTool.pauseTask || ScheduledTaskTool.resumeTask:
        final args = _arguments.parse(json: arguments, fromJson: TaskIdArguments.fromJson);
        final proposal = await _agent.proposeSetEnabled(
          caller: caller,
          taskId: args.taskId,
          enabled: known == ScheduledTaskTool.resumeTask,
        );
        return _proposal(proposal: proposal, sent: _appliesOnAllow);
      case ScheduledTaskTool.runTaskNow:
        final args = _arguments.parse(json: arguments, fromJson: TaskIdArguments.fromJson);
        final proposal = await _agent.proposeRunNow(caller: caller, taskId: args.taskId);
        return _proposal(proposal: proposal, sent: _appliesOnAllow);
    }
  }

  SesoriToolResult _proposal({required AgentProposal proposal, required String sent}) {
    return switch (proposal) {
      AgentProposalSent() => SesoriToolSuccess(text: sent),
      AgentProposalTaskNotFound(:final taskId) => SesoriToolFailure(text: _taskNotFound(taskId: taskId)),
      AgentProposalInvalid(:final code) => SesoriToolFailure(text: _invalid(code: code)),
      AgentProposalRefused(:final reason) => SesoriToolFailure(
        text: switch (reason) {
          AgentProposalRefusal.callerGone => callerGoneText,
          AgentProposalRefusal.nothingChanged => "That is the task as it is; nothing would change.",
          AgentProposalRefusal.promptIsCommand =>
            "This task runs a command, so its prompt cannot be text. Change command_arguments instead.",
          AgentProposalRefusal.promptIsText => "This task sends text, so it has no command_arguments. Change prompt.",
          AgentProposalRefusal.alreadyInState => "The task is already in that state.",
          AgentProposalRefusal.modelNotOffered =>
            "model is not one this task's harness offers. Leave it out unless the user named a model.",
          AgentProposalRefusal.shellCommandOnSlashCommand =>
            "This task runs a slash command, so it cannot also run a shell command first.",
        },
      ),
    };
  }

  String _invalid({required ScheduledTaskErrorCode code}) {
    return switch (code) {
      ScheduledTaskErrorCode.taskNotFound => "The task no longer exists. Find task ids with list_tasks.",
      ScheduledTaskErrorCode.emptyName => "The task needs a name.",
      ScheduledTaskErrorCode.emptyPrompt => "The task needs a prompt.",
      ScheduledTaskErrorCode.unknownProject => "Unknown project_id; find project ids with list_tasks.",
      ScheduledTaskErrorCode.unknownHarness => "This session's harness cannot run scheduled tasks.",
      ScheduledTaskErrorCode.unknownTimeZone => "Unknown time_zone; use an IANA name such as Europe/Bucharest.",
      ScheduledTaskErrorCode.invalidSchedule => "The schedule has an invalid date or time.",
      ScheduledTaskErrorCode.hoursOutOfRange => "schedule.hours must be 1 to 12.",
      ScheduledTaskErrorCode.onceTimeInPast => "schedule.at must be in the future.",
      ScheduledTaskErrorCode.unsupportedByBridge ||
      ScheduledTaskErrorCode.previousRunActive ||
      ScheduledTaskErrorCode.unknown => "This bridge cannot save that task.",
    };
  }

  /// `provider/model`; the model id may itself contain slashes.
  PromptModel? _model({required String? text}) {
    if (text == null) return null;
    final slash = text.indexOf("/");
    if (slash <= 0 || slash == text.length - 1) {
      throw const InvalidToolArguments(reason: "model must be provider/model.");
    }
    return PromptModel(providerID: text.substring(0, slash), modelID: text.substring(slash + 1));
  }

  SessionVariant? _variant({required String? id}) => id == null ? null : SessionVariant(id: id);

  /// The newest messages before `page` that fit one page. A page that
  /// overflows is read again with fewer messages, so `next_page` points just
  /// past what was shown.
  Future<SesoriToolResult> _transcript({required GetTaskRunTranscriptArguments args}) async {
    var limit = _transcriptMessages;
    while (true) {
      final lookup = await _agent.runTranscript(
        taskId: args.taskId,
        runId: args.runId,
        before: args.page,
        limit: limit,
      );
      switch (lookup) {
        case AgentRunTranscript(:final sessionId, :final messages, :final nextCursor):
          final blocks = _formatter.transcriptBlocks(messages: messages);
          final fitting = _formatter.newestFittingPage(blocks: blocks);
          if (fitting < blocks.length) {
            limit = fitting;
            continue;
          }
          return SesoriToolSuccess(
            text: _formatter.transcript(sessionId: sessionId, blocks: blocks, nextPage: nextCursor),
          );
        case AgentRunTranscriptTaskNotFound(:final taskId):
          return SesoriToolFailure(text: _taskNotFound(taskId: taskId));
        case AgentRunTranscriptRunNotFound(:final runId):
          return SesoriToolFailure(text: "No run $runId in task ${args.taskId}. Find run ids with list_task_runs.");
        case AgentRunTranscriptNoSession(:final run):
          return SesoriToolFailure(text: _formatter.runWithoutSession(run: run));
      }
    }
  }

  String _taskNotFound({required String taskId}) => "No scheduled task $taskId. Find task ids with list_tasks.";
}
