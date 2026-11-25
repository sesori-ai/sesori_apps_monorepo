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
 String? get reportedError;/// The automatic merge attempt's result, for the next report only.
 String? get autoMergeNotice;/// Turning auto-merge on removed the label from an eligible PR. Until new
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestMergeState&&(identical(other.retry, _this.retry) || other.retry == _this.retry)&&(identical(other.reportedError, _this.reportedError) || other.reportedError == _this.reportedError)&&(identical(other.autoMergeNotice, _this.autoMergeNotice) || other.autoMergeNotice == _this.autoMergeNotice)&&(identical(other.resetPending, _this.resetPending) || other.resetPending == _this.resetPending)&&(identical(other.restoreAfterReport, _this.restoreAfterReport) || other.restoreAfterReport == _this.restoreAfterReport));
}


@override
int get hashCode {
  final _this = this as PullRequestMergeState;
  return Object.hash(runtimeType,_this.retry,_this.reportedError,_this.autoMergeNotice,_this.resetPending,_this.restoreAfterReport);
}

@override
String toString() {
  final _this = this as PullRequestMergeState;
  return 'PullRequestMergeState(retry: ${_this.retry}, reportedError: ${_this.reportedError}, autoMergeNotice: ${_this.autoMergeNotice}, resetPending: ${_this.resetPending}, restoreAfterReport: ${_this.restoreAfterReport})';
}


}

/// @nodoc
abstract mixin class $PullRequestMergeStateCopyWith<$Res>  {
  factory $PullRequestMergeStateCopyWith(PullRequestMergeState value, $Res Function(PullRequestMergeState) _then) = _$PullRequestMergeStateCopyWithImpl;
@useResult
$Res call({
 PullRequestReadinessRetry? retry, String? reportedError, String? autoMergeNotice, bool resetPending, bool restoreAfterReport
});


$PullRequestReadinessRetryCopyWith<$Res>? get retry;

}
/// @nodoc
class _$PullRequestMergeStateCopyWithImpl<$Res>
    implements $PullRequestMergeStateCopyWith<$Res> {
  _$PullRequestMergeStateCopyWithImpl(this._self, this._then);

  final PullRequestMergeState _self;
  final $Res Function(PullRequestMergeState) _then;

/// Create a copy of PullRequestMergeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? retry = freezed,Object? reportedError = freezed,Object? autoMergeNotice = freezed,Object? resetPending = null,Object? restoreAfterReport = null,}) {
  return _then(PullRequestMergeState(
retry: freezed == retry ? _self.retry : retry // ignore: cast_nullable_to_non_nullable
as PullRequestReadinessRetry?,reportedError: freezed == reportedError ? _self.reportedError : reportedError // ignore: cast_nullable_to_non_nullable
as String?,autoMergeNotice: freezed == autoMergeNotice ? _self.autoMergeNotice : autoMergeNotice // ignore: cast_nullable_to_non_nullable
as String?,resetPending: null == resetPending ? _self.resetPending : resetPending // ignore: cast_nullable_to_non_nullable
as bool,restoreAfterReport: null == restoreAfterReport ? _self.restoreAfterReport : restoreAfterReport // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of PullRequestMergeState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestReadinessRetryCopyWith<$Res>? get retry {
    if (_self.retry == null) {
    return null;
  }

  return $PullRequestReadinessRetryCopyWith<$Res>(_self.retry!, (value) {
    return _then(_self.copyWith(retry: value));
  });
}
}



/// @nodoc


class _PullRequestMergeState implements PullRequestMergeState {
  const _PullRequestMergeState({required this.retry, required this.reportedError, required this.autoMergeNotice, required this.resetPending, required this.restoreAfterReport});
  

/// The label change that failed, retried on each poll.
@override final  PullRequestReadinessRetry? retry;
/// The failure the last report showed; a different one reports at once.
@override final  String? reportedError;
/// The automatic merge attempt's result, for the next report only.
@override final  String? autoMergeNotice;
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestMergeState&&(identical(other.retry, retry) || other.retry == retry)&&(identical(other.reportedError, reportedError) || other.reportedError == reportedError)&&(identical(other.autoMergeNotice, autoMergeNotice) || other.autoMergeNotice == autoMergeNotice)&&(identical(other.resetPending, resetPending) || other.resetPending == resetPending)&&(identical(other.restoreAfterReport, restoreAfterReport) || other.restoreAfterReport == restoreAfterReport));
}


@override
int get hashCode {
    return Object.hash(runtimeType,retry,reportedError,autoMergeNotice,resetPending,restoreAfterReport);
}

@override
String toString() {
    return 'PullRequestMergeState(retry: $retry, reportedError: $reportedError, autoMergeNotice: $autoMergeNotice, resetPending: $resetPending, restoreAfterReport: $restoreAfterReport)';
}


}

