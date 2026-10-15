// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'open_code_mcp_authentication_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpenCodeMcpConfigurationDto {

 Map<String, OpenCodeMcpServerConfigurationDto> get mcp;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _OpenCodeMcpConfigurationDto implements OpenCodeMcpConfigurationDto {
  const _OpenCodeMcpConfigurationDto({ Map<String, OpenCodeMcpServerConfigurationDto> mcp = const {}}): _mcp = mcp;
  factory _OpenCodeMcpConfigurationDto.fromJson(Map<String, dynamic> json) => _$OpenCodeMcpConfigurationDtoFromJson(json);

 final  Map<String, OpenCodeMcpServerConfigurationDto> _mcp;
@override@JsonKey() Map<String, OpenCodeMcpServerConfigurationDto> get mcp {
  if (_mcp is EqualUnmodifiableMapView) return _mcp;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_mcp);
}









}





/// @nodoc
mixin _$OpenCodeMcpServerConfigurationDto {

@JsonKey(name: "type", unknownEnumValue: OpenCodeMcpTransport.unknown) OpenCodeMcpTransport? get transport; String? get url;@JsonKey(name: "oauth", fromJson: _oauthEnabled) bool get oauthEnabled;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _OpenCodeMcpServerConfigurationDto implements OpenCodeMcpServerConfigurationDto {
  const _OpenCodeMcpServerConfigurationDto({@JsonKey(name: "type", unknownEnumValue: OpenCodeMcpTransport.unknown) required this.transport, required this.url, @JsonKey(name: "oauth", fromJson: _oauthEnabled) required this.oauthEnabled});
  factory _OpenCodeMcpServerConfigurationDto.fromJson(Map<String, dynamic> json) => _$OpenCodeMcpServerConfigurationDtoFromJson(json);

@override@JsonKey(name: "type", unknownEnumValue: OpenCodeMcpTransport.unknown) final  OpenCodeMcpTransport? transport;
@override final  String? url;
@override@JsonKey(name: "oauth", fromJson: _oauthEnabled) final  bool oauthEnabled;








}





/// @nodoc
mixin _$OpenCodeMcpAuthenticationResponseDto {

 String get authorizationUrl; String get oauthState;







}





/// @nodoc
@JsonSerializable(createToJson: false)

class _OpenCodeMcpAuthenticationResponseDto implements OpenCodeMcpAuthenticationResponseDto {
  const _OpenCodeMcpAuthenticationResponseDto({required this.authorizationUrl, required this.oauthState});
  factory _OpenCodeMcpAuthenticationResponseDto.fromJson(Map<String, dynamic> json) => _$OpenCodeMcpAuthenticationResponseDtoFromJson(json);

@override final  String authorizationUrl;
@override final  String oauthState;








}




// dart format on
