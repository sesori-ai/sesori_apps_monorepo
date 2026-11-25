// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'v2_client_mcp_frame.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$V2ClientMcpFrame {

/// Absent on notifications.
 Object? get id;@JsonKey(fromJson: _textOrNull) String? get method; V2ClientMcpParams? get params;



@override
bool operator ==(Object other) {
  final _this = this as V2ClientMcpFrame;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2ClientMcpFrame&&const DeepCollectionEquality().equals(other.id, _this.id)&&(identical(other.method, _this.method) || other.method == _this.method)&&(identical(other.params, _this.params) || other.params == _this.params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2ClientMcpFrame;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.id),_this.method,_this.params);
}

@override
String toString() {
  final _this = this as V2ClientMcpFrame;
  return 'V2ClientMcpFrame(id: ${_this.id}, method: ${_this.method}, params: ${_this.params})';
}


}





/// @nodoc
@JsonSerializable(createToJson: false)

class _V2ClientMcpFrame implements V2ClientMcpFrame {
  const _V2ClientMcpFrame({required this.id, @JsonKey(fromJson: _textOrNull) required this.method, required this.params});
  factory _V2ClientMcpFrame.fromJson(Map<String, dynamic> json) => _$V2ClientMcpFrameFromJson(json);

/// Absent on notifications.
@override final  Object? id;
@override@JsonKey(fromJson: _textOrNull) final  String? method;
@override final  V2ClientMcpParams? params;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2ClientMcpFrame&&const DeepCollectionEquality().equals(other.id, id)&&(identical(other.method, method) || other.method == method)&&(identical(other.params, params) || other.params == params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(id),method,params);
}

@override
String toString() {
    return 'V2ClientMcpFrame(id: $id, method: $method, params: $params)';
}


}





/// @nodoc
mixin _$V2ClientMcpParams {

@JsonKey(name: "_meta") V2ClientMcpMeta? get meta;



@override
bool operator ==(Object other) {
  final _this = this as V2ClientMcpParams;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2ClientMcpParams&&(identical(other.meta, _this.meta) || other.meta == _this.meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2ClientMcpParams;
  return Object.hash(runtimeType,_this.meta);
}

@override
String toString() {
  final _this = this as V2ClientMcpParams;
  return 'V2ClientMcpParams(meta: ${_this.meta})';
}


}





/// @nodoc
@JsonSerializable(createToJson: false)

class _V2ClientMcpParams implements V2ClientMcpParams {
  const _V2ClientMcpParams({@JsonKey(name: "_meta") required this.meta});
  factory _V2ClientMcpParams.fromJson(Map<String, dynamic> json) => _$V2ClientMcpParamsFromJson(json);

@override@JsonKey(name: "_meta") final  V2ClientMcpMeta? meta;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2ClientMcpParams&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,meta);
}

@override
String toString() {
    return 'V2ClientMcpParams(meta: $meta)';
}


}





/// @nodoc
mixin _$V2ClientMcpMeta {

/// The OpenCode session whose step made a `tools/call`.
@JsonKey(name: "ai.opencode/sessionID", fromJson: _textOrNull) String? get sessionId;



@override
bool operator ==(Object other) {
  final _this = this as V2ClientMcpMeta;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2ClientMcpMeta&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2ClientMcpMeta;
  return Object.hash(runtimeType,_this.sessionId);
}

@override
String toString() {
  final _this = this as V2ClientMcpMeta;
  return 'V2ClientMcpMeta(sessionId: ${_this.sessionId})';
}


}





/// @nodoc
@JsonSerializable(createToJson: false)

class _V2ClientMcpMeta implements V2ClientMcpMeta {
  const _V2ClientMcpMeta({@JsonKey(name: "ai.opencode/sessionID", fromJson: _textOrNull) required this.sessionId});
  factory _V2ClientMcpMeta.fromJson(Map<String, dynamic> json) => _$V2ClientMcpMetaFromJson(json);

/// The OpenCode session whose step made a `tools/call`.
@override@JsonKey(name: "ai.opencode/sessionID", fromJson: _textOrNull) final  String? sessionId;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2ClientMcpMeta&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId);
}

@override
String toString() {
    return 'V2ClientMcpMeta(sessionId: $sessionId)';
}


}




// dart format on
