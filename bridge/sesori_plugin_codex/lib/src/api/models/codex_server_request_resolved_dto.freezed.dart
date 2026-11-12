// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_server_request_resolved_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexServerRequestResolvedDto {

 String get threadId; Object get requestId;



@override
bool operator ==(Object other) {
  final _this = this as CodexServerRequestResolvedDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexServerRequestResolvedDto&&(identical(other.threadId, _this.threadId) || other.threadId == _this.threadId)&&const DeepCollectionEquality().equals(other.requestId, _this.requestId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexServerRequestResolvedDto;
  return Object.hash(runtimeType,_this.threadId,const DeepCollectionEquality().hash(_this.requestId));
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexServerRequestResolvedDto implements CodexServerRequestResolvedDto {
  const _CodexServerRequestResolvedDto({required this.threadId, required this.requestId});
  factory _CodexServerRequestResolvedDto.fromJson(Map<String, dynamic> json) => _$CodexServerRequestResolvedDtoFromJson(json);

@override final  String threadId;
@override final  Object requestId;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexServerRequestResolvedDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&const DeepCollectionEquality().equals(other.requestId, requestId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,threadId,const DeepCollectionEquality().hash(requestId));
}



}




// dart format on
