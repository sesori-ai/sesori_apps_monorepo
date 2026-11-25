import "package:freezed_annotation/freezed_annotation.dart";

part "v2_client_mcp_frame.freezed.dart";
part "v2_client_mcp_frame.g.dart";

/// One JSON-RPC message OpenCode sends over a client-MCP socket, as decoded.
/// [V2ClientMcpRequest] is what the plugin acts on.
@Freezed(copyWith: false, toJson: false)
sealed class V2ClientMcpFrame with _$V2ClientMcpFrame {
  const factory({
    /// Absent on notifications.
    required Object? id,
    @JsonKey(fromJson: _textOrNull) required String? method,
    required V2ClientMcpParams? params,
  }) = _V2ClientMcpFrame;

  factory fromJson(Map<String, dynamic> json) => _$V2ClientMcpFrameFromJson(json);
}

@Freezed(copyWith: false, toJson: false)
sealed class V2ClientMcpParams with _$V2ClientMcpParams {
  const factory({@JsonKey(name: "_meta") required V2ClientMcpMeta? meta}) = _V2ClientMcpParams;

  factory fromJson(Map<String, dynamic> json) => _$V2ClientMcpParamsFromJson(json);
}

@Freezed(copyWith: false, toJson: false)
sealed class V2ClientMcpMeta with _$V2ClientMcpMeta {
  const factory({
    /// The OpenCode session whose step made a `tools/call`.
    @JsonKey(name: "ai.opencode/sessionID", fromJson: _textOrNull) required String? sessionId,
  }) = _V2ClientMcpMeta;

  factory fromJson(Map<String, dynamic> json) => _$V2ClientMcpMetaFromJson(json);
}

String? _textOrNull(Object? value) => value is String ? value : null;

/// A request OpenCode sends over a client-MCP socket. [frame] is the message
/// as received, relayed to the bridge unchanged.
sealed class V2ClientMcpRequest({required final Object id, required final String frame});

/// `tools/list`; OpenCode registers the tools once it has the reply.
final class V2ClientMcpListing({required super.id, required super.frame}) extends V2ClientMcpRequest;

/// A `tools/call` made by OpenCode session [sessionId].
final class V2ClientMcpSessionCall({required super.id, required super.frame, required final String sessionId})
    extends V2ClientMcpRequest;

/// A `tools/call` that names no session.
final class V2ClientMcpUnattributedCall({required super.id, required super.frame}) extends V2ClientMcpRequest;

/// Any other request, such as `initialize`.
final class V2ClientMcpOtherRequest({required super.id, required super.frame}) extends V2ClientMcpRequest;
