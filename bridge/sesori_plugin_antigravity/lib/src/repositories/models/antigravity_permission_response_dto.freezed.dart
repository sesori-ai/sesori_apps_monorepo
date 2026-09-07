// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'antigravity_permission_response_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AntigravityPermissionResponseDto {

 AntigravityPermissionOutcomeDto get outcome;

  /// Serializes this AntigravityPermissionResponseDto to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable(createFactory: false)

class _AntigravityPermissionResponseDto implements AntigravityPermissionResponseDto {
  const _AntigravityPermissionResponseDto({required this.outcome});
  

@override final  AntigravityPermissionOutcomeDto outcome;


@override
Map<String, dynamic> toJson() {
  return _$AntigravityPermissionResponseDtoToJson(this, );
}





}




/// @nodoc
mixin _$AntigravityPermissionOutcomeDto {



  /// Serializes this AntigravityPermissionOutcomeDto to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable(createFactory: false)

class AntigravityPermissionSelectedDto implements AntigravityPermissionOutcomeDto {
  const AntigravityPermissionSelectedDto({required this.optionId,  String? $type}): $type = $type ?? 'selected';
  

 final  String optionId;

@JsonKey(name: 'outcome')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AntigravityPermissionSelectedDtoToJson(this, );
}





}




/// @nodoc
@JsonSerializable(createFactory: false)

class AntigravityPermissionCancelledDto implements AntigravityPermissionOutcomeDto {
  const AntigravityPermissionCancelledDto({ String? $type}): $type = $type ?? 'cancelled';
  



@JsonKey(name: 'outcome')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AntigravityPermissionCancelledDtoToJson(this, );
}





}




// dart format on
