// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_mcp_status_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudeMcpStatusDto {

 List<ClaudeMcpServerStatusDto> get mcpServers;



@override
bool operator ==(Object other) {
  final _this = this as ClaudeMcpStatusDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeMcpStatusDto&&const DeepCollectionEquality().equals(other.mcpServers, _this.mcpServers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClaudeMcpStatusDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.mcpServers));
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeMcpStatusDto implements ClaudeMcpStatusDto {
  const _ClaudeMcpStatusDto({required  List<ClaudeMcpServerStatusDto> mcpServers}): _mcpServers = mcpServers;
  factory _ClaudeMcpStatusDto.fromJson(Map<String, dynamic> json) => _$ClaudeMcpStatusDtoFromJson(json);

 final  List<ClaudeMcpServerStatusDto> _mcpServers;
@override List<ClaudeMcpServerStatusDto> get mcpServers {
  if (_mcpServers is EqualUnmodifiableListView) return _mcpServers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mcpServers);
}





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeMcpStatusDto&&const DeepCollectionEquality().equals(other.mcpServers, _mcpServers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_mcpServers));
}



}





/// @nodoc
mixin _$ClaudeMcpServerStatusDto {

 String get name;@JsonKey(unknownEnumValue: ClaudeMcpStatus.unknown) ClaudeMcpStatus get status;@JsonKey(unknownEnumValue: ClaudeMcpConfigurationScope.unknown) ClaudeMcpConfigurationScope? get scope; ClaudeMcpServerInfoDto? get serverInfo; ClaudeMcpConfigDto? get config; List<ClaudeMcpToolDto>? get tools;



@override
bool operator ==(Object other) {
  final _this = this as ClaudeMcpServerStatusDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeMcpServerStatusDto&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.scope, _this.scope) || other.scope == _this.scope)&&(identical(other.serverInfo, _this.serverInfo) || other.serverInfo == _this.serverInfo)&&(identical(other.config, _this.config) || other.config == _this.config)&&const DeepCollectionEquality().equals(other.tools, _this.tools));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClaudeMcpServerStatusDto;
  return Object.hash(runtimeType,_this.name,_this.status,_this.scope,_this.serverInfo,_this.config,const DeepCollectionEquality().hash(_this.tools));
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeMcpServerStatusDto implements ClaudeMcpServerStatusDto {
  const _ClaudeMcpServerStatusDto({required this.name, @JsonKey(unknownEnumValue: ClaudeMcpStatus.unknown) required this.status, @JsonKey(unknownEnumValue: ClaudeMcpConfigurationScope.unknown) required this.scope, required this.serverInfo, required this.config, required  List<ClaudeMcpToolDto>? tools}): _tools = tools;
  factory _ClaudeMcpServerStatusDto.fromJson(Map<String, dynamic> json) => _$ClaudeMcpServerStatusDtoFromJson(json);

@override final  String name;
@override@JsonKey(unknownEnumValue: ClaudeMcpStatus.unknown) final  ClaudeMcpStatus status;
@override@JsonKey(unknownEnumValue: ClaudeMcpConfigurationScope.unknown) final  ClaudeMcpConfigurationScope? scope;
@override final  ClaudeMcpServerInfoDto? serverInfo;
@override final  ClaudeMcpConfigDto? config;
 final  List<ClaudeMcpToolDto>? _tools;
@override List<ClaudeMcpToolDto>? get tools {
  final value = _tools;
  if (value == null) return null;
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeMcpServerStatusDto&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.serverInfo, serverInfo) || other.serverInfo == serverInfo)&&(identical(other.config, config) || other.config == config)&&const DeepCollectionEquality().equals(other.tools, _tools));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,status,scope,serverInfo,config,const DeepCollectionEquality().hash(_tools));
}



}





/// @nodoc
mixin _$ClaudeMcpServerInfoDto {

 String? get title; String? get description;



@override
bool operator ==(Object other) {
  final _this = this as ClaudeMcpServerInfoDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeMcpServerInfoDto&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.description, _this.description) || other.description == _this.description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClaudeMcpServerInfoDto;
  return Object.hash(runtimeType,_this.title,_this.description);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeMcpServerInfoDto implements ClaudeMcpServerInfoDto {
  const _ClaudeMcpServerInfoDto({required this.title, required this.description});
  factory _ClaudeMcpServerInfoDto.fromJson(Map<String, dynamic> json) => _$ClaudeMcpServerInfoDtoFromJson(json);

@override final  String? title;
@override final  String? description;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeMcpServerInfoDto&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,title,description);
}



}





/// @nodoc
mixin _$ClaudeMcpConfigDto {

@JsonKey(unknownEnumValue: ClaudeMcpTransportType.unknown) ClaudeMcpTransportType? get type; String? get url;



@override
bool operator ==(Object other) {
  final _this = this as ClaudeMcpConfigDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeMcpConfigDto&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.url, _this.url) || other.url == _this.url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClaudeMcpConfigDto;
  return Object.hash(runtimeType,_this.type,_this.url);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeMcpConfigDto implements ClaudeMcpConfigDto {
  const _ClaudeMcpConfigDto({@JsonKey(unknownEnumValue: ClaudeMcpTransportType.unknown) required this.type, required this.url});
  factory _ClaudeMcpConfigDto.fromJson(Map<String, dynamic> json) => _$ClaudeMcpConfigDtoFromJson(json);

@override@JsonKey(unknownEnumValue: ClaudeMcpTransportType.unknown) final  ClaudeMcpTransportType? type;
@override final  String? url;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeMcpConfigDto&&(identical(other.type, type) || other.type == type)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,url);
}



}





/// @nodoc
mixin _$ClaudeMcpToolDto {

 String get name; String? get description;



@override
bool operator ==(Object other) {
  final _this = this as ClaudeMcpToolDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeMcpToolDto&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClaudeMcpToolDto;
  return Object.hash(runtimeType,_this.name,_this.description);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeMcpToolDto implements ClaudeMcpToolDto {
  const _ClaudeMcpToolDto({required this.name, required this.description});
  factory _ClaudeMcpToolDto.fromJson(Map<String, dynamic> json) => _$ClaudeMcpToolDtoFromJson(json);

@override final  String name;
@override final  String? description;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeMcpToolDto&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,description);
}



}




// dart format on
