// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pull_request_baseline.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PullRequestBaseline {

 PullRequestState get state; String get headSha; PullRequestMergeable get mergeable;/// Whether any check was still pending.
 bool get ciRunning; Set<String> get failedCheckIds;/// Each latest review's author, state and time, plus the pending
/// reviewers.
 String get reviewSignature;/// Relevant comments only: the agent's prefixed replies are never news.
 Set<String> get issueCommentIds; int get issueCommentsTotal; Set<String> get reviewSummaryIds;/// Relevant comment ids per review thread id.
 Map<String, Set<String>> get threadCommentIds; Set<String> get resolvedThreadIds; int get unresolvedThreadCount;
/// Create a copy of PullRequestBaseline
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestBaselineCopyWith<PullRequestBaseline> get copyWith => _$PullRequestBaselineCopyWithImpl<PullRequestBaseline>(this as PullRequestBaseline, _$identity);

  /// Serializes this PullRequestBaseline to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PullRequestBaseline;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestBaseline&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.headSha, _this.headSha) || other.headSha == _this.headSha)&&(identical(other.mergeable, _this.mergeable) || other.mergeable == _this.mergeable)&&(identical(other.ciRunning, _this.ciRunning) || other.ciRunning == _this.ciRunning)&&const DeepCollectionEquality().equals(other.failedCheckIds, _this.failedCheckIds)&&(identical(other.reviewSignature, _this.reviewSignature) || other.reviewSignature == _this.reviewSignature)&&const DeepCollectionEquality().equals(other.issueCommentIds, _this.issueCommentIds)&&(identical(other.issueCommentsTotal, _this.issueCommentsTotal) || other.issueCommentsTotal == _this.issueCommentsTotal)&&const DeepCollectionEquality().equals(other.reviewSummaryIds, _this.reviewSummaryIds)&&const DeepCollectionEquality().equals(other.threadCommentIds, _this.threadCommentIds)&&const DeepCollectionEquality().equals(other.resolvedThreadIds, _this.resolvedThreadIds)&&(identical(other.unresolvedThreadCount, _this.unresolvedThreadCount) || other.unresolvedThreadCount == _this.unresolvedThreadCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PullRequestBaseline;
  return Object.hash(runtimeType,_this.state,_this.headSha,_this.mergeable,_this.ciRunning,const DeepCollectionEquality().hash(_this.failedCheckIds),_this.reviewSignature,const DeepCollectionEquality().hash(_this.issueCommentIds),_this.issueCommentsTotal,const DeepCollectionEquality().hash(_this.reviewSummaryIds),const DeepCollectionEquality().hash(_this.threadCommentIds),const DeepCollectionEquality().hash(_this.resolvedThreadIds),_this.unresolvedThreadCount);
}

@override
String toString() {
  final _this = this as PullRequestBaseline;
  return 'PullRequestBaseline(state: ${_this.state}, headSha: ${_this.headSha}, mergeable: ${_this.mergeable}, ciRunning: ${_this.ciRunning}, failedCheckIds: ${_this.failedCheckIds}, reviewSignature: ${_this.reviewSignature}, issueCommentIds: ${_this.issueCommentIds}, issueCommentsTotal: ${_this.issueCommentsTotal}, reviewSummaryIds: ${_this.reviewSummaryIds}, threadCommentIds: ${_this.threadCommentIds}, resolvedThreadIds: ${_this.resolvedThreadIds}, unresolvedThreadCount: ${_this.unresolvedThreadCount})';
}


}

