// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pull_request_merge_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PullRequestMergeState {

/// The label change that failed, retried on each poll.
 PullRequestReadinessRetry? get retry;/// The failure the last report showed; a different one reports at once.
 PullRequestReadinessRetry? get reportedRetry;/// The automatic merge attempt, for the next report only.
 PullRequestMergeAttempt? get mergeAttempt;/// Turning auto-merge on removed the label from an eligible PR. Until new
/// activity, readiness waits for the agent's own judgment.
 bool get resetPending;/// The ready label was just withdrawn: the report saying so goes first,
/// and only a later quiet report may add it back.
 bool get restoreAfterReport;
/// Create a copy of PullRequestMergeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestMergeStateCopyWith<PullRequestMergeState> get copyWith => _$PullRequestMergeStateCopyWithImpl<PullRequestMergeState>(this as PullRequestMergeState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PullRequestMergeState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestMergeState&&(identical(other.retry, _this.retry) || other.retry == _this.retry)&&(identical(other.reportedRetry, _this.reportedRetry) || other.reportedRetry == _this.reportedRetry)&&(identical(other.mergeAttempt, _this.mergeAttempt) || other.mergeAttempt == _this.mergeAttempt)&&(identical(other.resetPending, _this.resetPending) || other.resetPending == _this.resetPending)&&(identical(other.restoreAfterReport, _this.restoreAfterReport) || other.restoreAfterReport == _this.restoreAfterReport));
}


@override
int get hashCode {
  final _this = this as PullRequestMergeState;
  return Object.hash(runtimeType,_this.retry,_this.reportedRetry,_this.mergeAttempt,_this.resetPending,_this.restoreAfterReport);
}

@override
String toString() {
  final _this = this as PullRequestMergeState;
  return 'PullRequestMergeState(retry: ${_this.retry}, reportedRetry: ${_this.reportedRetry}, mergeAttempt: ${_this.mergeAttempt}, resetPending: ${_this.resetPending}, restoreAfterReport: ${_this.restoreAfterReport})';
}


}

/// @nodoc
abstract mixin class $PullRequestMergeStateCopyWith<$Res>  {
  factory $PullRequestMergeStateCopyWith(PullRequestMergeState value, $Res Function(PullRequestMergeState) _then) = _$PullRequestMergeStateCopyWithImpl;
@useResult
$Res call({
 PullRequestReadinessRetry? retry, PullRequestReadinessRetry? reportedRetry, PullRequestMergeAttempt? mergeAttempt, bool resetPending, bool restoreAfterReport
});




}
/// @nodoc
class _$PullRequestMergeStateCopyWithImpl<$Res>
    implements $PullRequestMergeStateCopyWith<$Res> {
  _$PullRequestMergeStateCopyWithImpl(this._self, this._then);

  final PullRequestMergeState _self;
  final $Res Function(PullRequestMergeState) _then;

/// Create a copy of PullRequestMergeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? retry = freezed,Object? reportedRetry = freezed,Object? mergeAttempt = freezed,Object? resetPending = null,Object? restoreAfterReport = null,}) {
  return _then(PullRequestMergeState(
retry: freezed == retry ? _self.retry : retry // ignore: cast_nullable_to_non_nullable
as PullRequestReadinessRetry?,reportedRetry: freezed == reportedRetry ? _self.reportedRetry : reportedRetry // ignore: cast_nullable_to_non_nullable
as PullRequestReadinessRetry?,mergeAttempt: freezed == mergeAttempt ? _self.mergeAttempt : mergeAttempt // ignore: cast_nullable_to_non_nullable
as PullRequestMergeAttempt?,resetPending: null == resetPending ? _self.resetPending : resetPending // ignore: cast_nullable_to_non_nullable
as bool,restoreAfterReport: null == restoreAfterReport ? _self.restoreAfterReport : restoreAfterReport // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc


class _PullRequestMergeState implements PullRequestMergeState {
  const _PullRequestMergeState({required this.retry, required this.reportedRetry, required this.mergeAttempt, required this.resetPending, required this.restoreAfterReport});
  

/// The label change that failed, retried on each poll.
@override final  PullRequestReadinessRetry? retry;
/// The failure the last report showed; a different one reports at once.
@override final  PullRequestReadinessRetry? reportedRetry;
/// The automatic merge attempt, for the next report only.
@override final  PullRequestMergeAttempt? mergeAttempt;
/// Turning auto-merge on removed the label from an eligible PR. Until new
/// activity, readiness waits for the agent's own judgment.
@override final  bool resetPending;
/// The ready label was just withdrawn: the report saying so goes first,
/// and only a later quiet report may add it back.
@override final  bool restoreAfterReport;

/// Create a copy of PullRequestMergeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestMergeStateCopyWith<_PullRequestMergeState> get copyWith => __$PullRequestMergeStateCopyWithImpl<_PullRequestMergeState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestMergeState&&(identical(other.retry, retry) || other.retry == retry)&&(identical(other.reportedRetry, reportedRetry) || other.reportedRetry == reportedRetry)&&(identical(other.mergeAttempt, mergeAttempt) || other.mergeAttempt == mergeAttempt)&&(identical(other.resetPending, resetPending) || other.resetPending == resetPending)&&(identical(other.restoreAfterReport, restoreAfterReport) || other.restoreAfterReport == restoreAfterReport));
}


@override
int get hashCode {
    return Object.hash(runtimeType,retry,reportedRetry,mergeAttempt,resetPending,restoreAfterReport);
}

@override
String toString() {
    return 'PullRequestMergeState(retry: $retry, reportedRetry: $reportedRetry, mergeAttempt: $mergeAttempt, resetPending: $resetPending, restoreAfterReport: $restoreAfterReport)';
}


}

/// @nodoc
abstract mixin class _$PullRequestMergeStateCopyWith<$Res> implements $PullRequestMergeStateCopyWith<$Res> {
  factory _$PullRequestMergeStateCopyWith(_PullRequestMergeState value, $Res Function(_PullRequestMergeState) _then) = __$PullRequestMergeStateCopyWithImpl;
@override @useResult
$Res call({
 PullRequestReadinessRetry? retry, PullRequestReadinessRetry? reportedRetry, PullRequestMergeAttempt? mergeAttempt, bool resetPending, bool restoreAfterReport
});




}
/// @nodoc
class __$PullRequestMergeStateCopyWithImpl<$Res>
    implements _$PullRequestMergeStateCopyWith<$Res> {
  __$PullRequestMergeStateCopyWithImpl(this._self, this._then);

  final _PullRequestMergeState _self;
  final $Res Function(_PullRequestMergeState) _then;

/// Create a copy of PullRequestMergeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? retry = freezed,Object? reportedRetry = freezed,Object? mergeAttempt = freezed,Object? resetPending = null,Object? restoreAfterReport = null,}) {
  return _then(_PullRequestMergeState(
retry: freezed == retry ? _self.retry : retry // ignore: cast_nullable_to_non_nullable
as PullRequestReadinessRetry?,reportedRetry: freezed == reportedRetry ? _self.reportedRetry : reportedRetry // ignore: cast_nullable_to_non_nullable
as PullRequestReadinessRetry?,mergeAttempt: freezed == mergeAttempt ? _self.mergeAttempt : mergeAttempt // ignore: cast_nullable_to_non_nullable
as PullRequestMergeAttempt?,resetPending: null == resetPending ? _self.resetPending : resetPending // ignore: cast_nullable_to_non_nullable
as bool,restoreAfterReport: null == restoreAfterReport ? _self.restoreAfterReport : restoreAfterReport // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
