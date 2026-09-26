// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feedback_prompt_presentation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FeedbackPromptPresentation {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackPromptPresentation);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FeedbackPromptPresentation()';
}


}

/// @nodoc
class $FeedbackPromptPresentationCopyWith<$Res>  {
$FeedbackPromptPresentationCopyWith(FeedbackPromptPresentation _, $Res Function(FeedbackPromptPresentation) __);
}



/// @nodoc


class FeedbackPromptIdle implements FeedbackPromptPresentation {
  const FeedbackPromptIdle();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackPromptIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FeedbackPromptPresentation.idle()';
}


}




/// @nodoc


class FeedbackPromptShow implements FeedbackPromptPresentation {
  const FeedbackPromptShow({required this.sequence});
  

 final  int sequence;

/// Create a copy of FeedbackPromptPresentation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedbackPromptShowCopyWith<FeedbackPromptShow> get copyWith => _$FeedbackPromptShowCopyWithImpl<FeedbackPromptShow>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackPromptShow&&(identical(other.sequence, sequence) || other.sequence == sequence));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sequence);
}

@override
String toString() {
    return 'FeedbackPromptPresentation.show(sequence: $sequence)';
}


}

/// @nodoc
abstract mixin class $FeedbackPromptShowCopyWith<$Res> implements $FeedbackPromptPresentationCopyWith<$Res> {
  factory $FeedbackPromptShowCopyWith(FeedbackPromptShow value, $Res Function(FeedbackPromptShow) _then) = _$FeedbackPromptShowCopyWithImpl;
@useResult
$Res call({
 int sequence
});




}
/// @nodoc
class _$FeedbackPromptShowCopyWithImpl<$Res>
    implements $FeedbackPromptShowCopyWith<$Res> {
  _$FeedbackPromptShowCopyWithImpl(this._self, this._then);

  final FeedbackPromptShow _self;
  final $Res Function(FeedbackPromptShow) _then;

/// Create a copy of FeedbackPromptPresentation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sequence = null,}) {
  return _then(FeedbackPromptShow(
sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
