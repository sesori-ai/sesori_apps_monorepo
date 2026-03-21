// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_prompt_part.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginPromptPart {

 String get text;
/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPromptPartCopyWith<PluginPromptPart> get copyWith => _$PluginPromptPartCopyWithImpl<PluginPromptPart>(this as PluginPromptPart, _$identity);

  /// Serializes this PluginPromptPart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPromptPart&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'PluginPromptPart(text: $text)';
}


}

/// @nodoc
abstract mixin class $PluginPromptPartCopyWith<$Res>  {
  factory $PluginPromptPartCopyWith(PluginPromptPart value, $Res Function(PluginPromptPart) _then) = _$PluginPromptPartCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$PluginPromptPartCopyWithImpl<$Res>
    implements $PluginPromptPartCopyWith<$Res> {
  _$PluginPromptPartCopyWithImpl(this._self, this._then);

  final PluginPromptPart _self;
  final $Res Function(PluginPromptPart) _then;

/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class PluginPromptPartText implements PluginPromptPart {
  const PluginPromptPartText({required this.text});
  

@override final  String text;

/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPromptPartTextCopyWith<PluginPromptPartText> get copyWith => _$PluginPromptPartTextCopyWithImpl<PluginPromptPartText>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginPromptPartTextToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPromptPartText&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'PluginPromptPart.text(text: $text)';
}


}

/// @nodoc
abstract mixin class $PluginPromptPartTextCopyWith<$Res> implements $PluginPromptPartCopyWith<$Res> {
  factory $PluginPromptPartTextCopyWith(PluginPromptPartText value, $Res Function(PluginPromptPartText) _then) = _$PluginPromptPartTextCopyWithImpl;
@override @useResult
$Res call({
 String text
});




}
/// @nodoc
class _$PluginPromptPartTextCopyWithImpl<$Res>
    implements $PluginPromptPartTextCopyWith<$Res> {
  _$PluginPromptPartTextCopyWithImpl(this._self, this._then);

  final PluginPromptPartText _self;
  final $Res Function(PluginPromptPartText) _then;

/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(PluginPromptPartText(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