/// @nodoc
abstract mixin class $PullRequestBaselineCopyWith<$Res>  {
  factory $PullRequestBaselineCopyWith(PullRequestBaseline value, $Res Function(PullRequestBaseline) _then) = _$PullRequestBaselineCopyWithImpl;
@useResult
$Res call({
 PullRequestState state, String headSha, PullRequestMergeable mergeable, bool ciRunning, Set<String> failedCheckIds, String reviewSignature, Set<String> issueCommentIds, int issueCommentsTotal, Set<String> reviewSummaryIds, Map<String, Set<String>> threadCommentIds, Set<String> resolvedThreadIds, int unresolvedThreadCount
});




}
/// @nodoc
class _$PullRequestBaselineCopyWithImpl<$Res>
    implements $PullRequestBaselineCopyWith<$Res> {
  _$PullRequestBaselineCopyWithImpl(this._self, this._then);

  final PullRequestBaseline _self;
  final $Res Function(PullRequestBaseline) _then;

/// Create a copy of PullRequestBaseline
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = null,Object? headSha = null,Object? mergeable = null,Object? ciRunning = null,Object? failedCheckIds = null,Object? reviewSignature = null,Object? issueCommentIds = null,Object? issueCommentsTotal = null,Object? reviewSummaryIds = null,Object? threadCommentIds = null,Object? resolvedThreadIds = null,Object? unresolvedThreadCount = null,}) {
  return _then(PullRequestBaseline(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PullRequestState,headSha: null == headSha ? _self.headSha : headSha // ignore: cast_nullable_to_non_nullable
as String,mergeable: null == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as PullRequestMergeable,ciRunning: null == ciRunning ? _self.ciRunning : ciRunning // ignore: cast_nullable_to_non_nullable
as bool,failedCheckIds: null == failedCheckIds ? _self.failedCheckIds : failedCheckIds // ignore: cast_nullable_to_non_nullable
as Set<String>,reviewSignature: null == reviewSignature ? _self.reviewSignature : reviewSignature // ignore: cast_nullable_to_non_nullable
as String,issueCommentIds: null == issueCommentIds ? _self.issueCommentIds : issueCommentIds // ignore: cast_nullable_to_non_nullable
as Set<String>,issueCommentsTotal: null == issueCommentsTotal ? _self.issueCommentsTotal : issueCommentsTotal // ignore: cast_nullable_to_non_nullable
as int,reviewSummaryIds: null == reviewSummaryIds ? _self.reviewSummaryIds : reviewSummaryIds // ignore: cast_nullable_to_non_nullable
as Set<String>,threadCommentIds: null == threadCommentIds ? _self.threadCommentIds : threadCommentIds // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,resolvedThreadIds: null == resolvedThreadIds ? _self.resolvedThreadIds : resolvedThreadIds // ignore: cast_nullable_to_non_nullable
as Set<String>,unresolvedThreadCount: null == unresolvedThreadCount ? _self.unresolvedThreadCount : unresolvedThreadCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PullRequestBaseline implements PullRequestBaseline {
  const _PullRequestBaseline({required this.state, required this.headSha, required this.mergeable, required this.ciRunning, required  Set<String> failedCheckIds, required this.reviewSignature, required  Set<String> issueCommentIds, required this.issueCommentsTotal, required  Set<String> reviewSummaryIds, required  Map<String, Set<String>> threadCommentIds, required  Set<String> resolvedThreadIds, required this.unresolvedThreadCount}): _failedCheckIds = failedCheckIds,_issueCommentIds = issueCommentIds,_reviewSummaryIds = reviewSummaryIds,_threadCommentIds = threadCommentIds,_resolvedThreadIds = resolvedThreadIds;
  factory _PullRequestBaseline.fromJson(Map<String, dynamic> json) => _$PullRequestBaselineFromJson(json);

@override final  PullRequestState state;
@override final  String headSha;
@override final  PullRequestMergeable mergeable;
/// Whether any check was still pending.
@override final  bool ciRunning;
 final  Set<String> _failedCheckIds;
@override Set<String> get failedCheckIds {
  if (_failedCheckIds is EqualUnmodifiableSetView) return _failedCheckIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_failedCheckIds);
}

/// Each latest review's author, state and time, plus the pending
/// reviewers.
@override final  String reviewSignature;
/// Relevant comments only: the agent's prefixed replies are never news.
 final  Set<String> _issueCommentIds;
/// Relevant comments only: the agent's prefixed replies are never news.
@override Set<String> get issueCommentIds {
  if (_issueCommentIds is EqualUnmodifiableSetView) return _issueCommentIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_issueCommentIds);
}

@override final  int issueCommentsTotal;
 final  Set<String> _reviewSummaryIds;
@override Set<String> get reviewSummaryIds {
  if (_reviewSummaryIds is EqualUnmodifiableSetView) return _reviewSummaryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_reviewSummaryIds);
}

/// Relevant comment ids per review thread id.
 final  Map<String, Set<String>> _threadCommentIds;
/// Relevant comment ids per review thread id.
@override Map<String, Set<String>> get threadCommentIds {
  if (_threadCommentIds is EqualUnmodifiableMapView) return _threadCommentIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_threadCommentIds);
}

 final  Set<String> _resolvedThreadIds;
@override Set<String> get resolvedThreadIds {
  if (_resolvedThreadIds is EqualUnmodifiableSetView) return _resolvedThreadIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_resolvedThreadIds);
}

@override final  int unresolvedThreadCount;

