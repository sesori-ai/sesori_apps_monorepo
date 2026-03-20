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

 String get type; String? get text;
/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPromptPartCopyWith<PluginPromptPart> get copyWith => _$PluginPromptPartCopyWithImpl<PluginPromptPart>(this as PluginPromptPart, _$identity);

  /// Serializes this PluginPromptPart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPromptPart&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,text);

@override
String toString() {
  return 'PluginPromptPart(type: $type, text: $text)';
}


}

/// @nodoc
abstract mixin class $PluginPromptPartCopyWith<$Res>  {
  factory $PluginPromptPartCopyWith(PluginPromptPart value, $Res Function(PluginPromptPart) _then) = _$PluginPromptPartCopyWithImpl;
@useResult
$Res call({
 String type, String? text
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
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? text = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginPromptPart implements PluginPromptPart {
  const _PluginPromptPart({required this.type, this.text});
  

@override final  String type;
@override final  String? text;

/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginPromptPartCopyWith<_PluginPromptPart> get copyWith => __$PluginPromptPartCopyWithImpl<_PluginPromptPart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginPromptPartToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginPromptPart&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,text);

@override
String toString() {
  return 'PluginPromptPart(type: $type, text: $text)';
}


}

/// @nodoc
abstract mixin class _$PluginPromptPartCopyWith<$Res> implements $PluginPromptPartCopyWith<$Res> {
  factory _$PluginPromptPartCopyWith(_PluginPromptPart value, $Res Function(_PluginPromptPart) _then) = __$PluginPromptPartCopyWithImpl;
@override @useResult
$Res call({
 String type, String? text
});




}
/// @nodoc
class __$PluginPromptPartCopyWithImpl<$Res>
    implements _$PluginPromptPartCopyWith<$Res> {
  __$PluginPromptPartCopyWithImpl(this._self, this._then);

  final _PluginPromptPart _self;
  final $Res Function(_PluginPromptPart) _then;

/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? text = freezed,}) {
  return _then(_PluginPromptPart(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