/// @nodoc
abstract mixin class _$PullRequestMergeStateCopyWith<$Res> implements $PullRequestMergeStateCopyWith<$Res> {
  factory _$PullRequestMergeStateCopyWith(_PullRequestMergeState value, $Res Function(_PullRequestMergeState) _then) = __$PullRequestMergeStateCopyWithImpl;
@override @useResult
$Res call({
 PullRequestReadinessRetry? retry, String? reportedError, String? autoMergeNotice, bool resetPending, bool restoreAfterReport
});


@override $PullRequestReadinessRetryCopyWith<$Res>? get retry;

}
/// @nodoc
class __$PullRequestMergeStateCopyWithImpl<$Res>
    implements _$PullRequestMergeStateCopyWith<$Res> {
  __$PullRequestMergeStateCopyWithImpl(this._self, this._then);

  final _PullRequestMergeState _self;
  final $Res Function(_PullRequestMergeState) _then;

/// Create a copy of PullRequestMergeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? retry = freezed,Object? reportedError = freezed,Object? autoMergeNotice = freezed,Object? resetPending = null,Object? restoreAfterReport = null,}) {
  return _then(_PullRequestMergeState(
retry: freezed == retry ? _self.retry : retry // ignore: cast_nullable_to_non_nullable
as PullRequestReadinessRetry?,reportedError: freezed == reportedError ? _self.reportedError : reportedError // ignore: cast_nullable_to_non_nullable
as String?,autoMergeNotice: freezed == autoMergeNotice ? _self.autoMergeNotice : autoMergeNotice // ignore: cast_nullable_to_non_nullable
as String?,resetPending: null == resetPending ? _self.resetPending : resetPending // ignore: cast_nullable_to_non_nullable
as bool,restoreAfterReport: null == restoreAfterReport ? _self.restoreAfterReport : restoreAfterReport // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of PullRequestMergeState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestReadinessRetryCopyWith<$Res>? get retry {
    if (_self.retry == null) {
    return null;
  }

  return $PullRequestReadinessRetryCopyWith<$Res>(_self.retry!, (value) {
    return _then(_self.copyWith(retry: value));
  });
}
}

/// @nodoc
mixin _$PullRequestReadinessRetry {

 bool get ready; PullRequestSnapshot get baseline; String get error;
/// Create a copy of PullRequestReadinessRetry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestReadinessRetryCopyWith<PullRequestReadinessRetry> get copyWith => _$PullRequestReadinessRetryCopyWithImpl<PullRequestReadinessRetry>(this as PullRequestReadinessRetry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PullRequestReadinessRetry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestReadinessRetry&&(identical(other.ready, _this.ready) || other.ready == _this.ready)&&(identical(other.baseline, _this.baseline) || other.baseline == _this.baseline)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as PullRequestReadinessRetry;
  return Object.hash(runtimeType,_this.ready,_this.baseline,_this.error);
}

@override
String toString() {
  final _this = this as PullRequestReadinessRetry;
  return 'PullRequestReadinessRetry(ready: ${_this.ready}, baseline: ${_this.baseline}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $PullRequestReadinessRetryCopyWith<$Res>  {
  factory $PullRequestReadinessRetryCopyWith(PullRequestReadinessRetry value, $Res Function(PullRequestReadinessRetry) _then) = _$PullRequestReadinessRetryCopyWithImpl;
@useResult
$Res call({
 bool ready, PullRequestSnapshot baseline, String error
});


$PullRequestSnapshotCopyWith<$Res> get baseline;

}
/// @nodoc
class _$PullRequestReadinessRetryCopyWithImpl<$Res>
    implements $PullRequestReadinessRetryCopyWith<$Res> {
  _$PullRequestReadinessRetryCopyWithImpl(this._self, this._then);

  final PullRequestReadinessRetry _self;
  final $Res Function(PullRequestReadinessRetry) _then;

/// Create a copy of PullRequestReadinessRetry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ready = null,Object? baseline = null,Object? error = null,}) {
  return _then(PullRequestReadinessRetry(
ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,baseline: null == baseline ? _self.baseline : baseline // ignore: cast_nullable_to_non_nullable
as PullRequestSnapshot,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of PullRequestReadinessRetry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestSnapshotCopyWith<$Res> get baseline {
  
  return $PullRequestSnapshotCopyWith<$Res>(_self.baseline, (value) {
    return _then(_self.copyWith(baseline: value));
  });
}
}



/// @nodoc


class _PullRequestReadinessRetry implements PullRequestReadinessRetry {
  const _PullRequestReadinessRetry({required this.ready, required this.baseline, required this.error});
  

@override final  bool ready;
@override final  PullRequestSnapshot baseline;
@override final  String error;

/// Create a copy of PullRequestReadinessRetry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestReadinessRetryCopyWith<_PullRequestReadinessRetry> get copyWith => __$PullRequestReadinessRetryCopyWithImpl<_PullRequestReadinessRetry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestReadinessRetry&&(identical(other.ready, ready) || other.ready == ready)&&(identical(other.baseline, baseline) || other.baseline == baseline)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ready,baseline,error);
}

@override
String toString() {
    return 'PullRequestReadinessRetry(ready: $ready, baseline: $baseline, error: $error)';
}


}

/// @nodoc
abstract mixin class _$PullRequestReadinessRetryCopyWith<$Res> implements $PullRequestReadinessRetryCopyWith<$Res> {
  factory _$PullRequestReadinessRetryCopyWith(_PullRequestReadinessRetry value, $Res Function(_PullRequestReadinessRetry) _then) = __$PullRequestReadinessRetryCopyWithImpl;
@override @useResult
$Res call({
 bool ready, PullRequestSnapshot baseline, String error
});


@override $PullRequestSnapshotCopyWith<$Res> get baseline;

}
/// @nodoc
class __$PullRequestReadinessRetryCopyWithImpl<$Res>
    implements _$PullRequestReadinessRetryCopyWith<$Res> {
  __$PullRequestReadinessRetryCopyWithImpl(this._self, this._then);

  final _PullRequestReadinessRetry _self;
  final $Res Function(_PullRequestReadinessRetry) _then;

/// Create a copy of PullRequestReadinessRetry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ready = null,Object? baseline = null,Object? error = null,}) {
  return _then(_PullRequestReadinessRetry(
ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,baseline: null == baseline ? _self.baseline : baseline // ignore: cast_nullable_to_non_nullable
as PullRequestSnapshot,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of PullRequestReadinessRetry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestSnapshotCopyWith<$Res> get baseline {
  
  return $PullRequestSnapshotCopyWith<$Res>(_self.baseline, (value) {
    return _then(_self.copyWith(baseline: value));
  });
}
}

// dart format on
