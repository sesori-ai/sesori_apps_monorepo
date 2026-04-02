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

 int get number; String get url; String get title; String get state; String get headRefName; String? get mergeable; String? get reviewDecision; String? get statusCheckRollup;
/// Create a copy of GhPullRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhPullRequestCopyWith<GhPullRequest> get copyWith => _$GhPullRequestCopyWithImpl<GhPullRequest>(this as GhPullRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhPullRequest&&(identical(other.number, number) || other.number == number)&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.state, state) || other.state == state)&&(identical(other.headRefName, headRefName) || other.headRefName == headRefName)&&(identical(other.mergeable, mergeable) || other.mergeable == mergeable)&&(identical(other.reviewDecision, reviewDecision) || other.reviewDecision == reviewDecision)&&(identical(other.statusCheckRollup, statusCheckRollup) || other.statusCheckRollup == statusCheckRollup));
}


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
 int number, String url, String title, String state, String headRefName, String? mergeable, String? reviewDecision, String? statusCheckRollup
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
@pragma('vm:prefer-inline') @override $Res call({Object? number = null,Object? url = null,Object? title = null,Object? state = null,Object? headRefName = null,Object? mergeable = freezed,Object? reviewDecision = freezed,Object? statusCheckRollup = freezed,}) {
  return _then(_self.copyWith(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,headRefName: null == headRefName ? _self.headRefName : headRefName // ignore: cast_nullable_to_non_nullable
as String,mergeable: freezed == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as String?,reviewDecision: freezed == reviewDecision ? _self.reviewDecision : reviewDecision // ignore: cast_nullable_to_non_nullable
as String?,statusCheckRollup: freezed == statusCheckRollup ? _self.statusCheckRollup : statusCheckRollup // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc


class _GhPullRequest implements GhPullRequest {
  const _GhPullRequest({required this.number, required this.url, required this.title, required this.state, required this.headRefName, required this.mergeable, required this.reviewDecision, required this.statusCheckRollup});
  

@override final  int number;
@override final  String url;
@override final  String title;
@override final  String state;
@override final  String headRefName;
@override final  String? mergeable;
@override final  String? reviewDecision;
@override final  String? statusCheckRollup;

/// Create a copy of GhPullRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhPullRequestCopyWith<_GhPullRequest> get copyWith => __$GhPullRequestCopyWithImpl<_GhPullRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhPullRequest&&(identical(other.number, number) || other.number == number)&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.state, state) || other.state == state)&&(identical(other.headRefName, headRefName) || other.headRefName == headRefName)&&(identical(other.mergeable, mergeable) || other.mergeable == mergeable)&&(identical(other.reviewDecision, reviewDecision) || other.reviewDecision == reviewDecision)&&(identical(other.statusCheckRollup, statusCheckRollup) || other.statusCheckRollup == statusCheckRollup));
}


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
 int number, String url, String title, String state, String headRefName, String? mergeable, String? reviewDecision, String? statusCheckRollup
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
@override @pragma('vm:prefer-inline') $Res call({Object? number = null,Object? url = null,Object? title = null,Object? state = null,Object? headRefName = null,Object? mergeable = freezed,Object? reviewDecision = freezed,Object? statusCheckRollup = freezed,}) {
  return _then(_GhPullRequest(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,headRefName: null == headRefName ? _self.headRefName : headRefName // ignore: cast_nullable_to_non_nullable
as String,mergeable: freezed == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as String?,reviewDecision: freezed == reviewDecision ? _self.reviewDecision : reviewDecision // ignore: cast_nullable_to_non_nullable
as String?,statusCheckRollup: freezed == statusCheckRollup ? _self.statusCheckRollup : statusCheckRollup // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
