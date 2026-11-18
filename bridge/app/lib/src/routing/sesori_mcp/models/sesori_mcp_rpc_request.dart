import "package:freezed_annotation/freezed_annotation.dart";

part "sesori_mcp_rpc_request.freezed.dart";
part "sesori_mcp_rpc_request.g.dart";

/// One JSON-RPC 2.0 message a harness posts. Without an [id] it is a
/// notification, which gets no response.
@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class SesoriMcpRpcRequest with _$SesoriMcpRpcRequest {
  const factory({
    /// A string or a number, echoed back verbatim.
    required Object? id,
    required String method,
    required Map<String, dynamic>? params,
  }) = _SesoriMcpRpcRequest;

  factory fromJson(Map<String, dynamic> json) => _$SesoriMcpRpcRequestFromJson(json);
}

/// The `initialize` request's parameters this server reads.
@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class SesoriMcpInitializeParams with _$SesoriMcpInitializeParams {
  const factory({required String? protocolVersion}) = _SesoriMcpInitializeParams;

  factory fromJson(Map<String, dynamic> json) => _$SesoriMcpInitializeParamsFromJson(json);
}

/// The `tools/call` request's parameters.
@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class SesoriMcpToolCall with _$SesoriMcpToolCall {
  const factory({required String name, required Map<String, dynamic>? arguments}) = _SesoriMcpToolCall;

  factory fromJson(Map<String, dynamic> json) => _$SesoriMcpToolCallFromJson(json);
}