/// Create a copy of PullRequestBaseline
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestBaselineCopyWith<_PullRequestBaseline> get copyWith => __$PullRequestBaselineCopyWithImpl<_PullRequestBaseline>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestBaselineToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestBaseline&&(identical(other.state, state) || other.state == state)&&(identical(other.headSha, headSha) || other.headSha == headSha)&&(identical(other.mergeable, mergeable) || other.mergeable == mergeable)&&(identical(other.ciRunning, ciRunning) || other.ciRunning == ciRunning)&&const DeepCollectionEquality().equals(other.failedCheckIds, _failedCheckIds)&&(identical(other.reviewSignature, reviewSignature) || other.reviewSignature == reviewSignature)&&const DeepCollectionEquality().equals(other.issueCommentIds, _issueCommentIds)&&(identical(other.issueCommentsTotal, issueCommentsTotal) || other.issueCommentsTotal == issueCommentsTotal)&&const DeepCollectionEquality().equals(other.reviewSummaryIds, _reviewSummaryIds)&&const DeepCollectionEquality().equals(other.threadCommentIds, _threadCommentIds)&&const DeepCollectionEquality().equals(other.resolvedThreadIds, _resolvedThreadIds)&&(identical(other.unresolvedThreadCount, unresolvedThreadCount) || other.unresolvedThreadCount == unresolvedThreadCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,state,headSha,mergeable,ciRunning,const DeepCollectionEquality().hash(_failedCheckIds),reviewSignature,const DeepCollectionEquality().hash(_issueCommentIds),issueCommentsTotal,const DeepCollectionEquality().hash(_reviewSummaryIds),const DeepCollectionEquality().hash(_threadCommentIds),const DeepCollectionEquality().hash(_resolvedThreadIds),unresolvedThreadCount);
}

@override
String toString() {
    return 'PullRequestBaseline(state: $state, headSha: $headSha, mergeable: $mergeable, ciRunning: $ciRunning, failedCheckIds: $failedCheckIds, reviewSignature: $reviewSignature, issueCommentIds: $issueCommentIds, issueCommentsTotal: $issueCommentsTotal, reviewSummaryIds: $reviewSummaryIds, threadCommentIds: $threadCommentIds, resolvedThreadIds: $resolvedThreadIds, unresolvedThreadCount: $unresolvedThreadCount)';
}


}

/// @nodoc
abstract mixin class _$PullRequestBaselineCopyWith<$Res> implements $PullRequestBaselineCopyWith<$Res> {
  factory _$PullRequestBaselineCopyWith(_PullRequestBaseline value, $Res Function(_PullRequestBaseline) _then) = __$PullRequestBaselineCopyWithImpl;
@override @useResult
$Res call({
 PullRequestState state, String headSha, PullRequestMergeable mergeable, bool ciRunning, Set<String> failedCheckIds, String reviewSignature, Set<String> issueCommentIds, int issueCommentsTotal, Set<String> reviewSummaryIds, Map<String, Set<String>> threadCommentIds, Set<String> resolvedThreadIds, int unresolvedThreadCount
});




}
/// @nodoc
class __$PullRequestBaselineCopyWithImpl<$Res>
    implements _$PullRequestBaselineCopyWith<$Res> {
  __$PullRequestBaselineCopyWithImpl(this._self, this._then);

  final _PullRequestBaseline _self;
  final $Res Function(_PullRequestBaseline) _then;

/// Create a copy of PullRequestBaseline
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = null,Object? headSha = null,Object? mergeable = null,Object? ciRunning = null,Object? failedCheckIds = null,Object? reviewSignature = null,Object? issueCommentIds = null,Object? issueCommentsTotal = null,Object? reviewSummaryIds = null,Object? threadCommentIds = null,Object? resolvedThreadIds = null,Object? unresolvedThreadCount = null,}) {
  return _then(_PullRequestBaseline(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PullRequestState,headSha: null == headSha ? _self.headSha : headSha // ignore: cast_nullable_to_non_nullable
as String,mergeable: null == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as PullRequestMergeable,ciRunning: null == ciRunning ? _self.ciRunning : ciRunning // ignore: cast_nullable_to_non_nullable
as bool,failedCheckIds: null == failedCheckIds ? _self._failedCheckIds : failedCheckIds // ignore: cast_nullable_to_non_nullable
as Set<String>,reviewSignature: null == reviewSignature ? _self.reviewSignature : reviewSignature // ignore: cast_nullable_to_non_nullable
as String,issueCommentIds: null == issueCommentIds ? _self._issueCommentIds : issueCommentIds // ignore: cast_nullable_to_non_nullable
as Set<String>,issueCommentsTotal: null == issueCommentsTotal ? _self.issueCommentsTotal : issueCommentsTotal // ignore: cast_nullable_to_non_nullable
as int,reviewSummaryIds: null == reviewSummaryIds ? _self._reviewSummaryIds : reviewSummaryIds // ignore: cast_nullable_to_non_nullable
as Set<String>,threadCommentIds: null == threadCommentIds ? _self._threadCommentIds : threadCommentIds // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,resolvedThreadIds: null == resolvedThreadIds ? _self._resolvedThreadIds : resolvedThreadIds // ignore: cast_nullable_to_non_nullable
as Set<String>,unresolvedThreadCount: null == unresolvedThreadCount ? _self.unresolvedThreadCount : unresolvedThreadCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
