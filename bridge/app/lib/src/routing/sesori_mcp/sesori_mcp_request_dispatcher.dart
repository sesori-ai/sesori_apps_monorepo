import "dart:async";
import "dart:convert";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PendingOperations, bridgeVersion;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, sesoriMcpServerName;
import "package:sesori_tool_interface/sesori_tool_interface.dart"
    show InvalidToolArguments, SesoriToolFailure, SesoriToolGroup, SesoriToolResult;

import "../../foundation/sesori_mcp_server.dart";
import "../../services/sesori_mcp_access_service.dart";
import "models/sesori_mcp_rpc_request.dart";

/// Answers the JSON-RPC messages harnesses post to Sesori's MCP endpoint:
/// `initialize`, `ping`, `tools/list` and `tools/call`.
///
/// Hand-written instead of `package:dart_mcp`, whose server assumes one
/// long-lived stream per client and has no HTTP transport; here every POST is
/// independent and carries its caller's token.
///
/// Each tool belongs to one [SesoriToolGroup]; the dispatcher lists the
/// groups' tools and routes each call to its group.
class SesoriMcpRequestDispatcher({
  required final SesoriMcpAccessService _access,
  required final List<SesoriToolGroup> _groups,
}) {
  this : assert(_uniqueToolNames(groups: _groups), "Two Sesori tool groups offer a tool of the same name.");

  /// The protocol versions this server speaks, oldest first. `initialize`
  /// echoes the client's when listed and offers the newest otherwise.
  static const List<String> protocolVersions = ["2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"];

  static const String _instructionsLead = "Sesori's tools, served by the Sesori bridge on this computer.";

  static const int _parseError = -32700;
  static const int _invalidRequest = -32600;
  static const int _methodNotFound = -32601;
  static const int _invalidParams = -32602;

  final PendingOperations _inFlight = PendingOperations();

  /// The group that answers each tool, by tool name.
  late final Map<String, SesoriToolGroup> _owners = {
    for (final group in _groups)
      for (final tool in group.tools) tool.name: group,
  };

  static bool _uniqueToolNames({required List<SesoriToolGroup> groups}) {
    final names = [
      for (final group in groups)
        for (final tool in group.tools) tool.name,
    ];
    return names.length == names.toSet().length;
  }

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
        final group = _owners[call.name];
        if (group == null) return _error(id: id, code: _invalidParams, message: "Unknown tool: ${call.name}");
        return _result(
          id: id,
          result: await _call(token: token, group: group, tool: call.name, arguments: call.arguments ?? const {}),
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
      "instructions": [_instructionsLead, for (final group in _groups) group.instructions].join(" "),
    };
  }

  Map<String, Object?> _toolList() {
    return {
      "tools": [
        for (final group in _groups)
          for (final tool in group.tools)
            {
              "name": tool.name,
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
    required SesoriToolGroup group,
    required String tool,
    required Map<String, dynamic> arguments,
  }) async {
    final SesoriToolResult result;
    try {
      final caller = await _access.resolve(token: token);
      if (caller == null) {
        return _toolResult(
          text: "This session is not linked to a Sesori session yet. Try again in a moment.",
          isError: true,
        );
      }
      result = await group.call(tool: tool, caller: caller, arguments: arguments);
    } on InvalidToolArguments catch (error) {
      return _toolResult(text: "Invalid arguments for $tool: ${error.reason}", isError: true);
    } on Object catch (error, stackTrace) {
      // The tool name only: results and arguments can hold transcripts.
      Log.w("Sesori MCP tool $tool failed", error, stackTrace);
      return _toolResult(text: "$tool failed on the bridge.", isError: true);
    }
    return _toolResult(text: result.text, isError: result is SesoriToolFailure);
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
