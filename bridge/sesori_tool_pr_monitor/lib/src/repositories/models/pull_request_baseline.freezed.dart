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

 Set<String> get issueCommentIds; Set<String> get reviewSummaryIds;/// Comment ids per review thread id.
 Map<String, Set<String>> get threadCommentIds; int get unresolvedThreadCount;
/// Create a copy of PullRequestBaseline
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestBaselineCopyWith<PullRequestBaseline> get copyWith => _$PullRequestBaselineCopyWithImpl<PullRequestBaseline>(this as PullRequestBaseline, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PullRequestBaseline;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestBaseline&&const DeepCollectionEquality().equals(other.issueCommentIds, _this.issueCommentIds)&&const DeepCollectionEquality().equals(other.reviewSummaryIds, _this.reviewSummaryIds)&&const DeepCollectionEquality().equals(other.threadCommentIds, _this.threadCommentIds)&&(identical(other.unresolvedThreadCount, _this.unresolvedThreadCount) || other.unresolvedThreadCount == _this.unresolvedThreadCount));
}


@override
int get hashCode {
  final _this = this as PullRequestBaseline;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.issueCommentIds),const DeepCollectionEquality().hash(_this.reviewSummaryIds),const DeepCollectionEquality().hash(_this.threadCommentIds),_this.unresolvedThreadCount);
}

@override
String toString() {
  final _this = this as PullRequestBaseline;
  return 'PullRequestBaseline(issueCommentIds: ${_this.issueCommentIds}, reviewSummaryIds: ${_this.reviewSummaryIds}, threadCommentIds: ${_this.threadCommentIds}, unresolvedThreadCount: ${_this.unresolvedThreadCount})';
}


}

/// @nodoc
abstract mixin class $PullRequestBaselineCopyWith<$Res>  {
  factory $PullRequestBaselineCopyWith(PullRequestBaseline value, $Res Function(PullRequestBaseline) _then) = _$PullRequestBaselineCopyWithImpl;
@useResult
$Res call({
 Set<String> issueCommentIds, Set<String> reviewSummaryIds, Map<String, Set<String>> threadCommentIds, int unresolvedThreadCount
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
@pragma('vm:prefer-inline') @override $Res call({Object? issueCommentIds = null,Object? reviewSummaryIds = null,Object? threadCommentIds = null,Object? unresolvedThreadCount = null,}) {
  return _then(PullRequestBaseline(
issueCommentIds: null == issueCommentIds ? _self.issueCommentIds : issueCommentIds // ignore: cast_nullable_to_non_nullable
as Set<String>,reviewSummaryIds: null == reviewSummaryIds ? _self.reviewSummaryIds : reviewSummaryIds // ignore: cast_nullable_to_non_nullable
as Set<String>,threadCommentIds: null == threadCommentIds ? _self.threadCommentIds : threadCommentIds // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,unresolvedThreadCount: null == unresolvedThreadCount ? _self.unresolvedThreadCount : unresolvedThreadCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc


class _PullRequestBaseline implements PullRequestBaseline {
  const _PullRequestBaseline({required  Set<String> issueCommentIds, required  Set<String> reviewSummaryIds, required  Map<String, Set<String>> threadCommentIds, required this.unresolvedThreadCount}): _issueCommentIds = issueCommentIds,_reviewSummaryIds = reviewSummaryIds,_threadCommentIds = threadCommentIds;
  

 final  Set<String> _issueCommentIds;
@override Set<String> get issueCommentIds {
  if (_issueCommentIds is EqualUnmodifiableSetView) return _issueCommentIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_issueCommentIds);
}

 final  Set<String> _reviewSummaryIds;
@override Set<String> get reviewSummaryIds {
  if (_reviewSummaryIds is EqualUnmodifiableSetView) return _reviewSummaryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_reviewSummaryIds);
}

/// Comment ids per review thread id.
 final  Map<String, Set<String>> _threadCommentIds;
/// Comment ids per review thread id.
@override Map<String, Set<String>> get threadCommentIds {
  if (_threadCommentIds is EqualUnmodifiableMapView) return _threadCommentIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_threadCommentIds);
}

@override final  int unresolvedThreadCount;

/// Create a copy of PullRequestBaseline
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestBaselineCopyWith<_PullRequestBaseline> get copyWith => __$PullRequestBaselineCopyWithImpl<_PullRequestBaseline>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestBaseline&&const DeepCollectionEquality().equals(other.issueCommentIds, _issueCommentIds)&&const DeepCollectionEquality().equals(other.reviewSummaryIds, _reviewSummaryIds)&&const DeepCollectionEquality().equals(other.threadCommentIds, _threadCommentIds)&&(identical(other.unresolvedThreadCount, unresolvedThreadCount) || other.unresolvedThreadCount == unresolvedThreadCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_issueCommentIds),const DeepCollectionEquality().hash(_reviewSummaryIds),const DeepCollectionEquality().hash(_threadCommentIds),unresolvedThreadCount);
}

@override
String toString() {
    return 'PullRequestBaseline(issueCommentIds: $issueCommentIds, reviewSummaryIds: $reviewSummaryIds, threadCommentIds: $threadCommentIds, unresolvedThreadCount: $unresolvedThreadCount)';
}


}

/// @nodoc
abstract mixin class _$PullRequestBaselineCopyWith<$Res> implements $PullRequestBaselineCopyWith<$Res> {
  factory _$PullRequestBaselineCopyWith(_PullRequestBaseline value, $Res Function(_PullRequestBaseline) _then) = __$PullRequestBaselineCopyWithImpl;
@override @useResult
$Res call({
 Set<String> issueCommentIds, Set<String> reviewSummaryIds, Map<String, Set<String>> threadCommentIds, int unresolvedThreadCount
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
@override @pragma('vm:prefer-inline') $Res call({Object? issueCommentIds = null,Object? reviewSummaryIds = null,Object? threadCommentIds = null,Object? unresolvedThreadCount = null,}) {
  return _then(_PullRequestBaseline(
issueCommentIds: null == issueCommentIds ? _self._issueCommentIds : issueCommentIds // ignore: cast_nullable_to_non_nullable
as Set<String>,reviewSummaryIds: null == reviewSummaryIds ? _self._reviewSummaryIds : reviewSummaryIds // ignore: cast_nullable_to_non_nullable
as Set<String>,threadCommentIds: null == threadCommentIds ? _self._threadCommentIds : threadCommentIds // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,unresolvedThreadCount: null == unresolvedThreadCount ? _self.unresolvedThreadCount : unresolvedThreadCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
