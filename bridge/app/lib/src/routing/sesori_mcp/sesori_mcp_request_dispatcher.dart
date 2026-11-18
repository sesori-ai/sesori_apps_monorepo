import "dart:async";
import "dart:convert";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PendingOperations, bridgeVersion;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, sesoriMcpServerName;

import "../../foundation/sesori_mcp_server.dart";
import "../../repositories/models/sesori_mcp_caller.dart";
import "../../services/scheduled_task_agent_service.dart";
import "../../services/sesori_mcp_access_service.dart";
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
          "Sesori's tools for the scheduled tasks on this computer. Start with list_tasks; get_task without a "
          "task_id shows this session's own task when it is a scheduled run. Tools that change a task only send "
          "the user a request to allow; they return before the user answers.",
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
    } on _InvalidArguments {
      return _toolResult(text: "Invalid arguments for ${tool.wireName}; see its input schema.", isError: true);
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
        final list = await _agent.listTasks(caller: caller, projectId: args.projectId);
        return _ToolOutcome(isError: false, text: _formatter.taskList(list: list));
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
      case SesoriMcpTool.pauseTask || SesoriMcpTool.resumeTask:
        final args = _parse(json: arguments, fromJson: TaskIdArguments.fromJson);
        final proposal = await _agent.proposeSetEnabled(
          caller: caller,
          taskId: args.taskId,
          enabled: tool == SesoriMcpTool.resumeTask,
        );
        return _proposal(proposal: proposal);
      case SesoriMcpTool.runTaskNow:
        final args = _parse(json: arguments, fromJson: TaskIdArguments.fromJson);
        final proposal = await _agent.proposeRunNow(caller: caller, taskId: args.taskId);
        return _proposal(proposal: proposal);
    }
  }

  _ToolOutcome _proposal({required AgentProposal proposal}) {
    const sent = "Sent to the user for approval. Nothing happens unless they allow it.";
    return switch (proposal) {
      AgentProposalSent(withdrewPrevious: false) => const _ToolOutcome(isError: false, text: sent),
      AgentProposalSent(withdrewPrevious: true) => const _ToolOutcome(
        isError: false,
        text: "$sent It replaces this session's earlier request, which can no longer be allowed.",
      ),
      AgentProposalTaskNotFound(:final taskId) => _ToolOutcome(isError: true, text: _taskNotFound(taskId: taskId)),
      AgentProposalRefused(:final reason) => _ToolOutcome(
        isError: true,
        text: switch (reason) {
          AgentProposalRefusal.callerGone => "This session is no longer known to Sesori.",
          AgentProposalRefusal.alreadyInState => "The task is already in that state.",
        },
      ),
    };
  }

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

  T _parse<T>({required Map<String, dynamic> json, required T Function(Map<String, dynamic> json) fromJson}) {
    try {
      return fromJson(json);
    } on Object {
      throw const _InvalidArguments();
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

final class const _InvalidArguments() implements Exception;
