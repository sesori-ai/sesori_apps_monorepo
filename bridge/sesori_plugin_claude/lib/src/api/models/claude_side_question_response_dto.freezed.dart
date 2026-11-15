// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_side_question_response_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudeSideQuestionResponseDto {

 String? get response; bool get synthetic;@JsonKey(name: "refusal_fallback") ClaudeSideQuestionRefusalFallbackDto? get refusalFallback;



@override
bool operator ==(Object other) {
  final _this = this as ClaudeSideQuestionResponseDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeSideQuestionResponseDto&&(identical(other.response, _this.response) || other.response == _this.response)&&(identical(other.synthetic, _this.synthetic) || other.synthetic == _this.synthetic)&&(identical(other.refusalFallback, _this.refusalFallback) || other.refusalFallback == _this.refusalFallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClaudeSideQuestionResponseDto;
  return Object.hash(runtimeType,_this.response,_this.synthetic,_this.refusalFallback);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeSideQuestionResponseDto implements ClaudeSideQuestionResponseDto {
  const _ClaudeSideQuestionResponseDto({required this.response, required this.synthetic, @JsonKey(name: "refusal_fallback") required this.refusalFallback});
  factory _ClaudeSideQuestionResponseDto.fromJson(Map<String, dynamic> json) => _$ClaudeSideQuestionResponseDtoFromJson(json);

@override final  String? response;
@override final  bool synthetic;
@override@JsonKey(name: "refusal_fallback") final  ClaudeSideQuestionRefusalFallbackDto? refusalFallback;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeSideQuestionResponseDto&&(identical(other.response, response) || other.response == response)&&(identical(other.synthetic, synthetic) || other.synthetic == synthetic)&&(identical(other.refusalFallback, refusalFallback) || other.refusalFallback == refusalFallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,response,synthetic,refusalFallback);
}



}





/// @nodoc
mixin _$ClaudeSideQuestionRefusalFallbackDto {

 String? get content;



@override
bool operator ==(Object other) {
  final _this = this as ClaudeSideQuestionRefusalFallbackDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeSideQuestionRefusalFallbackDto&&(identical(other.content, _this.content) || other.content == _this.content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClaudeSideQuestionRefusalFallbackDto;
  return Object.hash(runtimeType,_this.content);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeSideQuestionRefusalFallbackDto implements ClaudeSideQuestionRefusalFallbackDto {
  const _ClaudeSideQuestionRefusalFallbackDto({required this.content});
  factory _ClaudeSideQuestionRefusalFallbackDto.fromJson(Map<String, dynamic> json) => _$ClaudeSideQuestionRefusalFallbackDtoFromJson(json);

@override final  String? content;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeSideQuestionRefusalFallbackDto&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,content);
}



}




// dart format on
