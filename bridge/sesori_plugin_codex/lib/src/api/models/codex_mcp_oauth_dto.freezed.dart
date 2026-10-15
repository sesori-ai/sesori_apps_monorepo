// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_mcp_oauth_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexMcpOAuthLoginDto {

 String get authorizationUrl;



@override
bool operator ==(Object other) {
  final _this = this as CodexMcpOAuthLoginDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpOAuthLoginDto&&(identical(other.authorizationUrl, _this.authorizationUrl) || other.authorizationUrl == _this.authorizationUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexMcpOAuthLoginDto;
  return Object.hash(runtimeType,_this.authorizationUrl);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexMcpOAuthLoginDto implements CodexMcpOAuthLoginDto {
  const _CodexMcpOAuthLoginDto({required this.authorizationUrl});
  factory _CodexMcpOAuthLoginDto.fromJson(Map<String, dynamic> json) => _$CodexMcpOAuthLoginDtoFromJson(json);

@override final  String authorizationUrl;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexMcpOAuthLoginDto&&(identical(other.authorizationUrl, authorizationUrl) || other.authorizationUrl == authorizationUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,authorizationUrl);
}



}





/// @nodoc
mixin _$CodexMcpOAuthCompletionDto {

 String get name; bool get success; String? get error; String? get threadId;



@override
bool operator ==(Object other) {
  final _this = this as CodexMcpOAuthCompletionDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpOAuthCompletionDto&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.success, _this.success) || other.success == _this.success)&&(identical(other.error, _this.error) || other.error == _this.error)&&(identical(other.threadId, _this.threadId) || other.threadId == _this.threadId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexMcpOAuthCompletionDto;
  return Object.hash(runtimeType,_this.name,_this.success,_this.error,_this.threadId);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexMcpOAuthCompletionDto implements CodexMcpOAuthCompletionDto {
  const _CodexMcpOAuthCompletionDto({required this.name, required this.success, required this.error, required this.threadId});
  factory _CodexMcpOAuthCompletionDto.fromJson(Map<String, dynamic> json) => _$CodexMcpOAuthCompletionDtoFromJson(json);

@override final  String name;
@override final  bool success;
@override final  String? error;
@override final  String? threadId;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexMcpOAuthCompletionDto&&(identical(other.name, name) || other.name == name)&&(identical(other.success, success) || other.success == success)&&(identical(other.error, error) || other.error == error)&&(identical(other.threadId, threadId) || other.threadId == threadId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,success,error,threadId);
}



}




// dart format on
