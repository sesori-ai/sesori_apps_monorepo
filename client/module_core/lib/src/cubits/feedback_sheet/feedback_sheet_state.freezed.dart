// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feedback_sheet_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FeedbackSheetState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackSheetState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FeedbackSheetState()';
}


}

/// @nodoc
class $FeedbackSheetStateCopyWith<$Res>  {
$FeedbackSheetStateCopyWith(FeedbackSheetState _, $Res Function(FeedbackSheetState) __);
}



/// @nodoc


class FeedbackSheetRating implements FeedbackSheetState {
  const FeedbackSheetRating();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackSheetRating);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FeedbackSheetState.rating()';
}


}




/// @nodoc


class FeedbackSheetCelebrating implements FeedbackSheetState {
  const FeedbackSheetCelebrating();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackSheetCelebrating);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FeedbackSheetState.celebrating()';
}


}




/// @nodoc


class FeedbackSheetReviewConfirmation implements FeedbackSheetState {
  const FeedbackSheetReviewConfirmation();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackSheetReviewConfirmation);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FeedbackSheetState.reviewConfirmation()';
}


}




/// @nodoc


class FeedbackSheetReviewAccepted implements FeedbackSheetState {
  const FeedbackSheetReviewAccepted();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackSheetReviewAccepted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FeedbackSheetState.reviewAccepted()';
}


}




/// @nodoc


class FeedbackSheetReviewPromptPending implements FeedbackSheetState {
  const FeedbackSheetReviewPromptPending();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackSheetReviewPromptPending);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FeedbackSheetState.reviewPromptPending()';
}


}




/// @nodoc


class FeedbackSheetPrivateFeedback implements FeedbackSheetState {
  const FeedbackSheetPrivateFeedback({required  Set<FeedbackIssue> issues, required this.submission}): _issues = issues;
  

 final  Set<FeedbackIssue> _issues;
 Set<FeedbackIssue> get issues {
  if (_issues is EqualUnmodifiableSetView) return _issues;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_issues);
}

 final  FeedbackSubmission submission;

/// Create a copy of FeedbackSheetState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedbackSheetPrivateFeedbackCopyWith<FeedbackSheetPrivateFeedback> get copyWith => _$FeedbackSheetPrivateFeedbackCopyWithImpl<FeedbackSheetPrivateFeedback>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackSheetPrivateFeedback&&const DeepCollectionEquality().equals(other.issues, _issues)&&(identical(other.submission, submission) || other.submission == submission));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_issues),submission);
}

@override
String toString() {
    return 'FeedbackSheetState.privateFeedback(issues: $issues, submission: $submission)';
}


}

/// @nodoc
abstract mixin class $FeedbackSheetPrivateFeedbackCopyWith<$Res> implements $FeedbackSheetStateCopyWith<$Res> {
  factory $FeedbackSheetPrivateFeedbackCopyWith(FeedbackSheetPrivateFeedback value, $Res Function(FeedbackSheetPrivateFeedback) _then) = _$FeedbackSheetPrivateFeedbackCopyWithImpl;
@useResult
$Res call({
 Set<FeedbackIssue> issues, FeedbackSubmission submission
});




}
/// @nodoc
class _$FeedbackSheetPrivateFeedbackCopyWithImpl<$Res>
    implements $FeedbackSheetPrivateFeedbackCopyWith<$Res> {
  _$FeedbackSheetPrivateFeedbackCopyWithImpl(this._self, this._then);

  final FeedbackSheetPrivateFeedback _self;
  final $Res Function(FeedbackSheetPrivateFeedback) _then;

/// Create a copy of FeedbackSheetState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? issues = null,Object? submission = null,}) {
  return _then(FeedbackSheetPrivateFeedback(
issues: null == issues ? _self._issues : issues // ignore: cast_nullable_to_non_nullable
as Set<FeedbackIssue>,submission: null == submission ? _self.submission : submission // ignore: cast_nullable_to_non_nullable
as FeedbackSubmission,
  ));
}


}

// dart format on
