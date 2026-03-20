// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_pending_question.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginQuestionOption {

 String get label; String get description;
/// Create a copy of PluginQuestionOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginQuestionOptionCopyWith<PluginQuestionOption> get copyWith => _$PluginQuestionOptionCopyWithImpl<PluginQuestionOption>(this as PluginQuestionOption, _$identity);

  /// Serializes this PluginQuestionOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginQuestionOption&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,description);

@override
String toString() {
  return 'PluginQuestionOption(label: $label, description: $description)';
}


}

/// @nodoc
abstract mixin class $PluginQuestionOptionCopyWith<$Res>  {
  factory $PluginQuestionOptionCopyWith(PluginQuestionOption value, $Res Function(PluginQuestionOption) _then) = _$PluginQuestionOptionCopyWithImpl;
@useResult
$Res call({
 String label, String description
});




}
/// @nodoc
class _$PluginQuestionOptionCopyWithImpl<$Res>
    implements $PluginQuestionOptionCopyWith<$Res> {
  _$PluginQuestionOptionCopyWithImpl(this._self, this._then);

  final PluginQuestionOption _self;
  final $Res Function(PluginQuestionOption) _then;

/// Create a copy of PluginQuestionOption
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
@JsonSerializable(createFactory: false)

class _PluginQuestionOption implements PluginQuestionOption {
  const _PluginQuestionOption({required this.label, required this.description});
  

@override final  String label;
@override final  String description;

/// Create a copy of PluginQuestionOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginQuestionOptionCopyWith<_PluginQuestionOption> get copyWith => __$PluginQuestionOptionCopyWithImpl<_PluginQuestionOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginQuestionOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginQuestionOption&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,description);

@override
String toString() {
  return 'PluginQuestionOption(label: $label, description: $description)';
}


}

/// @nodoc
abstract mixin class _$PluginQuestionOptionCopyWith<$Res> implements $PluginQuestionOptionCopyWith<$Res> {
  factory _$PluginQuestionOptionCopyWith(_PluginQuestionOption value, $Res Function(_PluginQuestionOption) _then) = __$PluginQuestionOptionCopyWithImpl;
@override @useResult
$Res call({
 String label, String description
});




}
/// @nodoc
class __$PluginQuestionOptionCopyWithImpl<$Res>
    implements _$PluginQuestionOptionCopyWith<$Res> {
  __$PluginQuestionOptionCopyWithImpl(this._self, this._then);

  final _PluginQuestionOption _self;
  final $Res Function(_PluginQuestionOption) _then;

/// Create a copy of PluginQuestionOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? description = null,}) {
  return _then(_PluginQuestionOption(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PluginQuestionInfo {

 String get question; String get header; List<PluginQuestionOption> get options; bool get multiple; bool get custom;
/// Create a copy of PluginQuestionInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginQuestionInfoCopyWith<PluginQuestionInfo> get copyWith => _$PluginQuestionInfoCopyWithImpl<PluginQuestionInfo>(this as PluginQuestionInfo, _$identity);

  /// Serializes this PluginQuestionInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginQuestionInfo&&(identical(other.question, question) || other.question == question)&&(identical(other.header, header) || other.header == header)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.multiple, multiple) || other.multiple == multiple)&&(identical(other.custom, custom) || other.custom == custom));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,question,header,const DeepCollectionEquality().hash(options),multiple,custom);

@override
String toString() {
  return 'PluginQuestionInfo(question: $question, header: $header, options: $options, multiple: $multiple, custom: $custom)';
}


}

/// @nodoc
abstract mixin class $PluginQuestionInfoCopyWith<$Res>  {
  factory $PluginQuestionInfoCopyWith(PluginQuestionInfo value, $Res Function(PluginQuestionInfo) _then) = _$PluginQuestionInfoCopyWithImpl;
@useResult
$Res call({
 String question, String header, List<PluginQuestionOption> options, bool multiple, bool custom
});




}
/// @nodoc
class _$PluginQuestionInfoCopyWithImpl<$Res>
    implements $PluginQuestionInfoCopyWith<$Res> {
  _$PluginQuestionInfoCopyWithImpl(this._self, this._then);

  final PluginQuestionInfo _self;
  final $Res Function(PluginQuestionInfo) _then;

/// Create a copy of PluginQuestionInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? question = null,Object? header = null,Object? options = null,Object? multiple = null,Object? custom = null,}) {
  return _then(_self.copyWith(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<PluginQuestionOption>,multiple: null == multiple ? _self.multiple : multiple // ignore: cast_nullable_to_non_nullable
as bool,custom: null == custom ? _self.custom : custom // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginQuestionInfo implements PluginQuestionInfo {
  const _PluginQuestionInfo({required this.question, required this.header, required final  List<PluginQuestionOption> options, required this.multiple, required this.custom}): _options = options;
  

@override final  String question;
@override final  String header;
 final  List<PluginQuestionOption> _options;
@override List<PluginQuestionOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override final  bool multiple;
@override final  bool custom;

/// Create a copy of PluginQuestionInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginQuestionInfoCopyWith<_PluginQuestionInfo> get copyWith => __$PluginQuestionInfoCopyWithImpl<_PluginQuestionInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginQuestionInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginQuestionInfo&&(identical(other.question, question) || other.question == question)&&(identical(other.header, header) || other.header == header)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.multiple, multiple) || other.multiple == multiple)&&(identical(other.custom, custom) || other.custom == custom));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,question,header,const DeepCollectionEquality().hash(_options),multiple,custom);

@override
String toString() {
  return 'PluginQuestionInfo(question: $question, header: $header, options: $options, multiple: $multiple, custom: $custom)';
}


}

/// @nodoc
abstract mixin class _$PluginQuestionInfoCopyWith<$Res> implements $PluginQuestionInfoCopyWith<$Res> {
  factory _$PluginQuestionInfoCopyWith(_PluginQuestionInfo value, $Res Function(_PluginQuestionInfo) _then) = __$PluginQuestionInfoCopyWithImpl;
@override @useResult
$Res call({
 String question, String header, List<PluginQuestionOption> options, bool multiple, bool custom
});




}
/// @nodoc
class __$PluginQuestionInfoCopyWithImpl<$Res>
    implements _$PluginQuestionInfoCopyWith<$Res> {
  __$PluginQuestionInfoCopyWithImpl(this._self, this._then);

  final _PluginQuestionInfo _self;
  final $Res Function(_PluginQuestionInfo) _then;

/// Create a copy of PluginQuestionInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? question = null,Object? header = null,Object? options = null,Object? multiple = null,Object? custom = null,}) {
  return _then(_PluginQuestionInfo(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<PluginQuestionOption>,multiple: null == multiple ? _self.multiple : multiple // ignore: cast_nullable_to_non_nullable
as bool,custom: null == custom ? _self.custom : custom // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$PluginPendingQuestion {

 String get id; String get sessionID; List<PluginQuestionInfo> get questions;
/// Create a copy of PluginPendingQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPendingQuestionCopyWith<PluginPendingQuestion> get copyWith => _$PluginPendingQuestionCopyWithImpl<PluginPendingQuestion>(this as PluginPendingQuestion, _$identity);

  /// Serializes this PluginPendingQuestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPendingQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&const DeepCollectionEquality().equals(other.questions, questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,const DeepCollectionEquality().hash(questions));

@override
String toString() {
  return 'PluginPendingQuestion(id: $id, sessionID: $sessionID, questions: $questions)';
}


}

/// @nodoc
abstract mixin class $PluginPendingQuestionCopyWith<$Res>  {
  factory $PluginPendingQuestionCopyWith(PluginPendingQuestion value, $Res Function(PluginPendingQuestion) _then) = _$PluginPendingQuestionCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, List<PluginQuestionInfo> questions
});




}
/// @nodoc
class _$PluginPendingQuestionCopyWithImpl<$Res>
    implements $PluginPendingQuestionCopyWith<$Res> {
  _$PluginPendingQuestionCopyWithImpl(this._self, this._then);

  final PluginPendingQuestion _self;
  final $Res Function(PluginPendingQuestion) _then;

/// Create a copy of PluginPendingQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? questions = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<PluginQuestionInfo>,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginPendingQuestion implements PluginPendingQuestion {
  const _PluginPendingQuestion({required this.id, required this.sessionID, required final  List<PluginQuestionInfo> questions}): _questions = questions;
  

@override final  String id;
@override final  String sessionID;
 final  List<PluginQuestionInfo> _questions;
@override List<PluginQuestionInfo> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}


/// Create a copy of PluginPendingQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginPendingQuestionCopyWith<_PluginPendingQuestion> get copyWith => __$PluginPendingQuestionCopyWithImpl<_PluginPendingQuestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginPendingQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginPendingQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&const DeepCollectionEquality().equals(other._questions, _questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,const DeepCollectionEquality().hash(_questions));

@override
String toString() {
  return 'PluginPendingQuestion(id: $id, sessionID: $sessionID, questions: $questions)';
}


}

/// @nodoc
abstract mixin class _$PluginPendingQuestionCopyWith<$Res> implements $PluginPendingQuestionCopyWith<$Res> {
  factory _$PluginPendingQuestionCopyWith(_PluginPendingQuestion value, $Res Function(_PluginPendingQuestion) _then) = __$PluginPendingQuestionCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, List<PluginQuestionInfo> questions
});




}
/// @nodoc
class __$PluginPendingQuestionCopyWithImpl<$Res>
    implements _$PluginPendingQuestionCopyWith<$Res> {
  __$PluginPendingQuestionCopyWithImpl(this._self, this._then);

  final _PluginPendingQuestion _self;
  final $Res Function(_PluginPendingQuestion) _then;

/// Create a copy of PluginPendingQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? questions = null,}) {
  return _then(_PluginPendingQuestion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<PluginQuestionInfo>,
  ));
}


}

// dart format on
