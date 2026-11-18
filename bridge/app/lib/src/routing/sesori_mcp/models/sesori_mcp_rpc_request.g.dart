// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesori_mcp_rpc_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SesoriMcpRpcRequest _$SesoriMcpRpcRequestFromJson(Map json) => _SesoriMcpRpcRequest(
  id: json['id'],
  method: json['method'] as String,
  params: (json['params'] as Map?)?.map((k, e) => MapEntry(k as String, e)),
);

_SesoriMcpInitializeParams _$SesoriMcpInitializeParamsFromJson(Map json) => _SesoriMcpInitializeParams(
  protocolVersion: json['protocolVersion'] as String?,
);

_SesoriMcpToolCall _$SesoriMcpToolCallFromJson(Map json) => _SesoriMcpToolCall(
  name: json['name'] as String,
  arguments: (json['arguments'] as Map?)?.map(
    (k, e) => MapEntry(k as String, e),
  ),
);
