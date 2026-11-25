import "dart:convert";
import "dart:io" show WebSocket;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../api/opencode_v2_api.dart";
import "../api/sesori_bridge_mcp_api.dart";
import "../models/v2_client_mcp_frame.dart";

/// OpenCode's client-MCP sockets on one side and the bridge's MCP endpoint on
/// the other: opens a folder's socket, reads what OpenCode asks, and answers.
class V2SesoriToolsRepository({required final OpenCodeV2Api _api, required final SesoriBridgeMcpApi _bridge}) {
  static const int _internalError = -32603;

  Future<WebSocket> connect({required String directory}) =>
      _api.connectClientMcp(directory: directory, name: sesoriMcpServerName);

  /// The request in [frame], or null for a notification, a reply or anything
  /// that is not JSON-RPC.
  V2ClientMcpRequest? parse({required Object? frame}) {
    if (frame is! String) return null;
    final V2ClientMcpFrame message;
    try {
      message = V2ClientMcpFrame.fromJson(jsonDecodeMap(frame));
    } on FormatException {
      return null;
    }
    final id = message.id;
    if (id == null) return null;
    return switch ((message.method, message.params?.meta?.sessionId)) {
      (null, _) => null,
      ("tools/list", _) => V2ClientMcpListing(id: id, frame: frame),
      ("tools/call", final sessionId?) => V2ClientMcpSessionCall(id: id, frame: frame, sessionId: sessionId),
      ("tools/call", null) => V2ClientMcpUnattributedCall(id: id, frame: frame),
      (_, _) => V2ClientMcpOtherRequest(id: id, frame: frame),
    };
  }

  /// The bridge's reply to [request] for [launch]'s token. Throws when the
  /// bridge does not answer.
  Future<String> forward({required V2ClientMcpRequest request, required SesoriMcpLaunch launch}) =>
      _bridge.send(launch: launch, message: request.frame);

  /// A JSON-RPC error for a request the bridge did not answer.
  String unanswered({required V2ClientMcpRequest request}) => jsonEncode({
    "jsonrpc": "2.0",
    "id": request.id,
    "error": {"code": _internalError, "message": "The Sesori bridge did not answer."},
  });

  /// A tool result the agent reads as a failed call.
  String toolError({required V2ClientMcpRequest request, required String text}) => jsonEncode({
    "jsonrpc": "2.0",
    "id": request.id,
    "result": {
      "content": [
        {"type": "text", "text": text},
      ],
      "isError": true,
    },
  });
}
