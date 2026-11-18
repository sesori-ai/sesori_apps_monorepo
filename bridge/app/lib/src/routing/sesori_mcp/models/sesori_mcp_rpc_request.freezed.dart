// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sesori_mcp_rpc_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SesoriMcpRpcRequest {

/// A string or a number, echoed back verbatim.
 Object? get id; String get method; Map<String, dynamic>? get params;





@override
String toString() {
  final _this = this as SesoriMcpRpcRequest;
  return 'SesoriMcpRpcRequest(id: ${_this.id}, method: ${_this.method}, params: ${_this.params})';
}


}





/// @nodoc
@JsonSerializable(createToJson: false)

class _SesoriMcpRpcRequest implements SesoriMcpRpcRequest {
  const _SesoriMcpRpcRequest({required this.id, required this.method, required  Map<String, dynamic>? params}): _params = params;
  factory _SesoriMcpRpcRequest.fromJson(Map<String, dynamic> json) => _$SesoriMcpRpcRequestFromJson(json);

/// A string or a number, echoed back verbatim.
@override final  Object? id;
@override final  String method;
 final  Map<String, dynamic>? _params;
@override Map<String, dynamic>? get params {
  final value = _params;
  if (value == null) return null;
  if (_params is EqualUnmodifiableMapView) return _params;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}







@override
String toString() {
    return 'SesoriMcpRpcRequest(id: $id, method: $method, params: $params)';
}


}





/// @nodoc
mixin _$SesoriMcpInitializeParams {

 String? get protocolVersion;





@override
String toString() {
  final _this = this as SesoriMcpInitializeParams;
  return 'SesoriMcpInitializeParams(protocolVersion: ${_this.protocolVersion})';
}


}





/// @nodoc
@JsonSerializable(createToJson: false)

class _SesoriMcpInitializeParams implements SesoriMcpInitializeParams {
  const _SesoriMcpInitializeParams({required this.protocolVersion});
  factory _SesoriMcpInitializeParams.fromJson(Map<String, dynamic> json) => _$SesoriMcpInitializeParamsFromJson(json);

@override final  String? protocolVersion;






@override
String toString() {
    return 'SesoriMcpInitializeParams(protocolVersion: $protocolVersion)';
}


}





/// @nodoc
mixin _$SesoriMcpToolCall {

 String get name; Map<String, dynamic>? get arguments;





@override
String toString() {
  final _this = this as SesoriMcpToolCall;
  return 'SesoriMcpToolCall(name: ${_this.name}, arguments: ${_this.arguments})';
}


}





/// @nodoc
@JsonSerializable(createToJson: false)

class _SesoriMcpToolCall implements SesoriMcpToolCall {
  const _SesoriMcpToolCall({required this.name, required  Map<String, dynamic>? arguments}): _arguments = arguments;
  factory _SesoriMcpToolCall.fromJson(Map<String, dynamic> json) => _$SesoriMcpToolCallFromJson(json);

@override final  String name;
 final  Map<String, dynamic>? _arguments;
@override Map<String, dynamic>? get arguments {
  final value = _arguments;
  if (value == null) return null;
  if (_arguments is EqualUnmodifiableMapView) return _arguments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}







@override
String toString() {
    return 'SesoriMcpToolCall(name: $name, arguments: $arguments)';
}


}




// dart format on
