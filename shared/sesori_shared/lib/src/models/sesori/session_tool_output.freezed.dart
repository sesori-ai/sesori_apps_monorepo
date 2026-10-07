// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_tool_output.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionToolOutputRequest {

 String get sessionId; String get messageId; String get partId;

  /// Serializes this SessionToolOutputRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionToolOutputRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionToolOutputRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId)&&(identical(other.partId, _this.partId) || other.partId == _this.partId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionToolOutputRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.messageId,_this.partId);
}

@override
String toString() {
  final _this = this as SessionToolOutputRequest;
  return 'SessionToolOutputRequest(sessionId: ${_this.sessionId}, messageId: ${_this.messageId}, partId: ${_this.partId})';
}


}





/// @nodoc
@JsonSerializable()

class _SessionToolOutputRequest implements SessionToolOutputRequest {
  const _SessionToolOutputRequest({required this.sessionId, required this.messageId, required this.partId});
  factory _SessionToolOutputRequest.fromJson(Map<String, dynamic> json) => _$SessionToolOutputRequestFromJson(json);

@override final  String sessionId;
@override final  String messageId;
@override final  String partId;


@override
Map<String, dynamic> toJson() {
  return _$SessionToolOutputRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionToolOutputRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.partId, partId) || other.partId == partId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,messageId,partId);
}

@override
String toString() {
    return 'SessionToolOutputRequest(sessionId: $sessionId, messageId: $messageId, partId: $partId)';
}


}





/// @nodoc
mixin _$SessionToolOutputResponse {

 String? get output; String? get error;

  /// Serializes this SessionToolOutputResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionToolOutputResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionToolOutputResponse&&(identical(other.output, _this.output) || other.output == _this.output)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionToolOutputResponse;
  return Object.hash(runtimeType,_this.output,_this.error);
}

@override
String toString() {
  final _this = this as SessionToolOutputResponse;
  return 'SessionToolOutputResponse(output: ${_this.output}, error: ${_this.error})';
}


}





/// @nodoc
@JsonSerializable()

class _SessionToolOutputResponse implements SessionToolOutputResponse {
  const _SessionToolOutputResponse({required this.output, required this.error});
  factory _SessionToolOutputResponse.fromJson(Map<String, dynamic> json) => _$SessionToolOutputResponseFromJson(json);

@override final  String? output;
@override final  String? error;


@override
Map<String, dynamic> toJson() {
  return _$SessionToolOutputResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionToolOutputResponse&&(identical(other.output, output) || other.output == output)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,output,error);
}

@override
String toString() {
    return 'SessionToolOutputResponse(output: $output, error: $error)';
}


}




// dart format on
