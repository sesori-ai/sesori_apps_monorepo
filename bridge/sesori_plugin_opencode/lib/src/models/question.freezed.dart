// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'question.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$QuestionInfo {

 String get question; String get header; List<QuestionOption> get options; bool get multiple; bool get custom;
/// Create a copy of QuestionInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionInfoCopyWith<QuestionInfo> get copyWith => _$QuestionInfoCopyWithImpl<QuestionInfo>(this as QuestionInfo, _$identity);

  /// Serializes this QuestionInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionInfo&&(identical(other.question, question) || other.question == question)&&(identical(other.header, header) || other.header == header)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.multiple, multiple) || other.multiple == multiple)&&(identical(other.custom, custom) || other.custom == custom));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,question,header,const DeepCollectionEquality().hash(options),multiple,custom);

@override
String toString() {
  return 'QuestionInfo(question: $question, header: $header, options: $options, multiple: $multiple, custom: $custom)';
}


}

/// @nodoc
abstract mixin class $QuestionInfoCopyWith<$Res>  {
  factory $QuestionInfoCopyWith(QuestionInfo value, $Res Function(QuestionInfo) _then) = _$QuestionInfoCopyWithImpl;
@useResult
$Res call({
 String question, String header, List<QuestionOption> options, bool multiple, bool custom
});




}
/// @nodoc
class _$QuestionInfoCopyWithImpl<$Res>
    implements $QuestionInfoCopyWith<$Res> {
  _$QuestionInfoCopyWithImpl(this._self, this._then);

  final QuestionInfo _self;
  final $Res Function(QuestionInfo) _then;

/// Create a copy of QuestionInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? question = null,Object? header = null,Object? options = null,Object? multiple = null,Object? custom = null,}) {
  return _then(_self.copyWith(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<QuestionOption>,multiple: null == multiple ? _self.multiple : multiple // ignore: cast_nullable_to_non_nullable
as bool,custom: null == custom ? _self.custom : custom // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _QuestionInfo implements QuestionInfo {
  const _QuestionInfo({required this.question, required this.header, final  List<QuestionOption> options = const [], this.multiple = false, this.custom = true}): _options = options;
  factory _QuestionInfo.fromJson(Map<String, dynamic> json) => _$QuestionInfoFromJson(json);

@override final  String question;
@override final  String header;
 final  List<QuestionOption> _options;
@override@JsonKey() List<QuestionOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override@JsonKey() final  bool multiple;
@override@JsonKey() final  bool custom;

/// Create a copy of QuestionInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuestionInfoCopyWith<_QuestionInfo> get copyWith => __$QuestionInfoCopyWithImpl<_QuestionInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuestionInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuestionInfo&&(identical(other.question, question) || other.question == question)&&(identical(other.header, header) || other.header == header)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.multiple, multiple) || other.multiple == multiple)&&(identical(other.custom, custom) || other.custom == custom));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,question,header,const DeepCollectionEquality().hash(_options),multiple,custom);

@override
String toString() {
  return 'QuestionInfo(question: $question, header: $header, options: $options, multiple: $multiple, custom: $custom)';
}


}

/// @nodoc
abstract mixin class _$QuestionInfoCopyWith<$Res> implements $QuestionInfoCopyWith<$Res> {
  factory _$QuestionInfoCopyWith(_QuestionInfo value, $Res Function(_QuestionInfo) _then) = __$QuestionInfoCopyWithImpl;
@override @useResult
$Res call({
 String question, String header, List<QuestionOption> options, bool multiple, bool custom
});




}
/// @nodoc
class __$QuestionInfoCopyWithImpl<$Res>
    implements _$QuestionInfoCopyWith<$Res> {
  __$QuestionInfoCopyWithImpl(this._self, this._then);

  final _QuestionInfo _self;
  final $Res Function(_QuestionInfo) _then;

/// Create a copy of QuestionInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? question = null,Object? header = null,Object? options = null,Object? multiple = null,Object? custom = null,}) {
  return _then(_QuestionInfo(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<QuestionOption>,multiple: null == multiple ? _self.multiple : multiple // ignore: cast_nullable_to_non_nullable
as bool,custom: null == custom ? _self.custom : custom // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$QuestionOption {

 String get label; String get description;
/// Create a copy of QuestionOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestionOptionCopyWith<QuestionOption> get copyWith => _$QuestionOptionCopyWithImpl<QuestionOption>(this as QuestionOption, _$identity);

  /// Serializes this QuestionOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionOption&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,description);

@override
String toString() {
  return 'QuestionOption(label: $label, description: $description)';
}


}

/// @nodoc
abstract mixin class $QuestionOptionCopyWith<$Res>  {
  factory $QuestionOptionCopyWith(QuestionOption value, $Res Function(QuestionOption) _then) = _$QuestionOptionCopyWithImpl;
@useResult
$Res call({
 String label, String description
});




}
/// @nodoc
class _$QuestionOptionCopyWithImpl<$Res>
    implements $QuestionOptionCopyWith<$Res> {
  _$QuestionOptionCopyWithImpl(this._self, this._then);

  final QuestionOption _self;
  final $Res Function(QuestionOption) _then;

/// Create a copy of QuestionOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? description = null,}) {
  return _then(_self.copyWith(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _QuestionOption implements QuestionOption {
  const _QuestionOption({required this.label, required this.description});
  factory _QuestionOption.fromJson(Map<String, dynamic> json) => _$QuestionOptionFromJson(json);

@override final  String label;
@override final  String description;

/// Create a copy of QuestionOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuestionOptionCopyWith<_QuestionOption> get copyWith => __$QuestionOptionCopyWithImpl<_QuestionOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuestionOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuestionOption&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,description);

@override
String toString() {
  return 'QuestionOption(label: $label, description: $description)';
}


}

/// @nodoc
abstract mixin class _$QuestionOptionCopyWith<$Res> implements $QuestionOptionCopyWith<$Res> {
  factory _$QuestionOptionCopyWith(_QuestionOption value, $Res Function(_QuestionOption) _then) = __$QuestionOptionCopyWithImpl;
@override @useResult
$Res call({
 String label, String description
});




}
/// @nodoc
class __$QuestionOptionCopyWithImpl<$Res>
    implements _$QuestionOptionCopyWith<$Res> {
  __$QuestionOptionCopyWithImpl(this._self, this._then);

  final _QuestionOption _self;
  final $Res Function(_QuestionOption) _then;

/// Create a copy of QuestionOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? description = null,}) {
  return _then(_QuestionOption(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
