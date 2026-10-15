// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_mcp_status_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexMcpStatusPageDto {

 List<CodexMcpServerStatusDto> get data; String? get nextCursor;



@override
bool operator ==(Object other) {
  final _this = this as CodexMcpStatusPageDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpStatusPageDto&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.nextCursor, _this.nextCursor) || other.nextCursor == _this.nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexMcpStatusPageDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.nextCursor);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexMcpStatusPageDto implements CodexMcpStatusPageDto {
  const _CodexMcpStatusPageDto({required  List<CodexMcpServerStatusDto> data, required this.nextCursor}): _data = data;
  factory _CodexMcpStatusPageDto.fromJson(Map<String, dynamic> json) => _$CodexMcpStatusPageDtoFromJson(json);

 final  List<CodexMcpServerStatusDto> _data;
@override List<CodexMcpServerStatusDto> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  String? nextCursor;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexMcpStatusPageDto&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),nextCursor);
}



}





/// @nodoc
mixin _$CodexMcpServerStatusDto {

 String get name; Map<String, CodexMcpToolDto> get tools;@JsonKey(defaultValue: CodexMcpAuthStatus.unknown, unknownEnumValue: CodexMcpAuthStatus.unknown) CodexMcpAuthStatus get authStatus;@JsonKey(unknownEnumValue: CodexMcpRuntimeStatus.unknown) CodexMcpRuntimeStatus? get runtimeStatus; String? get toolsError; String? get httpOrigin; CodexMcpServerInfoDto? get serverInfo;



@override
bool operator ==(Object other) {
  final _this = this as CodexMcpServerStatusDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpServerStatusDto&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.tools, _this.tools)&&(identical(other.authStatus, _this.authStatus) || other.authStatus == _this.authStatus)&&(identical(other.runtimeStatus, _this.runtimeStatus) || other.runtimeStatus == _this.runtimeStatus)&&(identical(other.toolsError, _this.toolsError) || other.toolsError == _this.toolsError)&&(identical(other.httpOrigin, _this.httpOrigin) || other.httpOrigin == _this.httpOrigin)&&(identical(other.serverInfo, _this.serverInfo) || other.serverInfo == _this.serverInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexMcpServerStatusDto;
  return Object.hash(runtimeType,_this.name,const DeepCollectionEquality().hash(_this.tools),_this.authStatus,_this.runtimeStatus,_this.toolsError,_this.httpOrigin,_this.serverInfo);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexMcpServerStatusDto implements CodexMcpServerStatusDto {
  const _CodexMcpServerStatusDto({required this.name, required  Map<String, CodexMcpToolDto> tools, @JsonKey(defaultValue: CodexMcpAuthStatus.unknown, unknownEnumValue: CodexMcpAuthStatus.unknown) required this.authStatus, @JsonKey(unknownEnumValue: CodexMcpRuntimeStatus.unknown) required this.runtimeStatus, required this.toolsError, required this.httpOrigin, required this.serverInfo}): _tools = tools;
  factory _CodexMcpServerStatusDto.fromJson(Map<String, dynamic> json) => _$CodexMcpServerStatusDtoFromJson(json);

@override final  String name;
 final  Map<String, CodexMcpToolDto> _tools;
@override Map<String, CodexMcpToolDto> get tools {
  if (_tools is EqualUnmodifiableMapView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_tools);
}

@override@JsonKey(defaultValue: CodexMcpAuthStatus.unknown, unknownEnumValue: CodexMcpAuthStatus.unknown) final  CodexMcpAuthStatus authStatus;
@override@JsonKey(unknownEnumValue: CodexMcpRuntimeStatus.unknown) final  CodexMcpRuntimeStatus? runtimeStatus;
@override final  String? toolsError;
@override final  String? httpOrigin;
@override final  CodexMcpServerInfoDto? serverInfo;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexMcpServerStatusDto&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.tools, _tools)&&(identical(other.authStatus, authStatus) || other.authStatus == authStatus)&&(identical(other.runtimeStatus, runtimeStatus) || other.runtimeStatus == runtimeStatus)&&(identical(other.toolsError, toolsError) || other.toolsError == toolsError)&&(identical(other.httpOrigin, httpOrigin) || other.httpOrigin == httpOrigin)&&(identical(other.serverInfo, serverInfo) || other.serverInfo == serverInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,const DeepCollectionEquality().hash(_tools),authStatus,runtimeStatus,toolsError,httpOrigin,serverInfo);
}



}





/// @nodoc
mixin _$CodexMcpToolDto {

 String get name; String? get description;



@override
bool operator ==(Object other) {
  final _this = this as CodexMcpToolDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpToolDto&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexMcpToolDto;
  return Object.hash(runtimeType,_this.name,_this.description);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexMcpToolDto implements CodexMcpToolDto {
  const _CodexMcpToolDto({required this.name, required this.description});
  factory _CodexMcpToolDto.fromJson(Map<String, dynamic> json) => _$CodexMcpToolDtoFromJson(json);

@override final  String name;
@override final  String? description;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexMcpToolDto&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,description);
}



}





/// @nodoc
mixin _$CodexMcpServerInfoDto {

 String? get title; String? get description;



@override
bool operator ==(Object other) {
  final _this = this as CodexMcpServerInfoDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpServerInfoDto&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.description, _this.description) || other.description == _this.description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexMcpServerInfoDto;
  return Object.hash(runtimeType,_this.title,_this.description);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexMcpServerInfoDto implements CodexMcpServerInfoDto {
  const _CodexMcpServerInfoDto({required this.title, required this.description});
  factory _CodexMcpServerInfoDto.fromJson(Map<String, dynamic> json) => _$CodexMcpServerInfoDtoFromJson(json);

@override final  String? title;
@override final  String? description;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexMcpServerInfoDto&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,title,description);
}



}




// dart format on
