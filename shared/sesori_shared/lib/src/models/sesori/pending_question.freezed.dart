// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pending_question.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PendingQuestion {

 String get id; String get sessionID; List<QuestionInfo> get questions;
/// Create a copy of PendingQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingQuestionCopyWith<PendingQuestion> get copyWith => _$PendingQuestionCopyWithImpl<PendingQuestion>(this as PendingQuestion, _$identity);

  /// Serializes this PendingQuestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&const DeepCollectionEquality().equals(other.questions, questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,const DeepCollectionEquality().hash(questions));

@override
String toString() {
  return 'PendingQuestion(id: $id, sessionID: $sessionID, questions: $questions)';
}


}

/// @nodoc
abstract mixin class $PendingQuestionCopyWith<$Res>  {
  factory $PendingQuestionCopyWith(PendingQuestion value, $Res Function(PendingQuestion) _then) = _$PendingQuestionCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, List<QuestionInfo> questions
});




}
/// @nodoc
class _$PendingQuestionCopyWithImpl<$Res>
    implements $PendingQuestionCopyWith<$Res> {
  _$PendingQuestionCopyWithImpl(this._self, this._then);

  final PendingQuestion _self;
  final $Res Function(PendingQuestion) _then;

/// Create a copy of PendingQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionID = null,Object? questions = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<QuestionInfo>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PendingQuestion implements PendingQuestion {
  const _PendingQuestion({required this.id, required this.sessionID, required final  List<QuestionInfo> questions}): _questions = questions;
  factory _PendingQuestion.fromJson(Map<String, dynamic> json) => _$PendingQuestionFromJson(json);

@override final  String id;
@override final  String sessionID;
 final  List<QuestionInfo> _questions;
@override List<QuestionInfo> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}


/// Create a copy of PendingQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PendingQuestionCopyWith<_PendingQuestion> get copyWith => __$PendingQuestionCopyWithImpl<_PendingQuestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PendingQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingQuestion&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&const DeepCollectionEquality().equals(other._questions, _questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,const DeepCollectionEquality().hash(_questions));

@override
String toString() {
  return 'PendingQuestion(id: $id, sessionID: $sessionID, questions: $questions)';
}


}

/// @nodoc
abstract mixin class _$PendingQuestionCopyWith<$Res> implements $PendingQuestionCopyWith<$Res> {
  factory _$PendingQuestionCopyWith(_PendingQuestion value, $Res Function(_PendingQuestion) _then) = __$PendingQuestionCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionID, List<QuestionInfo> questions
});




}
/// @nodoc
class __$PendingQuestionCopyWithImpl<$Res>
    implements _$PendingQuestionCopyWith<$Res> {
  __$PendingQuestionCopyWithImpl(this._self, this._then);

  final _PendingQuestion _self;
  final $Res Function(_PendingQuestion) _then;

/// Create a copy of PendingQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? questions = null,}) {
  return _then(_PendingQuestion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<QuestionInfo>,
  ));
}


}

// dart format on
