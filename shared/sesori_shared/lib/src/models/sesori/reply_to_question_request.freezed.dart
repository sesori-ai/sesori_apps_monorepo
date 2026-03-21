// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reply_to_question_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReplyToQuestionRequest {

 List<List<String>> get answers;
/// Create a copy of ReplyToQuestionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReplyToQuestionRequestCopyWith<ReplyToQuestionRequest> get copyWith => _$ReplyToQuestionRequestCopyWithImpl<ReplyToQuestionRequest>(this as ReplyToQuestionRequest, _$identity);

  /// Serializes this ReplyToQuestionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplyToQuestionRequest&&const DeepCollectionEquality().equals(other.answers, answers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(answers));

@override
String toString() {
  return 'ReplyToQuestionRequest(answers: $answers)';
}


}

/// @nodoc
abstract mixin class $ReplyToQuestionRequestCopyWith<$Res>  {
  factory $ReplyToQuestionRequestCopyWith(ReplyToQuestionRequest value, $Res Function(ReplyToQuestionRequest) _then) = _$ReplyToQuestionRequestCopyWithImpl;
@useResult
$Res call({
 List<List<String>> answers
});




}
/// @nodoc
class _$ReplyToQuestionRequestCopyWithImpl<$Res>
    implements $ReplyToQuestionRequestCopyWith<$Res> {
  _$ReplyToQuestionRequestCopyWithImpl(this._self, this._then);

  final ReplyToQuestionRequest _self;
  final $Res Function(ReplyToQuestionRequest) _then;

/// Create a copy of ReplyToQuestionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? answers = null,}) {
  return _then(_self.copyWith(
answers: null == answers ? _self.answers : answers // ignore: cast_nullable_to_non_nullable
as List<List<String>>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ReplyToQuestionRequest implements ReplyToQuestionRequest {
  const _ReplyToQuestionRequest({required final  List<List<String>> answers}): _answers = answers;
  factory _ReplyToQuestionRequest.fromJson(Map<String, dynamic> json) => _$ReplyToQuestionRequestFromJson(json);

 final  List<List<String>> _answers;
@override List<List<String>> get answers {
  if (_answers is EqualUnmodifiableListView) return _answers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_answers);
}


/// Create a copy of ReplyToQuestionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReplyToQuestionRequestCopyWith<_ReplyToQuestionRequest> get copyWith => __$ReplyToQuestionRequestCopyWithImpl<_ReplyToQuestionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReplyToQuestionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplyToQuestionRequest&&const DeepCollectionEquality().equals(other._answers, _answers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_answers));

@override
String toString() {
  return 'ReplyToQuestionRequest(answers: $answers)';
}


}

/// @nodoc
abstract mixin class _$ReplyToQuestionRequestCopyWith<$Res> implements $ReplyToQuestionRequestCopyWith<$Res> {
  factory _$ReplyToQuestionRequestCopyWith(_ReplyToQuestionRequest value, $Res Function(_ReplyToQuestionRequest) _then) = __$ReplyToQuestionRequestCopyWithImpl;
@override @useResult
$Res call({
 List<List<String>> answers
});




}
/// @nodoc
class __$ReplyToQuestionRequestCopyWithImpl<$Res>
    implements _$ReplyToQuestionRequestCopyWith<$Res> {
  __$ReplyToQuestionRequestCopyWithImpl(this._self, this._then);

  final _ReplyToQuestionRequest _self;
  final $Res Function(_ReplyToQuestionRequest) _then;

/// Create a copy of ReplyToQuestionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? answers = null,}) {
  return _then(_ReplyToQuestionRequest(
answers: null == answers ? _self._answers : answers // ignore: cast_nullable_to_non_nullable
as List<List<String>>,
  ));
}


}

// dart format on
