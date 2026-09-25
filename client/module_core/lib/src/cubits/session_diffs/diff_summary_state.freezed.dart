// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diff_summary_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiffSummaryState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DiffSummaryState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DiffSummaryState()';
}


}

/// @nodoc
class $DiffSummaryStateCopyWith<$Res>  {
$DiffSummaryStateCopyWith(DiffSummaryState _, $Res Function(DiffSummaryState) __);
}



/// @nodoc


class DiffSummaryUnknown implements DiffSummaryState {
  const DiffSummaryUnknown();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DiffSummaryUnknown);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DiffSummaryState.unknown()';
}


}




/// @nodoc


class DiffSummaryCounts implements DiffSummaryState {
  const DiffSummaryCounts({required this.additions, required this.deletions});
  

 final  int additions;
 final  int deletions;

/// Create a copy of DiffSummaryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiffSummaryCountsCopyWith<DiffSummaryCounts> get copyWith => _$DiffSummaryCountsCopyWithImpl<DiffSummaryCounts>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DiffSummaryCounts&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions));
}


@override
int get hashCode {
    return Object.hash(runtimeType,additions,deletions);
}

@override
String toString() {
    return 'DiffSummaryState.counts(additions: $additions, deletions: $deletions)';
}


}

/// @nodoc
abstract mixin class $DiffSummaryCountsCopyWith<$Res> implements $DiffSummaryStateCopyWith<$Res> {
  factory $DiffSummaryCountsCopyWith(DiffSummaryCounts value, $Res Function(DiffSummaryCounts) _then) = _$DiffSummaryCountsCopyWithImpl;
@useResult
$Res call({
 int additions, int deletions
});




}
/// @nodoc
class _$DiffSummaryCountsCopyWithImpl<$Res>
    implements $DiffSummaryCountsCopyWith<$Res> {
  _$DiffSummaryCountsCopyWithImpl(this._self, this._then);

  final DiffSummaryCounts _self;
  final $Res Function(DiffSummaryCounts) _then;

/// Create a copy of DiffSummaryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? additions = null,Object? deletions = null,}) {
  return _then(DiffSummaryCounts(
additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
