// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'v2_tool_presentation_fields.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$V2ToolPresentationFields {

@JsonKey(fromJson: _textOrNull) String? get command;@JsonKey(fromJson: _textOrNull) String? get title;



@override
bool operator ==(Object other) {
  final _this = this as V2ToolPresentationFields;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2ToolPresentationFields&&(identical(other.command, _this.command) || other.command == _this.command)&&(identical(other.title, _this.title) || other.title == _this.title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2ToolPresentationFields;
  return Object.hash(runtimeType,_this.command,_this.title);
}

@override
String toString() {
  final _this = this as V2ToolPresentationFields;
  return 'V2ToolPresentationFields(command: ${_this.command}, title: ${_this.title})';
}


}





/// @nodoc
@JsonSerializable(createToJson: false)

class _V2ToolPresentationFields implements V2ToolPresentationFields {
  const _V2ToolPresentationFields({@JsonKey(fromJson: _textOrNull) required this.command, @JsonKey(fromJson: _textOrNull) required this.title});
  factory _V2ToolPresentationFields.fromJson(Map<String, dynamic> json) => _$V2ToolPresentationFieldsFromJson(json);

@override@JsonKey(fromJson: _textOrNull) final  String? command;
@override@JsonKey(fromJson: _textOrNull) final  String? title;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2ToolPresentationFields&&(identical(other.command, command) || other.command == command)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,command,title);
}

@override
String toString() {
    return 'V2ToolPresentationFields(command: $command, title: $title)';
}


}




// dart format on
