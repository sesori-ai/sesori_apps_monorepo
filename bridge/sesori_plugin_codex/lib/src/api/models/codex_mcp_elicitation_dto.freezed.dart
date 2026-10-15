// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_mcp_elicitation_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexMcpElicitationDto {

 String get threadId; String get serverName;@JsonKey(unknownEnumValue: CodexMcpElicitationMode.unknown) CodexMcpElicitationMode get mode; String? get message; Map<String, Object?>? get requestedSchema; String? get url; String? get elicitationId;



@override
bool operator ==(Object other) {
  final _this = this as CodexMcpElicitationDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpElicitationDto&&(identical(other.threadId, _this.threadId) || other.threadId == _this.threadId)&&(identical(other.serverName, _this.serverName) || other.serverName == _this.serverName)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.message, _this.message) || other.message == _this.message)&&const DeepCollectionEquality().equals(other.requestedSchema, _this.requestedSchema)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.elicitationId, _this.elicitationId) || other.elicitationId == _this.elicitationId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexMcpElicitationDto;
  return Object.hash(runtimeType,_this.threadId,_this.serverName,_this.mode,_this.message,const DeepCollectionEquality().hash(_this.requestedSchema),_this.url,_this.elicitationId);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexMcpElicitationDto implements CodexMcpElicitationDto {
  const _CodexMcpElicitationDto({required this.threadId, required this.serverName, @JsonKey(unknownEnumValue: CodexMcpElicitationMode.unknown) required this.mode, required this.message, required  Map<String, Object?>? requestedSchema, required this.url, required this.elicitationId}): _requestedSchema = requestedSchema;
  factory _CodexMcpElicitationDto.fromJson(Map<String, dynamic> json) => _$CodexMcpElicitationDtoFromJson(json);

@override final  String threadId;
@override final  String serverName;
@override@JsonKey(unknownEnumValue: CodexMcpElicitationMode.unknown) final  CodexMcpElicitationMode mode;
@override final  String? message;
 final  Map<String, Object?>? _requestedSchema;
@override Map<String, Object?>? get requestedSchema {
  final value = _requestedSchema;
  if (value == null) return null;
  if (_requestedSchema is EqualUnmodifiableMapView) return _requestedSchema;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  String? url;
@override final  String? elicitationId;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexMcpElicitationDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.serverName, serverName) || other.serverName == serverName)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.requestedSchema, _requestedSchema)&&(identical(other.url, url) || other.url == url)&&(identical(other.elicitationId, elicitationId) || other.elicitationId == elicitationId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,threadId,serverName,mode,message,const DeepCollectionEquality().hash(_requestedSchema),url,elicitationId);
}



}




// dart format on
