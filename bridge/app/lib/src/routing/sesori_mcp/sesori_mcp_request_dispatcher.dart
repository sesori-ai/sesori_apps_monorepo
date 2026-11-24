import "dart:async";
import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart" show CheckedFromJsonException, UnrecognizedKeysException;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PendingOperations, bridgeVersion;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, sesoriMcpServerName;
import "package:sesori_shared/sesori_shared.dart"
    show PromptModel, ScheduledTaskErrorCode, SessionVariant, TaskSchedule, TaskTimeOfDay, maxTranscriptImageBytes;

import "../../foundation/sesori_mcp_server.dart";
import "../../repositories/models/sesori_mcp_caller.dart";
import "../../repositories/models/session_wake_up.dart";
import "../../repositories/models/task_command_edit.dart";
import "../../services/agent_page_service.dart";
import "../../services/scheduled_task_agent_service.dart";
import "../../services/sesori_mcp_access_service.dart";
import "../../services/session_wake_up_service.dart";
import "models/sesori_mcp_rpc_request.dart";
import "models/sesori_mcp_tool_arguments.dart";
import "sesori_mcp_result_formatter.dart";
import "sesori_mcp_tool.dart";

/// Answers the JSON-RPC messages harnesses post to Sesori's MCP endpoint:
/// `initialize`, `ping`, `tools/list` and `tools/call`.
///
/// Hand-written instead of `package:dart_mcp`, whose server assumes one
/// long-lived stream per client and has no HTTP transport; here every POST is
/// independent and carries its caller's token.
class SesoriMcpRequestDispatcher({
  required final SesoriMcpAccessService _access,
  required final ScheduledTaskAgentService _agent,
  required final AgentPageService _pages,
  required final SessionWakeUpService _wakeUps,
  required final SesoriMcpResultFormatter _formatter,
}) {
  /// The protocol versions this server speaks, oldest first. `initialize`
  /// echoes the client's when listed and offers the newest otherwise.
  static const List<String> protocolVersions = ["2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"];

  /// Messages read for one transcript page before trimming it to size.
  static const int _transcriptMessages = 20;

  static const int _parseError = -32700;
  static const int _invalidRequest = -32600;
  static const int _methodNotFound = -32601;
  static const int _invalidParams = -32602;

  final PendingOperations _inFlight = PendingOperations();

  /// Answers one request. Every failure becomes a reply, so this never throws.
  Future<SesoriMcpReply> dispatch({required String token, required String body}) {
    final reply = _dispatch(token: token, body: body);
    unawaited(_inFlight.track(operation: reply));
    return reply;
  }

  /// Waits for the answers in flight, so shutdown does not close the
  /// database under a tool's read.
  Future<void> drain() => _inFlight.drain();

  Future<SesoriMcpReply> _dispatch({required String token, required String body}) async {
    if (!_access.isMinted(token: token)) return const SesoriMcpUnauthorizedReply();

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return _error(id: null, code: _parseError, message: "The body is not JSON.");
    }
    if (decoded is! Map<String, dynamic>) {
      return _error(id: null, code: _invalidRequest, message: "Expected one JSON-RPC message.");
    }
    final SesoriMcpRpcRequest request;
    try {
      request = SesoriMcpRpcRequest.fromJson(decoded);
    } on Object {
      return _error(id: decoded["id"], code: _invalidRequest, message: "Not a JSON-RPC request.");
    }
    if (!decoded.containsKey("id")) return const SesoriMcpAcceptedReply();

    final id = request.id;
    switch (request.method) {
      case "initialize":
        return _result(
          id: id,
          result: _initialize(params: request.params),
        );
      case "ping":
        return _result(id: id, result: const <String, Object?>{});
      case "tools/list":
        return _result(id: id, result: _toolList());
      case "tools/call":
        final SesoriMcpToolCall call;
        try {
          call = SesoriMcpToolCall.fromJson(request.params ?? const {});
        } on Object {
          return _error(id: id, code: _invalidParams, message: "tools/call needs a tool name.");
        }
        final tool = SesoriMcpTool.fromWireName(name: call.name);
        if (tool == null) return _error(id: id, code: _invalidParams, message: "Unknown tool: ${call.name}");
        return _result(
          id: id,
          result: await _call(token: token, tool: tool, arguments: call.arguments ?? const {}),
        );
      default:
        return _error(id: id, code: _methodNotFound, message: "Method not found: ${request.method}");
    }
  }

  Map<String, Object?> _initialize({required Map<String, dynamic>? params}) {
    String? requested;
    try {
      requested = params == null ? null : SesoriMcpInitializeParams.fromJson(params).protocolVersion;
    } on Object {
      requested = null;
    }
    return {
      "protocolVersion": protocolVersions.contains(requested) ? requested : protocolVersions.last,
      "capabilities": {
        "tools": {"listChanged": false},
      },
      "serverInfo": {"name": sesoriMcpServerName, "version": bridgeVersion},
      "instructions":
          "Sesori's tools for asking the user and for the scheduled tasks on this computer. send_page asks the "
          "user on a page in the Sesori app. For tasks, start with list_tasks; get_task without a task_id shows "
          "this session's own task when it is a scheduled run. Tools that change a task only send the user a "
          "request to allow. Pages and requests return at once and are answered on their own; Sesori messages "
          "this session with the user's answer, so don't poll for it. schedule_wakeup has Sesori send this "
          "session a prompt later, as a message; use it instead of a harness timer, because the user can see and "
          "cancel it.",
    };
  }

  Map<String, Object?> _toolList() {
    return {
      "tools": [
        for (final tool in SesoriMcpTool.values)
          {
            "name": tool.wireName,
            "description": tool.description,
            "inputSchema": tool.inputSchema,
            "annotations": {"readOnlyHint": tool.readOnly},
          },
      ],
    };
  }

  /// A tool result. Failures an agent can act on come back as `isError`
  /// results rather than protocol errors, so the agent reads them.
  Future<Map<String, Object?>> _call({
    required String token,
    required SesoriMcpTool tool,
    required Map<String, dynamic> arguments,
  }) async {
    final _ToolOutcome outcome;
    try {
      final caller = await _access.resolve(token: token);
      if (caller == null) {
        return _toolResult(
          text: "This session is not linked to a Sesori session yet. Try again in a moment.",
          isError: true,
        );
      }
      outcome = await _run(tool: tool, caller: caller, arguments: arguments);
    } on _InvalidArguments catch (error) {
      return _toolResult(text: "Invalid arguments for ${tool.wireName}: ${error.reason}", isError: true);
    } on Object catch (error, stackTrace) {
      // The tool name only: results and arguments can hold transcripts.
      Log.w("Sesori MCP tool ${tool.wireName} failed", error, stackTrace);
      return _toolResult(text: "${tool.wireName} failed on the bridge.", isError: true);
    }
    return _toolResult(text: outcome.text, isError: outcome.isError);
  }

  Future<_ToolOutcome> _run({
    required SesoriMcpTool tool,
    required SesoriMcpCaller caller,
    required Map<String, dynamic> arguments,
  }) async {
    switch (tool) {
      case SesoriMcpTool.listTasks:
        final args = _parse(json: arguments, fromJson: ListTasksArguments.fromJson);
        return switch (await _agent.listTasks(caller: caller, projectId: args.projectId)) {
          final AgentTaskList list => _ToolOutcome(isError: false, text: _formatter.taskList(list: list)),
          AgentTaskListUnknownProject() => throw const _InvalidArguments(
            reason: "project_id is not a known project; leave it out to list every task.",
          ),
        };
      case SesoriMcpTool.getTask:
        final args = _parse(json: arguments, fromJson: GetTaskArguments.fromJson);
        return switch (await _agent.getTask(caller: caller, taskId: args.taskId)) {
          final AgentTaskFound found => _ToolOutcome(isError: false, text: _formatter.task(found: found)),
          AgentTaskNotScheduledRun() => const _ToolOutcome(
            isError: true,
            text: "This session is not a scheduled task run. Pass a task_id from list_tasks.",
          ),
          AgentTaskNotFound(:final taskId) => _ToolOutcome(isError: true, text: _taskNotFound(taskId: taskId)),
        };
      case SesoriMcpTool.listTaskRuns:
        final args = _parse(json: arguments, fromJson: TaskIdArguments.fromJson);
        return switch (await _agent.listTaskRuns(taskId: args.taskId)) {
          final AgentTaskRuns runs => _ToolOutcome(
            isError: false,
            text: _formatter.runs(taskId: args.taskId, runs: runs),
          ),
          AgentTaskRunsTaskNotFound(:final taskId) => _ToolOutcome(isError: true, text: _taskNotFound(taskId: taskId)),
        };
      case SesoriMcpTool.getTaskRunTranscript:
        final args = _parse(json: arguments, fromJson: GetTaskRunTranscriptArguments.fromJson);
        return await _transcript(args: args);
      case SesoriMcpTool.createTask:
        final args = _parse(json: arguments, fromJson: CreateTaskArguments.fromJson);
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
            command: _optionalText(value: args.command),
          ),
        );
        return _proposal(proposal: proposal, sent: _appliesToNextRun);
      case SesoriMcpTool.updateTask:
        final args = _parse(json: arguments, fromJson: UpdateTaskArguments.fromJson);
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
            command: switch ((_optionalText(value: args.command), args.removeCommand)) {
              (null, false) => const TaskCommandUnchanged(),
              (final command?, false) => TaskCommandSet(command: command),
              (null, true) => const TaskCommandRemoved(),
              (_?, true) => throw const _InvalidArguments(reason: "Pass command or remove_command, not both."),
            },
          ),
        );
        return _proposal(proposal: proposal, sent: _appliesToNextRun);
      case SesoriMcpTool.pauseTask || SesoriMcpTool.resumeTask:
        final args = _parse(json: arguments, fromJson: TaskIdArguments.fromJson);
        final proposal = await _agent.proposeSetEnabled(
          caller: caller,
          taskId: args.taskId,
          enabled: tool == SesoriMcpTool.resumeTask,
        );
        return _proposal(proposal: proposal, sent: _appliesOnAllow);
      case SesoriMcpTool.runTaskNow:
        final args = _parse(json: arguments, fromJson: TaskIdArguments.fromJson);
        final proposal = await _agent.proposeRunNow(caller: caller, taskId: args.taskId);
        return _proposal(proposal: proposal, sent: _appliesOnAllow);
      case SesoriMcpTool.sendPage:
        final args = _parse(json: arguments, fromJson: SendPageArguments.fromJson);
        return _pageSent(
          result: await _pages.send(
            caller: caller,
            draft: _pageDraft(args: args),
          ),
        );
      case SesoriMcpTool.scheduleWakeUp:
        final args = _parse(json: arguments, fromJson: ScheduleWakeUpArguments.fromJson);
        return _wakeUpScheduled(
          result: await _wakeUps.schedule(
            caller: caller,
            label: _requiredText(value: args.label, field: "label"),
            prompt: _requiredText(value: args.prompt, field: "prompt"),
            when: _wakeUpTime(when: args.when),
            timeZone: _optionalText(value: args.timeZone),
            command: _optionalText(value: args.command),
          ),
        );
      case SesoriMcpTool.listWakeUps:
        return switch (await _wakeUps.list(caller: caller)) {
          WakeUpList(:final wakeUps) => _ToolOutcome(isError: false, text: _formatter.wakeUpList(wakeUps: wakeUps)),
          WakeUpListCallerGone() => const _ToolOutcome(isError: true, text: _callerGone),
        };
      case SesoriMcpTool.cancelWakeUp:
        final args = _parse(json: arguments, fromJson: CancelWakeUpArguments.fromJson);
        final wakeUpId = args.wakeUpId;
        return switch (await _wakeUps.cancel(sessionId: caller.sessionId, wakeUpId: wakeUpId)) {
          WakeUpCancelResult.cancelled => _ToolOutcome(isError: false, text: "Cancelled wake-up $wakeUpId."),
          WakeUpCancelResult.notFound => _ToolOutcome(
            isError: true,
            text: "This session has no wake-up $wakeUpId. Find ids with list_wakeups.",
          ),
          WakeUpCancelResult.callerGone => const _ToolOutcome(isError: true, text: _callerGone),
        };
    }
  }

  static const String _callerGone = "This session is no longer known to Sesori.";

  _ToolOutcome _wakeUpScheduled({required WakeUpScheduleResult result}) {
    return switch (result) {
      WakeUpScheduled(:final wakeUp) => _ToolOutcome(isError: false, text: _formatter.wakeUpScheduled(wakeUp: wakeUp)),
      WakeUpAwaitingApproval() => const _ToolOutcome(
        isError: false,
        text:
            "Sent to the user for approval, because it runs a command. Nothing is set unless they allow it. "
            "$_answerFollows End your turn now; don't wait or poll.",
      ),
      WakeUpRefused(:final reason) => _ToolOutcome(
        isError: true,
        text: switch (reason) {
          WakeUpRefusal.callerGone => _callerGone,
          WakeUpRefusal.labelTooLong => "label is longer than ${SessionWakeUpService.maxLabelLength} characters.",
          WakeUpRefusal.minutesOutOfRange => "when.minutes must be 1 to ${SessionWakeUpService.maxMinutes} (a week).",
          WakeUpRefusal.noDays => "when.days needs at least one day.",
          WakeUpRefusal.unknownTimeZone => "Unknown time_zone; use an IANA name such as Europe/Bucharest.",
          WakeUpRefusal.timeZoneNeeded =>
            "The bridge cannot tell this computer's time zone; pass time_zone, such as Europe/Bucharest.",
        },
      ),
    };
  }

  WakeUpRequestedTime _wakeUpTime({required WakeUpWhenArgument when}) {
    return switch (when) {
      WakeUpWhenAfterArgument(:final minutes) => WakeUpInMinutes(minutes: minutes),
      WakeUpWhenEveryArgument(:final minutes) => WakeUpEveryMinutes(minutes: minutes),
      WakeUpWhenDailyArgument(:final time) => WakeUpOnSchedule(
        schedule: TaskSchedule.daily(time: _clockTime(text: time)),
      ),
      WakeUpWhenWeekdaysArgument(:final time) => WakeUpOnSchedule(
        schedule: TaskSchedule.weekdays(time: _clockTime(text: time)),
      ),
      WakeUpWhenWeeklyArgument(:final days, :final time) => WakeUpOnSchedule(
        schedule: TaskSchedule.weekly(
          days: days,
          time: _clockTime(text: time),
        ),
      ),
    };
  }

  static final RegExp _clockTimePattern = RegExp(r"^([01]?\d|2[0-3]):([0-5]\d)$");

  /// [text] as `HH:MM`, 24-hour.
  TaskTimeOfDay _clockTime({required String text}) {
    return switch (_clockTimePattern.firstMatch(text.trim())?.groups([1, 2])) {
      [final String hour, final String minute] => TaskTimeOfDay(hour: int.parse(hour), minute: int.parse(minute)),
      _ => throw const _InvalidArguments(reason: "when.time must be HH:MM, from 00:00 to 23:59."),
    };
  }

  static const String _appliesToNextRun =
      "Sent to the user for approval. If they allow it, it applies to the next run. $_answerFollows";
  static const String _appliesOnAllow =
      "Sent to the user for approval. Nothing happens unless they allow it. $_answerFollows";
  static const String _answerFollows = "Sesori will message this session with their answer.";

  static const int _mebibyte = 1024 * 1024;

  _ToolOutcome _pageSent({required AgentPageSendResult result}) {
    final text = switch (result) {
      AgentPageSent(:final page) => "Sent “${page.title}” to the user. $_answerFollows",
      AgentPageCallerGone() => _callerGone,
      AgentPageOverLimit(limit: AgentPageLimit.titleLength) =>
        "title is longer than ${AgentPageService.maxTitleLength} characters.",
      AgentPageOverLimit(limit: AgentPageLimit.images) =>
        "The page has more than ${AgentPageService.maxImages} images.",
      AgentPageOverLimit(limit: AgentPageLimit.questions) =>
        "The page has more than ${AgentPageService.maxQuestions} questions.",
      AgentPageOverLimit(limit: AgentPageLimit.imageBytes) =>
        "The page's images are over ${AgentPageService.maxPageImageBytes ~/ _mebibyte} MiB together.",
      AgentPageTooManyOptions(:final questionId) =>
        "Question $questionId has more than ${AgentPageService.maxOptions} options.",
      AgentPageDuplicateQuestionId(:final questionId) => "Two questions have the id $questionId.",
      AgentPageDuplicateOptionId(:final questionId, :final optionId) =>
        "Question $questionId has two options with the id $optionId.",
      AgentPageImageRejected(:final path, :final problem) => switch (problem) {
        AgentPageImageProblem.notAbsolute => "Image path $path is not absolute.",
        AgentPageImageProblem.missing => "No file at image path $path.",
        AgentPageImageProblem.denied => "The bridge may not read image path $path.",
        AgentPageImageProblem.tooLarge => "The image at $path is over ${maxTranscriptImageBytes ~/ _mebibyte} MiB.",
        AgentPageImageProblem.notImage => "The file at $path is not a png, jpg, gif or webp image.",
      },
    };
    return _ToolOutcome(isError: result is! AgentPageSent, text: text);
  }

  /// [args] as the page service takes them. Strict-schema providers fill
  /// fields they leave out with "", so an empty optional text reads as
  /// absent, an empty required one as missing, and an image with neither a
  /// path nor a caption as no image.
  AgentPageDraft _pageDraft({required SendPageArguments args}) {
    return AgentPageDraft(
      title: _requiredText(value: args.title, field: "title"),
      intro: _optionalText(value: args.intro),
      sections: [
        for (final (sectionIndex, section) in args.sections.indexed)
          AgentPageSectionDraft(
            heading: _optionalText(value: section.heading),
            body: _optionalText(value: section.body),
            images: _pageImages(images: section.images ?? const [], field: "sections[$sectionIndex].images"),
            questions: [
              for (final (questionIndex, question) in (section.questions ?? const <PageQuestionArgument>[]).indexed)
                _pageQuestion(question: question, field: "sections[$sectionIndex].questions[$questionIndex]"),
            ],
          ),
      ],
    );
  }

  AgentPageQuestionDraft _pageQuestion({required PageQuestionArgument question, required String field}) {
    final options = [
      for (final (index, option) in (question.options ?? const <PageOptionArgument>[]).indexed)
        AgentPageOptionDraft(
          id: _requiredText(value: option.id, field: "$field.options[$index].id"),
          label: _requiredText(value: option.label, field: "$field.options[$index].label"),
          description: _optionalText(value: option.description),
          image: switch (option.image) {
            final image? => _pageImage(image: image, field: "$field.options[$index].image"),
            null => null,
          },
          recommended: option.recommended,
        ),
    ];
    return AgentPageQuestionDraft(
      id: _requiredText(value: question.id, field: "$field.id"),
      title: _requiredText(value: question.title, field: "$field.title"),
      body: _optionalText(value: question.body),
      images: _pageImages(images: question.images ?? const [], field: "$field.images"),
      kind: switch (question.kind) {
        PageQuestionKindArgument.single || PageQuestionKindArgument.multiple when options.isEmpty =>
          throw _InvalidArguments(reason: "$field.options is required when its kind is ${question.kind.name}."),
        PageQuestionKindArgument.single => AgentPageSingleChoiceDraft(options: options),
        PageQuestionKindArgument.multiple => AgentPageMultipleChoiceDraft(options: options),
        PageQuestionKindArgument.text when options.isEmpty => const AgentPageTextDraft(),
        PageQuestionKindArgument.text => throw _InvalidArguments(
          reason: "$field.options are only for single and multiple questions.",
        ),
      },
      isRequired: question.required,
    );
  }

  List<AgentPageImageDraft> _pageImages({required List<PageImageArgument> images, required String field}) => [
    for (final (index, image) in images.indexed) ?_pageImage(image: image, field: "$field[$index]"),
  ];

  /// [image] as the page service takes it, or null for an image with an empty
  /// path and no caption, which is how strict-schema providers fill in one
  /// they leave out.
  AgentPageImageDraft? _pageImage({required PageImageArgument image, required String field}) {
    final caption = _optionalText(value: image.caption);
    if (caption == null && image.path.trim().isEmpty) return null;
    return AgentPageImageDraft(
      path: _requiredText(value: image.path, field: "$field.path"),
      caption: caption,
    );
  }

  String _requiredText({required String value, required String field}) {
    if (value.trim().isEmpty) throw _InvalidArguments(reason: "$field is required.");
    return value;
  }

  String? _optionalText({required String? value}) => value == null || value.trim().isEmpty ? null : value;

  _ToolOutcome _proposal({required AgentProposal proposal, required String sent}) {
    return switch (proposal) {
      AgentProposalSent() => _ToolOutcome(isError: false, text: sent),
      AgentProposalTaskNotFound(:final taskId) => _ToolOutcome(isError: true, text: _taskNotFound(taskId: taskId)),
      AgentProposalInvalid(:final code) => _ToolOutcome(isError: true, text: _invalid(code: code)),
      AgentProposalRefused(:final reason) => _ToolOutcome(
        isError: true,
        text: switch (reason) {
          AgentProposalRefusal.callerGone => _callerGone,
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
      throw const _InvalidArguments(reason: "model must be provider/model.");
    }
    return PromptModel(providerID: text.substring(0, slash), modelID: text.substring(slash + 1));
  }

  SessionVariant? _variant({required String? id}) => id == null ? null : SessionVariant(id: id);

  /// The newest messages before `page` that fit one page. A page that
  /// overflows is read again with fewer messages, so `next_page` points just
  /// past what was shown.
  Future<_ToolOutcome> _transcript({required GetTaskRunTranscriptArguments args}) async {
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
          return _ToolOutcome(
            isError: false,
            text: _formatter.transcript(sessionId: sessionId, blocks: blocks, nextPage: nextCursor),
          );
        case AgentRunTranscriptTaskNotFound(:final taskId):
          return _ToolOutcome(isError: true, text: _taskNotFound(taskId: taskId));
        case AgentRunTranscriptRunNotFound(:final runId):
          return _ToolOutcome(
            isError: true,
            text: "No run $runId in task ${args.taskId}. Find run ids with list_task_runs.",
          );
        case AgentRunTranscriptNoSession(:final run):
          return _ToolOutcome(isError: true, text: _formatter.runWithoutSession(run: run));
      }
    }
  }

  String _taskNotFound({required String taskId}) => "No scheduled task $taskId. Find task ids with list_tasks.";

  /// Reads [json] as a tool's arguments, or throws [_InvalidArguments]
  /// naming the field that is wrong.
  ///
  /// Strict-schema providers make the model fill every field, and it fills
  /// the ones it means to leave out with "". No argument has a meaningful
  /// empty value, so an empty string reads as absent.
  T _parse<T>({required Map<String, dynamic> json, required T Function(Map<String, dynamic> json) fromJson}) {
    final present = {
      for (final MapEntry(:key, :value) in json.entries)
        if (value != "") key: value,
    };
    _checkKinds(json: present);
    try {
      return fromJson(present);
    } on CheckedFromJsonException catch (error) {
      // A nested argument's failure names only its own key, so its place
      // in the arguments comes from the model that failed.
      final place = _nestedArgumentPlaces[error.className] ?? "";
      final reason = switch (error.key) {
        final key? when error.map[key] == null => "$place$key is required.",
        final key? => "$place$key is not valid; see its input schema.",
        null => switch (error.innerError) {
          UnrecognizedKeysException(:final unrecognizedKeys) =>
            "$place${unrecognizedKeys.first} is not an argument; see its input schema.",
          _ => _seeSchema,
        },
      };
      throw _InvalidArguments(reason: reason);
    } on Object {
      throw const _InvalidArguments(reason: _seeSchema);
    }
  }

  static const String _seeSchema = "see its input schema.";

  /// Where each nested page argument sits, keyed by the class checked
  /// decoding reports: Freezed's generated `_<Model>` for each model, so a
  /// renamed model fails to compile here instead of losing its place.
  static final Map<String, String> _nestedArgumentPlaces = {
    "_$PageSectionArgument": "sections[].",
    "_$PageQuestionArgument": "sections[].questions[].",
    "_$PageOptionArgument": "sections[].questions[].options[].",
    "_$PageImageArgument": "images[].",
  };

  /// The fields each kind of a nested argument needs, as its schema
  /// describes them. The shared models read an unknown kind as unknown and
  /// fail on a missing field without naming it, so both are checked here.
  static const Map<String, Map<String, List<String>>> _kindFields = {
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
    "when": {
      "in": ["minutes"],
      "every": ["minutes"],
      "daily": ["time"],
      "weekdays": ["time"],
      "weekly": ["days", "time"],
    },
  };

  void _checkKinds({required Map<String, dynamic> json}) {
    for (final MapEntry(key: field, value: kinds) in _kindFields.entries) {
      if (json[field] case final Map<String, dynamic> value) {
        final kind = value["kind"];
        final needed = kinds[kind];
        if (needed == null) {
          throw _InvalidArguments(reason: "$field.kind must be one of ${kinds.keys.join(", ")}.");
        }
        for (final subfield in needed) {
          if (value[subfield] == null) {
            throw _InvalidArguments(reason: "$field.$subfield is required when $field.kind is $kind.");
          }
        }
      }
    }
  }

  Map<String, Object?> _toolResult({required String text, required bool isError}) {
    return {
      "content": [
        {"type": "text", "text": text},
      ],
      "isError": isError,
    };
  }

  SesoriMcpReply _result({required Object? id, required Map<String, Object?> result}) {
    return SesoriMcpJsonReply(body: jsonEncode({"jsonrpc": "2.0", "id": id, "result": result}));
  }

  SesoriMcpReply _error({required Object? id, required int code, required String message}) {
    return SesoriMcpJsonReply(
      body: jsonEncode({
        "jsonrpc": "2.0",
        "id": id,
        "error": {"code": code, "message": message},
      }),
    );
  }
}

final class const _ToolOutcome({required final String text, required final bool isError});

/// [reason] names the field and is shown to the agent.
final class const _InvalidArguments({required final String reason}) implements Exception;
