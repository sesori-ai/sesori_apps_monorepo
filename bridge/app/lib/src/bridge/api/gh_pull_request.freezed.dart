// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gh_pull_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GhPullRequest {

 int get number; String get url; String get title;@JsonKey(fromJson: _prStateFromString) PrState get state; String get headRefName;@JsonKey(fromJson: _prMergeableStatusFromString) PrMergeableStatus get mergeable;@JsonKey(fromJson: _prReviewDecisionFromString) PrReviewDecision get reviewDecision;@JsonKey(fromJson: _prCheckStatusFromRollup, toJson: _rollupStateToJson) PrCheckStatus get statusCheckRollup;
/// Create a copy of GhPullRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhPullRequestCopyWith<GhPullRequest> get copyWith => _$GhPullRequestCopyWithImpl<GhPullRequest>(this as GhPullRequest, _$identity);

  /// Serializes this GhPullRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhPullRequest&&(identical(other.number, number) || other.number == number)&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.state, state) || other.state == state)&&(identical(other.headRefName, headRefName) || other.headRefName == headRefName)&&(identical(other.mergeable, mergeable) || other.mergeable == mergeable)&&(identical(other.reviewDecision, reviewDecision) || other.reviewDecision == reviewDecision)&&(identical(other.statusCheckRollup, statusCheckRollup) || other.statusCheckRollup == statusCheckRollup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,number,url,title,state,headRefName,mergeable,reviewDecision,statusCheckRollup);

@override
String toString() {
  return 'GhPullRequest(number: $number, url: $url, title: $title, state: $state, headRefName: $headRefName, mergeable: $mergeable, reviewDecision: $reviewDecision, statusCheckRollup: $statusCheckRollup)';
}


}

/// @nodoc
abstract mixin class $GhPullRequestCopyWith<$Res>  {
  factory $GhPullRequestCopyWith(GhPullRequest value, $Res Function(GhPullRequest) _then) = _$GhPullRequestCopyWithImpl;
@useResult
$Res call({
 int number, String url, String title,@JsonKey(fromJson: _prStateFromString) PrState state, String headRefName,@JsonKey(fromJson: _prMergeableStatusFromString) PrMergeableStatus mergeable,@JsonKey(fromJson: _prReviewDecisionFromString) PrReviewDecision reviewDecision,@JsonKey(fromJson: _prCheckStatusFromRollup, toJson: _rollupStateToJson) PrCheckStatus statusCheckRollup
});




}
/// @nodoc
class _$GhPullRequestCopyWithImpl<$Res>
    implements $GhPullRequestCopyWith<$Res> {
  _$GhPullRequestCopyWithImpl(this._self, this._then);

  final GhPullRequest _self;
  final $Res Function(GhPullRequest) _then;

/// Create a copy of GhPullRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? number = null,Object? url = null,Object? title = null,Object? state = null,Object? headRefName = null,Object? mergeable = null,Object? reviewDecision = null,Object? statusCheckRollup = null,}) {
  return _then(_self.copyWith(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PrState,headRefName: null == headRefName ? _self.headRefName : headRefName // ignore: cast_nullable_to_non_nullable
as String,mergeable: null == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as PrMergeableStatus,reviewDecision: null == reviewDecision ? _self.reviewDecision : reviewDecision // ignore: cast_nullable_to_non_nullable
as PrReviewDecision,statusCheckRollup: null == statusCheckRollup ? _self.statusCheckRollup : statusCheckRollup // ignore: cast_nullable_to_non_nullable
as PrCheckStatus,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _GhPullRequest implements GhPullRequest {
  const _GhPullRequest({required this.number, required this.url, required this.title, @JsonKey(fromJson: _prStateFromString) required this.state, required this.headRefName, @JsonKey(fromJson: _prMergeableStatusFromString) required this.mergeable, @JsonKey(fromJson: _prReviewDecisionFromString) required this.reviewDecision, @JsonKey(fromJson: _prCheckStatusFromRollup, toJson: _rollupStateToJson) required this.statusCheckRollup});
  factory _GhPullRequest.fromJson(Map<String, dynamic> json) => _$GhPullRequestFromJson(json);

@override final  int number;
@override final  String url;
@override final  String title;
@override@JsonKey(fromJson: _prStateFromString) final  PrState state;
@override final  String headRefName;
@override@JsonKey(fromJson: _prMergeableStatusFromString) final  PrMergeableStatus mergeable;
@override@JsonKey(fromJson: _prReviewDecisionFromString) final  PrReviewDecision reviewDecision;
@override@JsonKey(fromJson: _prCheckStatusFromRollup, toJson: _rollupStateToJson) final  PrCheckStatus statusCheckRollup;

/// Create a copy of GhPullRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhPullRequestCopyWith<_GhPullRequest> get copyWith => __$GhPullRequestCopyWithImpl<_GhPullRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GhPullRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhPullRequest&&(identical(other.number, number) || other.number == number)&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.state, state) || other.state == state)&&(identical(other.headRefName, headRefName) || other.headRefName == headRefName)&&(identical(other.mergeable, mergeable) || other.mergeable == mergeable)&&(identical(other.reviewDecision, reviewDecision) || other.reviewDecision == reviewDecision)&&(identical(other.statusCheckRollup, statusCheckRollup) || other.statusCheckRollup == statusCheckRollup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,number,url,title,state,headRefName,mergeable,reviewDecision,statusCheckRollup);

@override
String toString() {
  return 'GhPullRequest(number: $number, url: $url, title: $title, state: $state, headRefName: $headRefName, mergeable: $mergeable, reviewDecision: $reviewDecision, statusCheckRollup: $statusCheckRollup)';
}


}

/// @nodoc
abstract mixin class _$GhPullRequestCopyWith<$Res> implements $GhPullRequestCopyWith<$Res> {
  factory _$GhPullRequestCopyWith(_GhPullRequest value, $Res Function(_GhPullRequest) _then) = __$GhPullRequestCopyWithImpl;
@override @useResult
$Res call({
 int number, String url, String title,@JsonKey(fromJson: _prStateFromString) PrState state, String headRefName,@JsonKey(fromJson: _prMergeableStatusFromString) PrMergeableStatus mergeable,@JsonKey(fromJson: _prReviewDecisionFromString) PrReviewDecision reviewDecision,@JsonKey(fromJson: _prCheckStatusFromRollup, toJson: _rollupStateToJson) PrCheckStatus statusCheckRollup
});




}
/// @nodoc
class __$GhPullRequestCopyWithImpl<$Res>
    implements _$GhPullRequestCopyWith<$Res> {
  __$GhPullRequestCopyWithImpl(this._self, this._then);

  final _GhPullRequest _self;
  final $Res Function(_GhPullRequest) _then;

/// Create a copy of GhPullRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? number = null,Object? url = null,Object? title = null,Object? state = null,Object? headRefName = null,Object? mergeable = null,Object? reviewDecision = null,Object? statusCheckRollup = null,}) {
  return _then(_GhPullRequest(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PrState,headRefName: null == headRefName ? _self.headRefName : headRefName // ignore: cast_nullable_to_non_nullable
as String,mergeable: null == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as PrMergeableStatus,reviewDecision: null == reviewDecision ? _self.reviewDecision : reviewDecision // ignore: cast_nullable_to_non_nullable
as PrReviewDecision,statusCheckRollup: null == statusCheckRollup ? _self.statusCheckRollup : statusCheckRollup // ignore: cast_nullable_to_non_nullable
as PrCheckStatus,
  ));
}


}

// dart format on
