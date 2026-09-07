// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'antigravity_initialize_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AntigravityInitializeDto {

 int? get protocolVersion; AntigravityAgentInfoDto? get agentInfo; AntigravityAgentCapabilitiesDto? get agentCapabilities; List<AntigravityAuthMethodDto>? get authMethods;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravityInitializeDto implements AntigravityInitializeDto {
  const _AntigravityInitializeDto({required this.protocolVersion, required this.agentInfo, required this.agentCapabilities, required  List<AntigravityAuthMethodDto>? authMethods}): _authMethods = authMethods;
  factory _AntigravityInitializeDto.fromJson(Map<String, dynamic> json) => _$AntigravityInitializeDtoFromJson(json);

@override final  int? protocolVersion;
@override final  AntigravityAgentInfoDto? agentInfo;
@override final  AntigravityAgentCapabilitiesDto? agentCapabilities;
 final  List<AntigravityAuthMethodDto>? _authMethods;
@override List<AntigravityAuthMethodDto>? get authMethods {
  final value = _authMethods;
  if (value == null) return null;
  if (_authMethods is EqualUnmodifiableListView) return _authMethods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}









}





/// @nodoc
mixin _$AntigravityAgentInfoDto {

 String? get name; String? get title; String? get version;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravityAgentInfoDto implements AntigravityAgentInfoDto {
  const _AntigravityAgentInfoDto({required this.name, required this.title, required this.version});
  factory _AntigravityAgentInfoDto.fromJson(Map<String, dynamic> json) => _$AntigravityAgentInfoDtoFromJson(json);

@override final  String? name;
@override final  String? title;
@override final  String? version;








}





/// @nodoc
mixin _$AntigravityAgentCapabilitiesDto {

 bool? get loadSession; AntigravitySessionCapabilitiesDto? get sessionCapabilities; AntigravityAuthCapabilitiesDto? get auth;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravityAgentCapabilitiesDto implements AntigravityAgentCapabilitiesDto {
  const _AntigravityAgentCapabilitiesDto({required this.loadSession, required this.sessionCapabilities, required this.auth});
  factory _AntigravityAgentCapabilitiesDto.fromJson(Map<String, dynamic> json) => _$AntigravityAgentCapabilitiesDtoFromJson(json);

@override final  bool? loadSession;
@override final  AntigravitySessionCapabilitiesDto? sessionCapabilities;
@override final  AntigravityAuthCapabilitiesDto? auth;








}





/// @nodoc
mixin _$AntigravitySessionCapabilitiesDto {

@AntigravityCapabilityPresenceConverter() bool get list;@AntigravityCapabilityPresenceConverter() bool get resume;@AntigravityCapabilityPresenceConverter() bool get close;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravitySessionCapabilitiesDto implements AntigravitySessionCapabilitiesDto {
  const _AntigravitySessionCapabilitiesDto({@AntigravityCapabilityPresenceConverter() required this.list, @AntigravityCapabilityPresenceConverter() required this.resume, @AntigravityCapabilityPresenceConverter() required this.close});
  factory _AntigravitySessionCapabilitiesDto.fromJson(Map<String, dynamic> json) => _$AntigravitySessionCapabilitiesDtoFromJson(json);

@override@AntigravityCapabilityPresenceConverter() final  bool list;
@override@AntigravityCapabilityPresenceConverter() final  bool resume;
@override@AntigravityCapabilityPresenceConverter() final  bool close;








}





/// @nodoc
mixin _$AntigravityAuthCapabilitiesDto {

@AntigravityCapabilityPresenceConverter() bool get logout;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravityAuthCapabilitiesDto implements AntigravityAuthCapabilitiesDto {
  const _AntigravityAuthCapabilitiesDto({@AntigravityCapabilityPresenceConverter() required this.logout});
  factory _AntigravityAuthCapabilitiesDto.fromJson(Map<String, dynamic> json) => _$AntigravityAuthCapabilitiesDtoFromJson(json);

@override@AntigravityCapabilityPresenceConverter() final  bool logout;








}





/// @nodoc
mixin _$AntigravityAuthMethodDto {

 String? get id;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _AntigravityAuthMethodDto implements AntigravityAuthMethodDto {
  const _AntigravityAuthMethodDto({required this.id});
  factory _AntigravityAuthMethodDto.fromJson(Map<String, dynamic> json) => _$AntigravityAuthMethodDtoFromJson(json);

@override final  String? id;








}




// dart format on
