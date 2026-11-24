// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gh_pull_request_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GhPullRequestDto {

 String get title; String get url; GhPullRequestStateDto get state;@JsonKey(unknownEnumValue: GhMergeableStateDto.unknown) GhMergeableStateDto get mergeable; String get headRefOid; GhCommitConnectionDto get commits; GhReviewRequestConnectionDto get reviewRequests; GhReviewConnectionDto get latestReviews; GhReviewThreadConnectionDto get reviewThreads; GhIssueCommentConnectionDto get comments; GhLabelConnectionDto get labels;
/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhPullRequestDtoCopyWith<GhPullRequestDto> get copyWith => _$GhPullRequestDtoCopyWithImpl<GhPullRequestDto>(this as GhPullRequestDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhPullRequestDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhPullRequestDto&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.mergeable, _this.mergeable) || other.mergeable == _this.mergeable)&&(identical(other.headRefOid, _this.headRefOid) || other.headRefOid == _this.headRefOid)&&(identical(other.commits, _this.commits) || other.commits == _this.commits)&&(identical(other.reviewRequests, _this.reviewRequests) || other.reviewRequests == _this.reviewRequests)&&(identical(other.latestReviews, _this.latestReviews) || other.latestReviews == _this.latestReviews)&&(identical(other.reviewThreads, _this.reviewThreads) || other.reviewThreads == _this.reviewThreads)&&(identical(other.comments, _this.comments) || other.comments == _this.comments)&&(identical(other.labels, _this.labels) || other.labels == _this.labels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhPullRequestDto;
  return Object.hash(runtimeType,_this.title,_this.url,_this.state,_this.mergeable,_this.headRefOid,_this.commits,_this.reviewRequests,_this.latestReviews,_this.reviewThreads,_this.comments,_this.labels);
}

@override
String toString() {
  final _this = this as GhPullRequestDto;
  return 'GhPullRequestDto(title: ${_this.title}, url: ${_this.url}, state: ${_this.state}, mergeable: ${_this.mergeable}, headRefOid: ${_this.headRefOid}, commits: ${_this.commits}, reviewRequests: ${_this.reviewRequests}, latestReviews: ${_this.latestReviews}, reviewThreads: ${_this.reviewThreads}, comments: ${_this.comments}, labels: ${_this.labels})';
}


}

/// @nodoc
abstract mixin class $GhPullRequestDtoCopyWith<$Res>  {
  factory $GhPullRequestDtoCopyWith(GhPullRequestDto value, $Res Function(GhPullRequestDto) _then) = _$GhPullRequestDtoCopyWithImpl;
@useResult
$Res call({
 String title, String url, GhPullRequestStateDto state,@JsonKey(unknownEnumValue: GhMergeableStateDto.unknown) GhMergeableStateDto mergeable, String headRefOid, GhCommitConnectionDto commits, GhReviewRequestConnectionDto reviewRequests, GhReviewConnectionDto latestReviews, GhReviewThreadConnectionDto reviewThreads, GhIssueCommentConnectionDto comments, GhLabelConnectionDto labels
});


$GhCommitConnectionDtoCopyWith<$Res> get commits;$GhReviewRequestConnectionDtoCopyWith<$Res> get reviewRequests;$GhReviewConnectionDtoCopyWith<$Res> get latestReviews;$GhReviewThreadConnectionDtoCopyWith<$Res> get reviewThreads;$GhIssueCommentConnectionDtoCopyWith<$Res> get comments;$GhLabelConnectionDtoCopyWith<$Res> get labels;

}
/// @nodoc
class _$GhPullRequestDtoCopyWithImpl<$Res>
    implements $GhPullRequestDtoCopyWith<$Res> {
  _$GhPullRequestDtoCopyWithImpl(this._self, this._then);

  final GhPullRequestDto _self;
  final $Res Function(GhPullRequestDto) _then;

/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? url = null,Object? state = null,Object? mergeable = null,Object? headRefOid = null,Object? commits = null,Object? reviewRequests = null,Object? latestReviews = null,Object? reviewThreads = null,Object? comments = null,Object? labels = null,}) {
  return _then(GhPullRequestDto(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as GhPullRequestStateDto,mergeable: null == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as GhMergeableStateDto,headRefOid: null == headRefOid ? _self.headRefOid : headRefOid // ignore: cast_nullable_to_non_nullable
as String,commits: null == commits ? _self.commits : commits // ignore: cast_nullable_to_non_nullable
as GhCommitConnectionDto,reviewRequests: null == reviewRequests ? _self.reviewRequests : reviewRequests // ignore: cast_nullable_to_non_nullable
as GhReviewRequestConnectionDto,latestReviews: null == latestReviews ? _self.latestReviews : latestReviews // ignore: cast_nullable_to_non_nullable
as GhReviewConnectionDto,reviewThreads: null == reviewThreads ? _self.reviewThreads : reviewThreads // ignore: cast_nullable_to_non_nullable
as GhReviewThreadConnectionDto,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as GhIssueCommentConnectionDto,labels: null == labels ? _self.labels : labels // ignore: cast_nullable_to_non_nullable
as GhLabelConnectionDto,
  ));
}
/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhCommitConnectionDtoCopyWith<$Res> get commits {
  
  return $GhCommitConnectionDtoCopyWith<$Res>(_self.commits, (value) {
    return _then(_self.copyWith(commits: value));
  });
}/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhReviewRequestConnectionDtoCopyWith<$Res> get reviewRequests {
  
  return $GhReviewRequestConnectionDtoCopyWith<$Res>(_self.reviewRequests, (value) {
    return _then(_self.copyWith(reviewRequests: value));
  });
}/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhReviewConnectionDtoCopyWith<$Res> get latestReviews {
  
  return $GhReviewConnectionDtoCopyWith<$Res>(_self.latestReviews, (value) {
    return _then(_self.copyWith(latestReviews: value));
  });
}/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhReviewThreadConnectionDtoCopyWith<$Res> get reviewThreads {
  
  return $GhReviewThreadConnectionDtoCopyWith<$Res>(_self.reviewThreads, (value) {
    return _then(_self.copyWith(reviewThreads: value));
  });
}/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhIssueCommentConnectionDtoCopyWith<$Res> get comments {
  
  return $GhIssueCommentConnectionDtoCopyWith<$Res>(_self.comments, (value) {
    return _then(_self.copyWith(comments: value));
  });
}/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhLabelConnectionDtoCopyWith<$Res> get labels {
  
  return $GhLabelConnectionDtoCopyWith<$Res>(_self.labels, (value) {
    return _then(_self.copyWith(labels: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhPullRequestDto implements GhPullRequestDto {
  const _GhPullRequestDto({required this.title, required this.url, required this.state, @JsonKey(unknownEnumValue: GhMergeableStateDto.unknown) required this.mergeable, required this.headRefOid, required this.commits, required this.reviewRequests, required this.latestReviews, required this.reviewThreads, required this.comments, required this.labels});
  factory _GhPullRequestDto.fromJson(Map<String, dynamic> json) => _$GhPullRequestDtoFromJson(json);

@override final  String title;
@override final  String url;
@override final  GhPullRequestStateDto state;
@override@JsonKey(unknownEnumValue: GhMergeableStateDto.unknown) final  GhMergeableStateDto mergeable;
@override final  String headRefOid;
@override final  GhCommitConnectionDto commits;
@override final  GhReviewRequestConnectionDto reviewRequests;
@override final  GhReviewConnectionDto latestReviews;
@override final  GhReviewThreadConnectionDto reviewThreads;
@override final  GhIssueCommentConnectionDto comments;
@override final  GhLabelConnectionDto labels;

/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhPullRequestDtoCopyWith<_GhPullRequestDto> get copyWith => __$GhPullRequestDtoCopyWithImpl<_GhPullRequestDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhPullRequestDto&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.state, state) || other.state == state)&&(identical(other.mergeable, mergeable) || other.mergeable == mergeable)&&(identical(other.headRefOid, headRefOid) || other.headRefOid == headRefOid)&&(identical(other.commits, commits) || other.commits == commits)&&(identical(other.reviewRequests, reviewRequests) || other.reviewRequests == reviewRequests)&&(identical(other.latestReviews, latestReviews) || other.latestReviews == latestReviews)&&(identical(other.reviewThreads, reviewThreads) || other.reviewThreads == reviewThreads)&&(identical(other.comments, comments) || other.comments == comments)&&(identical(other.labels, labels) || other.labels == labels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,title,url,state,mergeable,headRefOid,commits,reviewRequests,latestReviews,reviewThreads,comments,labels);
}

@override
String toString() {
    return 'GhPullRequestDto(title: $title, url: $url, state: $state, mergeable: $mergeable, headRefOid: $headRefOid, commits: $commits, reviewRequests: $reviewRequests, latestReviews: $latestReviews, reviewThreads: $reviewThreads, comments: $comments, labels: $labels)';
}


}

/// @nodoc
abstract mixin class _$GhPullRequestDtoCopyWith<$Res> implements $GhPullRequestDtoCopyWith<$Res> {
  factory _$GhPullRequestDtoCopyWith(_GhPullRequestDto value, $Res Function(_GhPullRequestDto) _then) = __$GhPullRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String title, String url, GhPullRequestStateDto state,@JsonKey(unknownEnumValue: GhMergeableStateDto.unknown) GhMergeableStateDto mergeable, String headRefOid, GhCommitConnectionDto commits, GhReviewRequestConnectionDto reviewRequests, GhReviewConnectionDto latestReviews, GhReviewThreadConnectionDto reviewThreads, GhIssueCommentConnectionDto comments, GhLabelConnectionDto labels
});


@override $GhCommitConnectionDtoCopyWith<$Res> get commits;@override $GhReviewRequestConnectionDtoCopyWith<$Res> get reviewRequests;@override $GhReviewConnectionDtoCopyWith<$Res> get latestReviews;@override $GhReviewThreadConnectionDtoCopyWith<$Res> get reviewThreads;@override $GhIssueCommentConnectionDtoCopyWith<$Res> get comments;@override $GhLabelConnectionDtoCopyWith<$Res> get labels;

}
/// @nodoc
class __$GhPullRequestDtoCopyWithImpl<$Res>
    implements _$GhPullRequestDtoCopyWith<$Res> {
  __$GhPullRequestDtoCopyWithImpl(this._self, this._then);

  final _GhPullRequestDto _self;
  final $Res Function(_GhPullRequestDto) _then;

/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? url = null,Object? state = null,Object? mergeable = null,Object? headRefOid = null,Object? commits = null,Object? reviewRequests = null,Object? latestReviews = null,Object? reviewThreads = null,Object? comments = null,Object? labels = null,}) {
  return _then(_GhPullRequestDto(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as GhPullRequestStateDto,mergeable: null == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as GhMergeableStateDto,headRefOid: null == headRefOid ? _self.headRefOid : headRefOid // ignore: cast_nullable_to_non_nullable
as String,commits: null == commits ? _self.commits : commits // ignore: cast_nullable_to_non_nullable
as GhCommitConnectionDto,reviewRequests: null == reviewRequests ? _self.reviewRequests : reviewRequests // ignore: cast_nullable_to_non_nullable
as GhReviewRequestConnectionDto,latestReviews: null == latestReviews ? _self.latestReviews : latestReviews // ignore: cast_nullable_to_non_nullable
as GhReviewConnectionDto,reviewThreads: null == reviewThreads ? _self.reviewThreads : reviewThreads // ignore: cast_nullable_to_non_nullable
as GhReviewThreadConnectionDto,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as GhIssueCommentConnectionDto,labels: null == labels ? _self.labels : labels // ignore: cast_nullable_to_non_nullable
as GhLabelConnectionDto,
  ));
}

/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhCommitConnectionDtoCopyWith<$Res> get commits {
  
  return $GhCommitConnectionDtoCopyWith<$Res>(_self.commits, (value) {
    return _then(_self.copyWith(commits: value));
  });
}/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhReviewRequestConnectionDtoCopyWith<$Res> get reviewRequests {
  
  return $GhReviewRequestConnectionDtoCopyWith<$Res>(_self.reviewRequests, (value) {
    return _then(_self.copyWith(reviewRequests: value));
  });
}/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhReviewConnectionDtoCopyWith<$Res> get latestReviews {
  
  return $GhReviewConnectionDtoCopyWith<$Res>(_self.latestReviews, (value) {
    return _then(_self.copyWith(latestReviews: value));
  });
}/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhReviewThreadConnectionDtoCopyWith<$Res> get reviewThreads {
  
  return $GhReviewThreadConnectionDtoCopyWith<$Res>(_self.reviewThreads, (value) {
    return _then(_self.copyWith(reviewThreads: value));
  });
}/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhIssueCommentConnectionDtoCopyWith<$Res> get comments {
  
  return $GhIssueCommentConnectionDtoCopyWith<$Res>(_self.comments, (value) {
    return _then(_self.copyWith(comments: value));
  });
}/// Create a copy of GhPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhLabelConnectionDtoCopyWith<$Res> get labels {
  
  return $GhLabelConnectionDtoCopyWith<$Res>(_self.labels, (value) {
    return _then(_self.copyWith(labels: value));
  });
}
}


/// @nodoc
mixin _$GhPageInfoDto {

 bool get hasNextPage; String? get endCursor;
/// Create a copy of GhPageInfoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhPageInfoDtoCopyWith<GhPageInfoDto> get copyWith => _$GhPageInfoDtoCopyWithImpl<GhPageInfoDto>(this as GhPageInfoDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhPageInfoDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhPageInfoDto&&(identical(other.hasNextPage, _this.hasNextPage) || other.hasNextPage == _this.hasNextPage)&&(identical(other.endCursor, _this.endCursor) || other.endCursor == _this.endCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhPageInfoDto;
  return Object.hash(runtimeType,_this.hasNextPage,_this.endCursor);
}

@override
String toString() {
  final _this = this as GhPageInfoDto;
  return 'GhPageInfoDto(hasNextPage: ${_this.hasNextPage}, endCursor: ${_this.endCursor})';
}


}

/// @nodoc
abstract mixin class $GhPageInfoDtoCopyWith<$Res>  {
  factory $GhPageInfoDtoCopyWith(GhPageInfoDto value, $Res Function(GhPageInfoDto) _then) = _$GhPageInfoDtoCopyWithImpl;
@useResult
$Res call({
 bool hasNextPage, String? endCursor
});




}
/// @nodoc
class _$GhPageInfoDtoCopyWithImpl<$Res>
    implements $GhPageInfoDtoCopyWith<$Res> {
  _$GhPageInfoDtoCopyWithImpl(this._self, this._then);

  final GhPageInfoDto _self;
  final $Res Function(GhPageInfoDto) _then;

/// Create a copy of GhPageInfoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hasNextPage = null,Object? endCursor = freezed,}) {
  return _then(GhPageInfoDto(
hasNextPage: null == hasNextPage ? _self.hasNextPage : hasNextPage // ignore: cast_nullable_to_non_nullable
as bool,endCursor: freezed == endCursor ? _self.endCursor : endCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhPageInfoDto implements GhPageInfoDto {
  const _GhPageInfoDto({required this.hasNextPage, required this.endCursor});
  factory _GhPageInfoDto.fromJson(Map<String, dynamic> json) => _$GhPageInfoDtoFromJson(json);

@override final  bool hasNextPage;
@override final  String? endCursor;

/// Create a copy of GhPageInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhPageInfoDtoCopyWith<_GhPageInfoDto> get copyWith => __$GhPageInfoDtoCopyWithImpl<_GhPageInfoDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhPageInfoDto&&(identical(other.hasNextPage, hasNextPage) || other.hasNextPage == hasNextPage)&&(identical(other.endCursor, endCursor) || other.endCursor == endCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,hasNextPage,endCursor);
}

@override
String toString() {
    return 'GhPageInfoDto(hasNextPage: $hasNextPage, endCursor: $endCursor)';
}


}

/// @nodoc
abstract mixin class _$GhPageInfoDtoCopyWith<$Res> implements $GhPageInfoDtoCopyWith<$Res> {
  factory _$GhPageInfoDtoCopyWith(_GhPageInfoDto value, $Res Function(_GhPageInfoDto) _then) = __$GhPageInfoDtoCopyWithImpl;
@override @useResult
$Res call({
 bool hasNextPage, String? endCursor
});




}
/// @nodoc
class __$GhPageInfoDtoCopyWithImpl<$Res>
    implements _$GhPageInfoDtoCopyWith<$Res> {
  __$GhPageInfoDtoCopyWithImpl(this._self, this._then);

  final _GhPageInfoDto _self;
  final $Res Function(_GhPageInfoDto) _then;

/// Create a copy of GhPageInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hasNextPage = null,Object? endCursor = freezed,}) {
  return _then(_GhPageInfoDto(
hasNextPage: null == hasNextPage ? _self.hasNextPage : hasNextPage // ignore: cast_nullable_to_non_nullable
as bool,endCursor: freezed == endCursor ? _self.endCursor : endCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$GhCommitConnectionDto {

 List<GhCommitNodeDto> get nodes;
/// Create a copy of GhCommitConnectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhCommitConnectionDtoCopyWith<GhCommitConnectionDto> get copyWith => _$GhCommitConnectionDtoCopyWithImpl<GhCommitConnectionDto>(this as GhCommitConnectionDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhCommitConnectionDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhCommitConnectionDto&&const DeepCollectionEquality().equals(other.nodes, _this.nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhCommitConnectionDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.nodes));
}

@override
String toString() {
  final _this = this as GhCommitConnectionDto;
  return 'GhCommitConnectionDto(nodes: ${_this.nodes})';
}


}

/// @nodoc
abstract mixin class $GhCommitConnectionDtoCopyWith<$Res>  {
  factory $GhCommitConnectionDtoCopyWith(GhCommitConnectionDto value, $Res Function(GhCommitConnectionDto) _then) = _$GhCommitConnectionDtoCopyWithImpl;
@useResult
$Res call({
 List<GhCommitNodeDto> nodes
});




}
/// @nodoc
class _$GhCommitConnectionDtoCopyWithImpl<$Res>
    implements $GhCommitConnectionDtoCopyWith<$Res> {
  _$GhCommitConnectionDtoCopyWithImpl(this._self, this._then);

  final GhCommitConnectionDto _self;
  final $Res Function(GhCommitConnectionDto) _then;

/// Create a copy of GhCommitConnectionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nodes = null,}) {
  return _then(GhCommitConnectionDto(
nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhCommitNodeDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhCommitConnectionDto implements GhCommitConnectionDto {
  const _GhCommitConnectionDto({required  List<GhCommitNodeDto> nodes}): _nodes = nodes;
  factory _GhCommitConnectionDto.fromJson(Map<String, dynamic> json) => _$GhCommitConnectionDtoFromJson(json);

 final  List<GhCommitNodeDto> _nodes;
@override List<GhCommitNodeDto> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}


/// Create a copy of GhCommitConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhCommitConnectionDtoCopyWith<_GhCommitConnectionDto> get copyWith => __$GhCommitConnectionDtoCopyWithImpl<_GhCommitConnectionDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhCommitConnectionDto&&const DeepCollectionEquality().equals(other.nodes, _nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_nodes));
}

@override
String toString() {
    return 'GhCommitConnectionDto(nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class _$GhCommitConnectionDtoCopyWith<$Res> implements $GhCommitConnectionDtoCopyWith<$Res> {
  factory _$GhCommitConnectionDtoCopyWith(_GhCommitConnectionDto value, $Res Function(_GhCommitConnectionDto) _then) = __$GhCommitConnectionDtoCopyWithImpl;
@override @useResult
$Res call({
 List<GhCommitNodeDto> nodes
});




}
/// @nodoc
class __$GhCommitConnectionDtoCopyWithImpl<$Res>
    implements _$GhCommitConnectionDtoCopyWith<$Res> {
  __$GhCommitConnectionDtoCopyWithImpl(this._self, this._then);

  final _GhCommitConnectionDto _self;
  final $Res Function(_GhCommitConnectionDto) _then;

/// Create a copy of GhCommitConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nodes = null,}) {
  return _then(_GhCommitConnectionDto(
nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhCommitNodeDto>,
  ));
}


}


/// @nodoc
mixin _$GhCommitNodeDto {

 GhCommitDto get commit;
/// Create a copy of GhCommitNodeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhCommitNodeDtoCopyWith<GhCommitNodeDto> get copyWith => _$GhCommitNodeDtoCopyWithImpl<GhCommitNodeDto>(this as GhCommitNodeDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhCommitNodeDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhCommitNodeDto&&(identical(other.commit, _this.commit) || other.commit == _this.commit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhCommitNodeDto;
  return Object.hash(runtimeType,_this.commit);
}

@override
String toString() {
  final _this = this as GhCommitNodeDto;
  return 'GhCommitNodeDto(commit: ${_this.commit})';
}


}

/// @nodoc
abstract mixin class $GhCommitNodeDtoCopyWith<$Res>  {
  factory $GhCommitNodeDtoCopyWith(GhCommitNodeDto value, $Res Function(GhCommitNodeDto) _then) = _$GhCommitNodeDtoCopyWithImpl;
@useResult
$Res call({
 GhCommitDto commit
});


$GhCommitDtoCopyWith<$Res> get commit;

}
/// @nodoc
class _$GhCommitNodeDtoCopyWithImpl<$Res>
    implements $GhCommitNodeDtoCopyWith<$Res> {
  _$GhCommitNodeDtoCopyWithImpl(this._self, this._then);

  final GhCommitNodeDto _self;
  final $Res Function(GhCommitNodeDto) _then;

/// Create a copy of GhCommitNodeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? commit = null,}) {
  return _then(GhCommitNodeDto(
commit: null == commit ? _self.commit : commit // ignore: cast_nullable_to_non_nullable
as GhCommitDto,
  ));
}
/// Create a copy of GhCommitNodeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhCommitDtoCopyWith<$Res> get commit {
  
  return $GhCommitDtoCopyWith<$Res>(_self.commit, (value) {
    return _then(_self.copyWith(commit: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhCommitNodeDto implements GhCommitNodeDto {
  const _GhCommitNodeDto({required this.commit});
  factory _GhCommitNodeDto.fromJson(Map<String, dynamic> json) => _$GhCommitNodeDtoFromJson(json);

@override final  GhCommitDto commit;

/// Create a copy of GhCommitNodeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhCommitNodeDtoCopyWith<_GhCommitNodeDto> get copyWith => __$GhCommitNodeDtoCopyWithImpl<_GhCommitNodeDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhCommitNodeDto&&(identical(other.commit, commit) || other.commit == commit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,commit);
}

@override
String toString() {
    return 'GhCommitNodeDto(commit: $commit)';
}


}

/// @nodoc
abstract mixin class _$GhCommitNodeDtoCopyWith<$Res> implements $GhCommitNodeDtoCopyWith<$Res> {
  factory _$GhCommitNodeDtoCopyWith(_GhCommitNodeDto value, $Res Function(_GhCommitNodeDto) _then) = __$GhCommitNodeDtoCopyWithImpl;
@override @useResult
$Res call({
 GhCommitDto commit
});


@override $GhCommitDtoCopyWith<$Res> get commit;

}
/// @nodoc
class __$GhCommitNodeDtoCopyWithImpl<$Res>
    implements _$GhCommitNodeDtoCopyWith<$Res> {
  __$GhCommitNodeDtoCopyWithImpl(this._self, this._then);

  final _GhCommitNodeDto _self;
  final $Res Function(_GhCommitNodeDto) _then;

/// Create a copy of GhCommitNodeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? commit = null,}) {
  return _then(_GhCommitNodeDto(
commit: null == commit ? _self.commit : commit // ignore: cast_nullable_to_non_nullable
as GhCommitDto,
  ));
}

/// Create a copy of GhCommitNodeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhCommitDtoCopyWith<$Res> get commit {
  
  return $GhCommitDtoCopyWith<$Res>(_self.commit, (value) {
    return _then(_self.copyWith(commit: value));
  });
}
}


/// @nodoc
mixin _$GhCommitDto {

 GhStatusCheckRollupDto? get statusCheckRollup;
/// Create a copy of GhCommitDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhCommitDtoCopyWith<GhCommitDto> get copyWith => _$GhCommitDtoCopyWithImpl<GhCommitDto>(this as GhCommitDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhCommitDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhCommitDto&&(identical(other.statusCheckRollup, _this.statusCheckRollup) || other.statusCheckRollup == _this.statusCheckRollup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhCommitDto;
  return Object.hash(runtimeType,_this.statusCheckRollup);
}

@override
String toString() {
  final _this = this as GhCommitDto;
  return 'GhCommitDto(statusCheckRollup: ${_this.statusCheckRollup})';
}


}

/// @nodoc
abstract mixin class $GhCommitDtoCopyWith<$Res>  {
  factory $GhCommitDtoCopyWith(GhCommitDto value, $Res Function(GhCommitDto) _then) = _$GhCommitDtoCopyWithImpl;
@useResult
$Res call({
 GhStatusCheckRollupDto? statusCheckRollup
});


$GhStatusCheckRollupDtoCopyWith<$Res>? get statusCheckRollup;

}
/// @nodoc
class _$GhCommitDtoCopyWithImpl<$Res>
    implements $GhCommitDtoCopyWith<$Res> {
  _$GhCommitDtoCopyWithImpl(this._self, this._then);

  final GhCommitDto _self;
  final $Res Function(GhCommitDto) _then;

/// Create a copy of GhCommitDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? statusCheckRollup = freezed,}) {
  return _then(GhCommitDto(
statusCheckRollup: freezed == statusCheckRollup ? _self.statusCheckRollup : statusCheckRollup // ignore: cast_nullable_to_non_nullable
as GhStatusCheckRollupDto?,
  ));
}
/// Create a copy of GhCommitDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhStatusCheckRollupDtoCopyWith<$Res>? get statusCheckRollup {
    if (_self.statusCheckRollup == null) {
    return null;
  }

  return $GhStatusCheckRollupDtoCopyWith<$Res>(_self.statusCheckRollup!, (value) {
    return _then(_self.copyWith(statusCheckRollup: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhCommitDto implements GhCommitDto {
  const _GhCommitDto({required this.statusCheckRollup});
  factory _GhCommitDto.fromJson(Map<String, dynamic> json) => _$GhCommitDtoFromJson(json);

@override final  GhStatusCheckRollupDto? statusCheckRollup;

/// Create a copy of GhCommitDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhCommitDtoCopyWith<_GhCommitDto> get copyWith => __$GhCommitDtoCopyWithImpl<_GhCommitDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhCommitDto&&(identical(other.statusCheckRollup, statusCheckRollup) || other.statusCheckRollup == statusCheckRollup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,statusCheckRollup);
}

@override
String toString() {
    return 'GhCommitDto(statusCheckRollup: $statusCheckRollup)';
}


}

/// @nodoc
abstract mixin class _$GhCommitDtoCopyWith<$Res> implements $GhCommitDtoCopyWith<$Res> {
  factory _$GhCommitDtoCopyWith(_GhCommitDto value, $Res Function(_GhCommitDto) _then) = __$GhCommitDtoCopyWithImpl;
@override @useResult
$Res call({
 GhStatusCheckRollupDto? statusCheckRollup
});


@override $GhStatusCheckRollupDtoCopyWith<$Res>? get statusCheckRollup;

}
/// @nodoc
class __$GhCommitDtoCopyWithImpl<$Res>
    implements _$GhCommitDtoCopyWith<$Res> {
  __$GhCommitDtoCopyWithImpl(this._self, this._then);

  final _GhCommitDto _self;
  final $Res Function(_GhCommitDto) _then;

/// Create a copy of GhCommitDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? statusCheckRollup = freezed,}) {
  return _then(_GhCommitDto(
statusCheckRollup: freezed == statusCheckRollup ? _self.statusCheckRollup : statusCheckRollup // ignore: cast_nullable_to_non_nullable
as GhStatusCheckRollupDto?,
  ));
}

/// Create a copy of GhCommitDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhStatusCheckRollupDtoCopyWith<$Res>? get statusCheckRollup {
    if (_self.statusCheckRollup == null) {
    return null;
  }

  return $GhStatusCheckRollupDtoCopyWith<$Res>(_self.statusCheckRollup!, (value) {
    return _then(_self.copyWith(statusCheckRollup: value));
  });
}
}


/// @nodoc
mixin _$GhStatusCheckRollupDto {

 GhCheckContextConnectionDto get contexts;
/// Create a copy of GhStatusCheckRollupDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhStatusCheckRollupDtoCopyWith<GhStatusCheckRollupDto> get copyWith => _$GhStatusCheckRollupDtoCopyWithImpl<GhStatusCheckRollupDto>(this as GhStatusCheckRollupDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhStatusCheckRollupDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhStatusCheckRollupDto&&(identical(other.contexts, _this.contexts) || other.contexts == _this.contexts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhStatusCheckRollupDto;
  return Object.hash(runtimeType,_this.contexts);
}

@override
String toString() {
  final _this = this as GhStatusCheckRollupDto;
  return 'GhStatusCheckRollupDto(contexts: ${_this.contexts})';
}


}

/// @nodoc
abstract mixin class $GhStatusCheckRollupDtoCopyWith<$Res>  {
  factory $GhStatusCheckRollupDtoCopyWith(GhStatusCheckRollupDto value, $Res Function(GhStatusCheckRollupDto) _then) = _$GhStatusCheckRollupDtoCopyWithImpl;
@useResult
$Res call({
 GhCheckContextConnectionDto contexts
});


$GhCheckContextConnectionDtoCopyWith<$Res> get contexts;

}
/// @nodoc
class _$GhStatusCheckRollupDtoCopyWithImpl<$Res>
    implements $GhStatusCheckRollupDtoCopyWith<$Res> {
  _$GhStatusCheckRollupDtoCopyWithImpl(this._self, this._then);

  final GhStatusCheckRollupDto _self;
  final $Res Function(GhStatusCheckRollupDto) _then;

/// Create a copy of GhStatusCheckRollupDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? contexts = null,}) {
  return _then(GhStatusCheckRollupDto(
contexts: null == contexts ? _self.contexts : contexts // ignore: cast_nullable_to_non_nullable
as GhCheckContextConnectionDto,
  ));
}
/// Create a copy of GhStatusCheckRollupDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhCheckContextConnectionDtoCopyWith<$Res> get contexts {
  
  return $GhCheckContextConnectionDtoCopyWith<$Res>(_self.contexts, (value) {
    return _then(_self.copyWith(contexts: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhStatusCheckRollupDto implements GhStatusCheckRollupDto {
  const _GhStatusCheckRollupDto({required this.contexts});
  factory _GhStatusCheckRollupDto.fromJson(Map<String, dynamic> json) => _$GhStatusCheckRollupDtoFromJson(json);

@override final  GhCheckContextConnectionDto contexts;

/// Create a copy of GhStatusCheckRollupDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhStatusCheckRollupDtoCopyWith<_GhStatusCheckRollupDto> get copyWith => __$GhStatusCheckRollupDtoCopyWithImpl<_GhStatusCheckRollupDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhStatusCheckRollupDto&&(identical(other.contexts, contexts) || other.contexts == contexts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,contexts);
}

@override
String toString() {
    return 'GhStatusCheckRollupDto(contexts: $contexts)';
}


}

/// @nodoc
abstract mixin class _$GhStatusCheckRollupDtoCopyWith<$Res> implements $GhStatusCheckRollupDtoCopyWith<$Res> {
  factory _$GhStatusCheckRollupDtoCopyWith(_GhStatusCheckRollupDto value, $Res Function(_GhStatusCheckRollupDto) _then) = __$GhStatusCheckRollupDtoCopyWithImpl;
@override @useResult
$Res call({
 GhCheckContextConnectionDto contexts
});


@override $GhCheckContextConnectionDtoCopyWith<$Res> get contexts;

}
/// @nodoc
class __$GhStatusCheckRollupDtoCopyWithImpl<$Res>
    implements _$GhStatusCheckRollupDtoCopyWith<$Res> {
  __$GhStatusCheckRollupDtoCopyWithImpl(this._self, this._then);

  final _GhStatusCheckRollupDto _self;
  final $Res Function(_GhStatusCheckRollupDto) _then;

/// Create a copy of GhStatusCheckRollupDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? contexts = null,}) {
  return _then(_GhStatusCheckRollupDto(
contexts: null == contexts ? _self.contexts : contexts // ignore: cast_nullable_to_non_nullable
as GhCheckContextConnectionDto,
  ));
}

/// Create a copy of GhStatusCheckRollupDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhCheckContextConnectionDtoCopyWith<$Res> get contexts {
  
  return $GhCheckContextConnectionDtoCopyWith<$Res>(_self.contexts, (value) {
    return _then(_self.copyWith(contexts: value));
  });
}
}


/// @nodoc
mixin _$GhCheckContextConnectionDto {

 GhPageInfoDto get pageInfo; List<GhCheckContextDto> get nodes;
/// Create a copy of GhCheckContextConnectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhCheckContextConnectionDtoCopyWith<GhCheckContextConnectionDto> get copyWith => _$GhCheckContextConnectionDtoCopyWithImpl<GhCheckContextConnectionDto>(this as GhCheckContextConnectionDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhCheckContextConnectionDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhCheckContextConnectionDto&&(identical(other.pageInfo, _this.pageInfo) || other.pageInfo == _this.pageInfo)&&const DeepCollectionEquality().equals(other.nodes, _this.nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhCheckContextConnectionDto;
  return Object.hash(runtimeType,_this.pageInfo,const DeepCollectionEquality().hash(_this.nodes));
}

@override
String toString() {
  final _this = this as GhCheckContextConnectionDto;
  return 'GhCheckContextConnectionDto(pageInfo: ${_this.pageInfo}, nodes: ${_this.nodes})';
}


}

/// @nodoc
abstract mixin class $GhCheckContextConnectionDtoCopyWith<$Res>  {
  factory $GhCheckContextConnectionDtoCopyWith(GhCheckContextConnectionDto value, $Res Function(GhCheckContextConnectionDto) _then) = _$GhCheckContextConnectionDtoCopyWithImpl;
@useResult
$Res call({
 GhPageInfoDto pageInfo, List<GhCheckContextDto> nodes
});


$GhPageInfoDtoCopyWith<$Res> get pageInfo;

}
/// @nodoc
class _$GhCheckContextConnectionDtoCopyWithImpl<$Res>
    implements $GhCheckContextConnectionDtoCopyWith<$Res> {
  _$GhCheckContextConnectionDtoCopyWithImpl(this._self, this._then);

  final GhCheckContextConnectionDto _self;
  final $Res Function(GhCheckContextConnectionDto) _then;

/// Create a copy of GhCheckContextConnectionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pageInfo = null,Object? nodes = null,}) {
  return _then(GhCheckContextConnectionDto(
pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as GhPageInfoDto,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhCheckContextDto>,
  ));
}
/// Create a copy of GhCheckContextConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPageInfoDtoCopyWith<$Res> get pageInfo {
  
  return $GhPageInfoDtoCopyWith<$Res>(_self.pageInfo, (value) {
    return _then(_self.copyWith(pageInfo: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhCheckContextConnectionDto implements GhCheckContextConnectionDto {
  const _GhCheckContextConnectionDto({required this.pageInfo, required  List<GhCheckContextDto> nodes}): _nodes = nodes;
  factory _GhCheckContextConnectionDto.fromJson(Map<String, dynamic> json) => _$GhCheckContextConnectionDtoFromJson(json);

@override final  GhPageInfoDto pageInfo;
 final  List<GhCheckContextDto> _nodes;
@override List<GhCheckContextDto> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}


/// Create a copy of GhCheckContextConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhCheckContextConnectionDtoCopyWith<_GhCheckContextConnectionDto> get copyWith => __$GhCheckContextConnectionDtoCopyWithImpl<_GhCheckContextConnectionDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhCheckContextConnectionDto&&(identical(other.pageInfo, pageInfo) || other.pageInfo == pageInfo)&&const DeepCollectionEquality().equals(other.nodes, _nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,pageInfo,const DeepCollectionEquality().hash(_nodes));
}

@override
String toString() {
    return 'GhCheckContextConnectionDto(pageInfo: $pageInfo, nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class _$GhCheckContextConnectionDtoCopyWith<$Res> implements $GhCheckContextConnectionDtoCopyWith<$Res> {
  factory _$GhCheckContextConnectionDtoCopyWith(_GhCheckContextConnectionDto value, $Res Function(_GhCheckContextConnectionDto) _then) = __$GhCheckContextConnectionDtoCopyWithImpl;
@override @useResult
$Res call({
 GhPageInfoDto pageInfo, List<GhCheckContextDto> nodes
});


@override $GhPageInfoDtoCopyWith<$Res> get pageInfo;

}
/// @nodoc
class __$GhCheckContextConnectionDtoCopyWithImpl<$Res>
    implements _$GhCheckContextConnectionDtoCopyWith<$Res> {
  __$GhCheckContextConnectionDtoCopyWithImpl(this._self, this._then);

  final _GhCheckContextConnectionDto _self;
  final $Res Function(_GhCheckContextConnectionDto) _then;

/// Create a copy of GhCheckContextConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pageInfo = null,Object? nodes = null,}) {
  return _then(_GhCheckContextConnectionDto(
pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as GhPageInfoDto,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhCheckContextDto>,
  ));
}

/// Create a copy of GhCheckContextConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPageInfoDtoCopyWith<$Res> get pageInfo {
  
  return $GhPageInfoDtoCopyWith<$Res>(_self.pageInfo, (value) {
    return _then(_self.copyWith(pageInfo: value));
  });
}
}

GhCheckContextDto _$GhCheckContextDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['__typename']) {
                  case 'CheckRun':
          return GhCheckRunDto.fromJson(
            json
          );
                case 'StatusContext':
          return GhStatusContextDto.fromJson(
            json
          );
        
          default:
            return GhUnknownCheckContextDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$GhCheckContextDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GhCheckContextDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GhCheckContextDto()';
}


}

/// @nodoc
class $GhCheckContextDtoCopyWith<$Res>  {
$GhCheckContextDtoCopyWith(GhCheckContextDto _, $Res Function(GhCheckContextDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class GhCheckRunDto implements GhCheckContextDto {
  const GhCheckRunDto({required this.id, required this.name, @JsonKey(unknownEnumValue: GhCheckStatusDto.unknown) required this.status, @JsonKey(unknownEnumValue: GhCheckConclusionDto.unknown) required this.conclusion,  String? $type}): $type = $type ?? 'CheckRun';
  factory GhCheckRunDto.fromJson(Map<String, dynamic> json) => _$GhCheckRunDtoFromJson(json);

 final  String id;
 final  String name;
@JsonKey(unknownEnumValue: GhCheckStatusDto.unknown) final  GhCheckStatusDto status;
@JsonKey(unknownEnumValue: GhCheckConclusionDto.unknown) final  GhCheckConclusionDto? conclusion;

@JsonKey(name: '__typename')
final String $type;


/// Create a copy of GhCheckContextDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhCheckRunDtoCopyWith<GhCheckRunDto> get copyWith => _$GhCheckRunDtoCopyWithImpl<GhCheckRunDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GhCheckRunDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.conclusion, conclusion) || other.conclusion == conclusion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,status,conclusion);
}

@override
String toString() {
    return 'GhCheckContextDto.checkRun(id: $id, name: $name, status: $status, conclusion: $conclusion)';
}


}

/// @nodoc
abstract mixin class $GhCheckRunDtoCopyWith<$Res> implements $GhCheckContextDtoCopyWith<$Res> {
  factory $GhCheckRunDtoCopyWith(GhCheckRunDto value, $Res Function(GhCheckRunDto) _then) = _$GhCheckRunDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(unknownEnumValue: GhCheckStatusDto.unknown) GhCheckStatusDto status,@JsonKey(unknownEnumValue: GhCheckConclusionDto.unknown) GhCheckConclusionDto? conclusion
});




}
/// @nodoc
class _$GhCheckRunDtoCopyWithImpl<$Res>
    implements $GhCheckRunDtoCopyWith<$Res> {
  _$GhCheckRunDtoCopyWithImpl(this._self, this._then);

  final GhCheckRunDto _self;
  final $Res Function(GhCheckRunDto) _then;

/// Create a copy of GhCheckContextDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? status = null,Object? conclusion = freezed,}) {
  return _then(GhCheckRunDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GhCheckStatusDto,conclusion: freezed == conclusion ? _self.conclusion : conclusion // ignore: cast_nullable_to_non_nullable
as GhCheckConclusionDto?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GhStatusContextDto implements GhCheckContextDto {
  const GhStatusContextDto({required this.context, @JsonKey(unknownEnumValue: GhStatusStateDto.unknown) required this.state, required this.createdAt,  String? $type}): $type = $type ?? 'StatusContext';
  factory GhStatusContextDto.fromJson(Map<String, dynamic> json) => _$GhStatusContextDtoFromJson(json);

 final  String context;
@JsonKey(unknownEnumValue: GhStatusStateDto.unknown) final  GhStatusStateDto state;
 final  DateTime createdAt;

@JsonKey(name: '__typename')
final String $type;


/// Create a copy of GhCheckContextDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhStatusContextDtoCopyWith<GhStatusContextDto> get copyWith => _$GhStatusContextDtoCopyWithImpl<GhStatusContextDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GhStatusContextDto&&(identical(other.context, context) || other.context == context)&&(identical(other.state, state) || other.state == state)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,context,state,createdAt);
}

@override
String toString() {
    return 'GhCheckContextDto.statusContext(context: $context, state: $state, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $GhStatusContextDtoCopyWith<$Res> implements $GhCheckContextDtoCopyWith<$Res> {
  factory $GhStatusContextDtoCopyWith(GhStatusContextDto value, $Res Function(GhStatusContextDto) _then) = _$GhStatusContextDtoCopyWithImpl;
@useResult
$Res call({
 String context,@JsonKey(unknownEnumValue: GhStatusStateDto.unknown) GhStatusStateDto state, DateTime createdAt
});




}
/// @nodoc
class _$GhStatusContextDtoCopyWithImpl<$Res>
    implements $GhStatusContextDtoCopyWith<$Res> {
  _$GhStatusContextDtoCopyWithImpl(this._self, this._then);

  final GhStatusContextDto _self;
  final $Res Function(GhStatusContextDto) _then;

/// Create a copy of GhCheckContextDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? context = null,Object? state = null,Object? createdAt = null,}) {
  return _then(GhStatusContextDto(
context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as GhStatusStateDto,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GhUnknownCheckContextDto implements GhCheckContextDto {
  const GhUnknownCheckContextDto({ String? $type}): $type = $type ?? 'unknown';
  factory GhUnknownCheckContextDto.fromJson(Map<String, dynamic> json) => _$GhUnknownCheckContextDtoFromJson(json);



@JsonKey(name: '__typename')
final String $type;





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GhUnknownCheckContextDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GhCheckContextDto.unknown()';
}


}





/// @nodoc
mixin _$GhReviewRequestConnectionDto {

 List<GhReviewRequestDto> get nodes;
/// Create a copy of GhReviewRequestConnectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhReviewRequestConnectionDtoCopyWith<GhReviewRequestConnectionDto> get copyWith => _$GhReviewRequestConnectionDtoCopyWithImpl<GhReviewRequestConnectionDto>(this as GhReviewRequestConnectionDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhReviewRequestConnectionDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhReviewRequestConnectionDto&&const DeepCollectionEquality().equals(other.nodes, _this.nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhReviewRequestConnectionDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.nodes));
}

@override
String toString() {
  final _this = this as GhReviewRequestConnectionDto;
  return 'GhReviewRequestConnectionDto(nodes: ${_this.nodes})';
}


}

/// @nodoc
abstract mixin class $GhReviewRequestConnectionDtoCopyWith<$Res>  {
  factory $GhReviewRequestConnectionDtoCopyWith(GhReviewRequestConnectionDto value, $Res Function(GhReviewRequestConnectionDto) _then) = _$GhReviewRequestConnectionDtoCopyWithImpl;
@useResult
$Res call({
 List<GhReviewRequestDto> nodes
});




}
/// @nodoc
class _$GhReviewRequestConnectionDtoCopyWithImpl<$Res>
    implements $GhReviewRequestConnectionDtoCopyWith<$Res> {
  _$GhReviewRequestConnectionDtoCopyWithImpl(this._self, this._then);

  final GhReviewRequestConnectionDto _self;
  final $Res Function(GhReviewRequestConnectionDto) _then;

/// Create a copy of GhReviewRequestConnectionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nodes = null,}) {
  return _then(GhReviewRequestConnectionDto(
nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhReviewRequestDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhReviewRequestConnectionDto implements GhReviewRequestConnectionDto {
  const _GhReviewRequestConnectionDto({required  List<GhReviewRequestDto> nodes}): _nodes = nodes;
  factory _GhReviewRequestConnectionDto.fromJson(Map<String, dynamic> json) => _$GhReviewRequestConnectionDtoFromJson(json);

 final  List<GhReviewRequestDto> _nodes;
@override List<GhReviewRequestDto> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}


/// Create a copy of GhReviewRequestConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhReviewRequestConnectionDtoCopyWith<_GhReviewRequestConnectionDto> get copyWith => __$GhReviewRequestConnectionDtoCopyWithImpl<_GhReviewRequestConnectionDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhReviewRequestConnectionDto&&const DeepCollectionEquality().equals(other.nodes, _nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_nodes));
}

@override
String toString() {
    return 'GhReviewRequestConnectionDto(nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class _$GhReviewRequestConnectionDtoCopyWith<$Res> implements $GhReviewRequestConnectionDtoCopyWith<$Res> {
  factory _$GhReviewRequestConnectionDtoCopyWith(_GhReviewRequestConnectionDto value, $Res Function(_GhReviewRequestConnectionDto) _then) = __$GhReviewRequestConnectionDtoCopyWithImpl;
@override @useResult
$Res call({
 List<GhReviewRequestDto> nodes
});




}
/// @nodoc
class __$GhReviewRequestConnectionDtoCopyWithImpl<$Res>
    implements _$GhReviewRequestConnectionDtoCopyWith<$Res> {
  __$GhReviewRequestConnectionDtoCopyWithImpl(this._self, this._then);

  final _GhReviewRequestConnectionDto _self;
  final $Res Function(_GhReviewRequestConnectionDto) _then;

/// Create a copy of GhReviewRequestConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nodes = null,}) {
  return _then(_GhReviewRequestConnectionDto(
nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhReviewRequestDto>,
  ));
}


}


/// @nodoc
mixin _$GhReviewRequestDto {

 GhRequestedReviewerDto? get requestedReviewer;
/// Create a copy of GhReviewRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhReviewRequestDtoCopyWith<GhReviewRequestDto> get copyWith => _$GhReviewRequestDtoCopyWithImpl<GhReviewRequestDto>(this as GhReviewRequestDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhReviewRequestDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhReviewRequestDto&&(identical(other.requestedReviewer, _this.requestedReviewer) || other.requestedReviewer == _this.requestedReviewer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhReviewRequestDto;
  return Object.hash(runtimeType,_this.requestedReviewer);
}

@override
String toString() {
  final _this = this as GhReviewRequestDto;
  return 'GhReviewRequestDto(requestedReviewer: ${_this.requestedReviewer})';
}


}

/// @nodoc
abstract mixin class $GhReviewRequestDtoCopyWith<$Res>  {
  factory $GhReviewRequestDtoCopyWith(GhReviewRequestDto value, $Res Function(GhReviewRequestDto) _then) = _$GhReviewRequestDtoCopyWithImpl;
@useResult
$Res call({
 GhRequestedReviewerDto? requestedReviewer
});


$GhRequestedReviewerDtoCopyWith<$Res>? get requestedReviewer;

}
/// @nodoc
class _$GhReviewRequestDtoCopyWithImpl<$Res>
    implements $GhReviewRequestDtoCopyWith<$Res> {
  _$GhReviewRequestDtoCopyWithImpl(this._self, this._then);

  final GhReviewRequestDto _self;
  final $Res Function(GhReviewRequestDto) _then;

/// Create a copy of GhReviewRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestedReviewer = freezed,}) {
  return _then(GhReviewRequestDto(
requestedReviewer: freezed == requestedReviewer ? _self.requestedReviewer : requestedReviewer // ignore: cast_nullable_to_non_nullable
as GhRequestedReviewerDto?,
  ));
}
/// Create a copy of GhReviewRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhRequestedReviewerDtoCopyWith<$Res>? get requestedReviewer {
    if (_self.requestedReviewer == null) {
    return null;
  }

  return $GhRequestedReviewerDtoCopyWith<$Res>(_self.requestedReviewer!, (value) {
    return _then(_self.copyWith(requestedReviewer: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhReviewRequestDto implements GhReviewRequestDto {
  const _GhReviewRequestDto({required this.requestedReviewer});
  factory _GhReviewRequestDto.fromJson(Map<String, dynamic> json) => _$GhReviewRequestDtoFromJson(json);

@override final  GhRequestedReviewerDto? requestedReviewer;

/// Create a copy of GhReviewRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhReviewRequestDtoCopyWith<_GhReviewRequestDto> get copyWith => __$GhReviewRequestDtoCopyWithImpl<_GhReviewRequestDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhReviewRequestDto&&(identical(other.requestedReviewer, requestedReviewer) || other.requestedReviewer == requestedReviewer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,requestedReviewer);
}

@override
String toString() {
    return 'GhReviewRequestDto(requestedReviewer: $requestedReviewer)';
}


}

/// @nodoc
abstract mixin class _$GhReviewRequestDtoCopyWith<$Res> implements $GhReviewRequestDtoCopyWith<$Res> {
  factory _$GhReviewRequestDtoCopyWith(_GhReviewRequestDto value, $Res Function(_GhReviewRequestDto) _then) = __$GhReviewRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 GhRequestedReviewerDto? requestedReviewer
});


@override $GhRequestedReviewerDtoCopyWith<$Res>? get requestedReviewer;

}
/// @nodoc
class __$GhReviewRequestDtoCopyWithImpl<$Res>
    implements _$GhReviewRequestDtoCopyWith<$Res> {
  __$GhReviewRequestDtoCopyWithImpl(this._self, this._then);

  final _GhReviewRequestDto _self;
  final $Res Function(_GhReviewRequestDto) _then;

/// Create a copy of GhReviewRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestedReviewer = freezed,}) {
  return _then(_GhReviewRequestDto(
requestedReviewer: freezed == requestedReviewer ? _self.requestedReviewer : requestedReviewer // ignore: cast_nullable_to_non_nullable
as GhRequestedReviewerDto?,
  ));
}

/// Create a copy of GhReviewRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhRequestedReviewerDtoCopyWith<$Res>? get requestedReviewer {
    if (_self.requestedReviewer == null) {
    return null;
  }

  return $GhRequestedReviewerDtoCopyWith<$Res>(_self.requestedReviewer!, (value) {
    return _then(_self.copyWith(requestedReviewer: value));
  });
}
}

GhRequestedReviewerDto _$GhRequestedReviewerDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['__typename']) {
                  case 'User':
          return GhRequestedUserDto.fromJson(
            json
          );
                case 'Bot':
          return GhRequestedBotDto.fromJson(
            json
          );
                case 'Team':
          return GhRequestedTeamDto.fromJson(
            json
          );
        
          default:
            return GhUnknownRequestedReviewerDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$GhRequestedReviewerDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GhRequestedReviewerDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GhRequestedReviewerDto()';
}


}

/// @nodoc
class $GhRequestedReviewerDtoCopyWith<$Res>  {
$GhRequestedReviewerDtoCopyWith(GhRequestedReviewerDto _, $Res Function(GhRequestedReviewerDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class GhRequestedUserDto implements GhRequestedReviewerDto {
  const GhRequestedUserDto({required this.login,  String? $type}): $type = $type ?? 'User';
  factory GhRequestedUserDto.fromJson(Map<String, dynamic> json) => _$GhRequestedUserDtoFromJson(json);

 final  String login;

@JsonKey(name: '__typename')
final String $type;


/// Create a copy of GhRequestedReviewerDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhRequestedUserDtoCopyWith<GhRequestedUserDto> get copyWith => _$GhRequestedUserDtoCopyWithImpl<GhRequestedUserDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GhRequestedUserDto&&(identical(other.login, login) || other.login == login));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,login);
}

@override
String toString() {
    return 'GhRequestedReviewerDto.user(login: $login)';
}


}

/// @nodoc
abstract mixin class $GhRequestedUserDtoCopyWith<$Res> implements $GhRequestedReviewerDtoCopyWith<$Res> {
  factory $GhRequestedUserDtoCopyWith(GhRequestedUserDto value, $Res Function(GhRequestedUserDto) _then) = _$GhRequestedUserDtoCopyWithImpl;
@useResult
$Res call({
 String login
});




}
/// @nodoc
class _$GhRequestedUserDtoCopyWithImpl<$Res>
    implements $GhRequestedUserDtoCopyWith<$Res> {
  _$GhRequestedUserDtoCopyWithImpl(this._self, this._then);

  final GhRequestedUserDto _self;
  final $Res Function(GhRequestedUserDto) _then;

/// Create a copy of GhRequestedReviewerDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? login = null,}) {
  return _then(GhRequestedUserDto(
login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GhRequestedBotDto implements GhRequestedReviewerDto {
  const GhRequestedBotDto({required this.login,  String? $type}): $type = $type ?? 'Bot';
  factory GhRequestedBotDto.fromJson(Map<String, dynamic> json) => _$GhRequestedBotDtoFromJson(json);

 final  String login;

@JsonKey(name: '__typename')
final String $type;


/// Create a copy of GhRequestedReviewerDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhRequestedBotDtoCopyWith<GhRequestedBotDto> get copyWith => _$GhRequestedBotDtoCopyWithImpl<GhRequestedBotDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GhRequestedBotDto&&(identical(other.login, login) || other.login == login));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,login);
}

@override
String toString() {
    return 'GhRequestedReviewerDto.bot(login: $login)';
}


}

/// @nodoc
abstract mixin class $GhRequestedBotDtoCopyWith<$Res> implements $GhRequestedReviewerDtoCopyWith<$Res> {
  factory $GhRequestedBotDtoCopyWith(GhRequestedBotDto value, $Res Function(GhRequestedBotDto) _then) = _$GhRequestedBotDtoCopyWithImpl;
@useResult
$Res call({
 String login
});




}
/// @nodoc
class _$GhRequestedBotDtoCopyWithImpl<$Res>
    implements $GhRequestedBotDtoCopyWith<$Res> {
  _$GhRequestedBotDtoCopyWithImpl(this._self, this._then);

  final GhRequestedBotDto _self;
  final $Res Function(GhRequestedBotDto) _then;

/// Create a copy of GhRequestedReviewerDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? login = null,}) {
  return _then(GhRequestedBotDto(
login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GhRequestedTeamDto implements GhRequestedReviewerDto {
  const GhRequestedTeamDto({required this.slug,  String? $type}): $type = $type ?? 'Team';
  factory GhRequestedTeamDto.fromJson(Map<String, dynamic> json) => _$GhRequestedTeamDtoFromJson(json);

 final  String slug;

@JsonKey(name: '__typename')
final String $type;


/// Create a copy of GhRequestedReviewerDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhRequestedTeamDtoCopyWith<GhRequestedTeamDto> get copyWith => _$GhRequestedTeamDtoCopyWithImpl<GhRequestedTeamDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GhRequestedTeamDto&&(identical(other.slug, slug) || other.slug == slug));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,slug);
}

@override
String toString() {
    return 'GhRequestedReviewerDto.team(slug: $slug)';
}


}

/// @nodoc
abstract mixin class $GhRequestedTeamDtoCopyWith<$Res> implements $GhRequestedReviewerDtoCopyWith<$Res> {
  factory $GhRequestedTeamDtoCopyWith(GhRequestedTeamDto value, $Res Function(GhRequestedTeamDto) _then) = _$GhRequestedTeamDtoCopyWithImpl;
@useResult
$Res call({
 String slug
});




}
/// @nodoc
class _$GhRequestedTeamDtoCopyWithImpl<$Res>
    implements $GhRequestedTeamDtoCopyWith<$Res> {
  _$GhRequestedTeamDtoCopyWithImpl(this._self, this._then);

  final GhRequestedTeamDto _self;
  final $Res Function(GhRequestedTeamDto) _then;

/// Create a copy of GhRequestedReviewerDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? slug = null,}) {
  return _then(GhRequestedTeamDto(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GhUnknownRequestedReviewerDto implements GhRequestedReviewerDto {
  const GhUnknownRequestedReviewerDto({ String? $type}): $type = $type ?? 'unknown';
  factory GhUnknownRequestedReviewerDto.fromJson(Map<String, dynamic> json) => _$GhUnknownRequestedReviewerDtoFromJson(json);



@JsonKey(name: '__typename')
final String $type;





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GhUnknownRequestedReviewerDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'GhRequestedReviewerDto.unknown()';
}


}





/// @nodoc
mixin _$GhReviewConnectionDto {

 GhPageInfoDto get pageInfo; List<GhReviewDto> get nodes;
/// Create a copy of GhReviewConnectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhReviewConnectionDtoCopyWith<GhReviewConnectionDto> get copyWith => _$GhReviewConnectionDtoCopyWithImpl<GhReviewConnectionDto>(this as GhReviewConnectionDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhReviewConnectionDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhReviewConnectionDto&&(identical(other.pageInfo, _this.pageInfo) || other.pageInfo == _this.pageInfo)&&const DeepCollectionEquality().equals(other.nodes, _this.nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhReviewConnectionDto;
  return Object.hash(runtimeType,_this.pageInfo,const DeepCollectionEquality().hash(_this.nodes));
}

@override
String toString() {
  final _this = this as GhReviewConnectionDto;
  return 'GhReviewConnectionDto(pageInfo: ${_this.pageInfo}, nodes: ${_this.nodes})';
}


}

/// @nodoc
abstract mixin class $GhReviewConnectionDtoCopyWith<$Res>  {
  factory $GhReviewConnectionDtoCopyWith(GhReviewConnectionDto value, $Res Function(GhReviewConnectionDto) _then) = _$GhReviewConnectionDtoCopyWithImpl;
@useResult
$Res call({
 GhPageInfoDto pageInfo, List<GhReviewDto> nodes
});


$GhPageInfoDtoCopyWith<$Res> get pageInfo;

}
/// @nodoc
class _$GhReviewConnectionDtoCopyWithImpl<$Res>
    implements $GhReviewConnectionDtoCopyWith<$Res> {
  _$GhReviewConnectionDtoCopyWithImpl(this._self, this._then);

  final GhReviewConnectionDto _self;
  final $Res Function(GhReviewConnectionDto) _then;

/// Create a copy of GhReviewConnectionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pageInfo = null,Object? nodes = null,}) {
  return _then(GhReviewConnectionDto(
pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as GhPageInfoDto,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhReviewDto>,
  ));
}
/// Create a copy of GhReviewConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPageInfoDtoCopyWith<$Res> get pageInfo {
  
  return $GhPageInfoDtoCopyWith<$Res>(_self.pageInfo, (value) {
    return _then(_self.copyWith(pageInfo: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhReviewConnectionDto implements GhReviewConnectionDto {
  const _GhReviewConnectionDto({required this.pageInfo, required  List<GhReviewDto> nodes}): _nodes = nodes;
  factory _GhReviewConnectionDto.fromJson(Map<String, dynamic> json) => _$GhReviewConnectionDtoFromJson(json);

@override final  GhPageInfoDto pageInfo;
 final  List<GhReviewDto> _nodes;
@override List<GhReviewDto> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}


/// Create a copy of GhReviewConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhReviewConnectionDtoCopyWith<_GhReviewConnectionDto> get copyWith => __$GhReviewConnectionDtoCopyWithImpl<_GhReviewConnectionDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhReviewConnectionDto&&(identical(other.pageInfo, pageInfo) || other.pageInfo == pageInfo)&&const DeepCollectionEquality().equals(other.nodes, _nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,pageInfo,const DeepCollectionEquality().hash(_nodes));
}

@override
String toString() {
    return 'GhReviewConnectionDto(pageInfo: $pageInfo, nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class _$GhReviewConnectionDtoCopyWith<$Res> implements $GhReviewConnectionDtoCopyWith<$Res> {
  factory _$GhReviewConnectionDtoCopyWith(_GhReviewConnectionDto value, $Res Function(_GhReviewConnectionDto) _then) = __$GhReviewConnectionDtoCopyWithImpl;
@override @useResult
$Res call({
 GhPageInfoDto pageInfo, List<GhReviewDto> nodes
});


@override $GhPageInfoDtoCopyWith<$Res> get pageInfo;

}
/// @nodoc
class __$GhReviewConnectionDtoCopyWithImpl<$Res>
    implements _$GhReviewConnectionDtoCopyWith<$Res> {
  __$GhReviewConnectionDtoCopyWithImpl(this._self, this._then);

  final _GhReviewConnectionDto _self;
  final $Res Function(_GhReviewConnectionDto) _then;

/// Create a copy of GhReviewConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pageInfo = null,Object? nodes = null,}) {
  return _then(_GhReviewConnectionDto(
pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as GhPageInfoDto,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhReviewDto>,
  ));
}

/// Create a copy of GhReviewConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPageInfoDtoCopyWith<$Res> get pageInfo {
  
  return $GhPageInfoDtoCopyWith<$Res>(_self.pageInfo, (value) {
    return _then(_self.copyWith(pageInfo: value));
  });
}
}


/// @nodoc
mixin _$GhReviewDto {

 String get id; GhActorDto? get author;@JsonKey(unknownEnumValue: GhReviewStateDto.unknown) GhReviewStateDto get state; DateTime? get submittedAt; String get body; GhTotalCountDto get comments;
/// Create a copy of GhReviewDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhReviewDtoCopyWith<GhReviewDto> get copyWith => _$GhReviewDtoCopyWithImpl<GhReviewDto>(this as GhReviewDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhReviewDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhReviewDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.submittedAt, _this.submittedAt) || other.submittedAt == _this.submittedAt)&&(identical(other.body, _this.body) || other.body == _this.body)&&(identical(other.comments, _this.comments) || other.comments == _this.comments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhReviewDto;
  return Object.hash(runtimeType,_this.id,_this.author,_this.state,_this.submittedAt,_this.body,_this.comments);
}

@override
String toString() {
  final _this = this as GhReviewDto;
  return 'GhReviewDto(id: ${_this.id}, author: ${_this.author}, state: ${_this.state}, submittedAt: ${_this.submittedAt}, body: ${_this.body}, comments: ${_this.comments})';
}


}

/// @nodoc
abstract mixin class $GhReviewDtoCopyWith<$Res>  {
  factory $GhReviewDtoCopyWith(GhReviewDto value, $Res Function(GhReviewDto) _then) = _$GhReviewDtoCopyWithImpl;
@useResult
$Res call({
 String id, GhActorDto? author,@JsonKey(unknownEnumValue: GhReviewStateDto.unknown) GhReviewStateDto state, DateTime? submittedAt, String body, GhTotalCountDto comments
});


$GhActorDtoCopyWith<$Res>? get author;$GhTotalCountDtoCopyWith<$Res> get comments;

}
/// @nodoc
class _$GhReviewDtoCopyWithImpl<$Res>
    implements $GhReviewDtoCopyWith<$Res> {
  _$GhReviewDtoCopyWithImpl(this._self, this._then);

  final GhReviewDto _self;
  final $Res Function(GhReviewDto) _then;

/// Create a copy of GhReviewDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? author = freezed,Object? state = null,Object? submittedAt = freezed,Object? body = null,Object? comments = null,}) {
  return _then(GhReviewDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as GhActorDto?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as GhReviewStateDto,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as GhTotalCountDto,
  ));
}
/// Create a copy of GhReviewDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhActorDtoCopyWith<$Res>? get author {
    if (_self.author == null) {
    return null;
  }

  return $GhActorDtoCopyWith<$Res>(_self.author!, (value) {
    return _then(_self.copyWith(author: value));
  });
}/// Create a copy of GhReviewDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhTotalCountDtoCopyWith<$Res> get comments {
  
  return $GhTotalCountDtoCopyWith<$Res>(_self.comments, (value) {
    return _then(_self.copyWith(comments: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhReviewDto implements GhReviewDto {
  const _GhReviewDto({required this.id, required this.author, @JsonKey(unknownEnumValue: GhReviewStateDto.unknown) required this.state, required this.submittedAt, required this.body, required this.comments});
  factory _GhReviewDto.fromJson(Map<String, dynamic> json) => _$GhReviewDtoFromJson(json);

@override final  String id;
@override final  GhActorDto? author;
@override@JsonKey(unknownEnumValue: GhReviewStateDto.unknown) final  GhReviewStateDto state;
@override final  DateTime? submittedAt;
@override final  String body;
@override final  GhTotalCountDto comments;

/// Create a copy of GhReviewDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhReviewDtoCopyWith<_GhReviewDto> get copyWith => __$GhReviewDtoCopyWithImpl<_GhReviewDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhReviewDto&&(identical(other.id, id) || other.id == id)&&(identical(other.author, author) || other.author == author)&&(identical(other.state, state) || other.state == state)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.body, body) || other.body == body)&&(identical(other.comments, comments) || other.comments == comments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,author,state,submittedAt,body,comments);
}

@override
String toString() {
    return 'GhReviewDto(id: $id, author: $author, state: $state, submittedAt: $submittedAt, body: $body, comments: $comments)';
}


}

/// @nodoc
abstract mixin class _$GhReviewDtoCopyWith<$Res> implements $GhReviewDtoCopyWith<$Res> {
  factory _$GhReviewDtoCopyWith(_GhReviewDto value, $Res Function(_GhReviewDto) _then) = __$GhReviewDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, GhActorDto? author,@JsonKey(unknownEnumValue: GhReviewStateDto.unknown) GhReviewStateDto state, DateTime? submittedAt, String body, GhTotalCountDto comments
});


@override $GhActorDtoCopyWith<$Res>? get author;@override $GhTotalCountDtoCopyWith<$Res> get comments;

}
/// @nodoc
class __$GhReviewDtoCopyWithImpl<$Res>
    implements _$GhReviewDtoCopyWith<$Res> {
  __$GhReviewDtoCopyWithImpl(this._self, this._then);

  final _GhReviewDto _self;
  final $Res Function(_GhReviewDto) _then;

/// Create a copy of GhReviewDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? author = freezed,Object? state = null,Object? submittedAt = freezed,Object? body = null,Object? comments = null,}) {
  return _then(_GhReviewDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as GhActorDto?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as GhReviewStateDto,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as GhTotalCountDto,
  ));
}

/// Create a copy of GhReviewDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhActorDtoCopyWith<$Res>? get author {
    if (_self.author == null) {
    return null;
  }

  return $GhActorDtoCopyWith<$Res>(_self.author!, (value) {
    return _then(_self.copyWith(author: value));
  });
}/// Create a copy of GhReviewDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhTotalCountDtoCopyWith<$Res> get comments {
  
  return $GhTotalCountDtoCopyWith<$Res>(_self.comments, (value) {
    return _then(_self.copyWith(comments: value));
  });
}
}


/// @nodoc
mixin _$GhReviewThreadConnectionDto {

 GhPageInfoDto get pageInfo; List<GhReviewThreadDto> get nodes;
/// Create a copy of GhReviewThreadConnectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhReviewThreadConnectionDtoCopyWith<GhReviewThreadConnectionDto> get copyWith => _$GhReviewThreadConnectionDtoCopyWithImpl<GhReviewThreadConnectionDto>(this as GhReviewThreadConnectionDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhReviewThreadConnectionDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhReviewThreadConnectionDto&&(identical(other.pageInfo, _this.pageInfo) || other.pageInfo == _this.pageInfo)&&const DeepCollectionEquality().equals(other.nodes, _this.nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhReviewThreadConnectionDto;
  return Object.hash(runtimeType,_this.pageInfo,const DeepCollectionEquality().hash(_this.nodes));
}

@override
String toString() {
  final _this = this as GhReviewThreadConnectionDto;
  return 'GhReviewThreadConnectionDto(pageInfo: ${_this.pageInfo}, nodes: ${_this.nodes})';
}


}

/// @nodoc
abstract mixin class $GhReviewThreadConnectionDtoCopyWith<$Res>  {
  factory $GhReviewThreadConnectionDtoCopyWith(GhReviewThreadConnectionDto value, $Res Function(GhReviewThreadConnectionDto) _then) = _$GhReviewThreadConnectionDtoCopyWithImpl;
@useResult
$Res call({
 GhPageInfoDto pageInfo, List<GhReviewThreadDto> nodes
});


$GhPageInfoDtoCopyWith<$Res> get pageInfo;

}
/// @nodoc
class _$GhReviewThreadConnectionDtoCopyWithImpl<$Res>
    implements $GhReviewThreadConnectionDtoCopyWith<$Res> {
  _$GhReviewThreadConnectionDtoCopyWithImpl(this._self, this._then);

  final GhReviewThreadConnectionDto _self;
  final $Res Function(GhReviewThreadConnectionDto) _then;

/// Create a copy of GhReviewThreadConnectionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pageInfo = null,Object? nodes = null,}) {
  return _then(GhReviewThreadConnectionDto(
pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as GhPageInfoDto,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhReviewThreadDto>,
  ));
}
/// Create a copy of GhReviewThreadConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPageInfoDtoCopyWith<$Res> get pageInfo {
  
  return $GhPageInfoDtoCopyWith<$Res>(_self.pageInfo, (value) {
    return _then(_self.copyWith(pageInfo: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhReviewThreadConnectionDto implements GhReviewThreadConnectionDto {
  const _GhReviewThreadConnectionDto({required this.pageInfo, required  List<GhReviewThreadDto> nodes}): _nodes = nodes;
  factory _GhReviewThreadConnectionDto.fromJson(Map<String, dynamic> json) => _$GhReviewThreadConnectionDtoFromJson(json);

@override final  GhPageInfoDto pageInfo;
 final  List<GhReviewThreadDto> _nodes;
@override List<GhReviewThreadDto> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}


/// Create a copy of GhReviewThreadConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhReviewThreadConnectionDtoCopyWith<_GhReviewThreadConnectionDto> get copyWith => __$GhReviewThreadConnectionDtoCopyWithImpl<_GhReviewThreadConnectionDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhReviewThreadConnectionDto&&(identical(other.pageInfo, pageInfo) || other.pageInfo == pageInfo)&&const DeepCollectionEquality().equals(other.nodes, _nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,pageInfo,const DeepCollectionEquality().hash(_nodes));
}

@override
String toString() {
    return 'GhReviewThreadConnectionDto(pageInfo: $pageInfo, nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class _$GhReviewThreadConnectionDtoCopyWith<$Res> implements $GhReviewThreadConnectionDtoCopyWith<$Res> {
  factory _$GhReviewThreadConnectionDtoCopyWith(_GhReviewThreadConnectionDto value, $Res Function(_GhReviewThreadConnectionDto) _then) = __$GhReviewThreadConnectionDtoCopyWithImpl;
@override @useResult
$Res call({
 GhPageInfoDto pageInfo, List<GhReviewThreadDto> nodes
});


@override $GhPageInfoDtoCopyWith<$Res> get pageInfo;

}
/// @nodoc
class __$GhReviewThreadConnectionDtoCopyWithImpl<$Res>
    implements _$GhReviewThreadConnectionDtoCopyWith<$Res> {
  __$GhReviewThreadConnectionDtoCopyWithImpl(this._self, this._then);

  final _GhReviewThreadConnectionDto _self;
  final $Res Function(_GhReviewThreadConnectionDto) _then;

/// Create a copy of GhReviewThreadConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pageInfo = null,Object? nodes = null,}) {
  return _then(_GhReviewThreadConnectionDto(
pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as GhPageInfoDto,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhReviewThreadDto>,
  ));
}

/// Create a copy of GhReviewThreadConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPageInfoDtoCopyWith<$Res> get pageInfo {
  
  return $GhPageInfoDtoCopyWith<$Res>(_self.pageInfo, (value) {
    return _then(_self.copyWith(pageInfo: value));
  });
}
}


/// @nodoc
mixin _$GhReviewThreadDto {

 String get id; bool get isResolved; String? get path; int? get line; int? get originalLine; GhThreadCommentConnectionDto get comments;
/// Create a copy of GhReviewThreadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhReviewThreadDtoCopyWith<GhReviewThreadDto> get copyWith => _$GhReviewThreadDtoCopyWithImpl<GhReviewThreadDto>(this as GhReviewThreadDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhReviewThreadDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhReviewThreadDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.isResolved, _this.isResolved) || other.isResolved == _this.isResolved)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.line, _this.line) || other.line == _this.line)&&(identical(other.originalLine, _this.originalLine) || other.originalLine == _this.originalLine)&&(identical(other.comments, _this.comments) || other.comments == _this.comments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhReviewThreadDto;
  return Object.hash(runtimeType,_this.id,_this.isResolved,_this.path,_this.line,_this.originalLine,_this.comments);
}

@override
String toString() {
  final _this = this as GhReviewThreadDto;
  return 'GhReviewThreadDto(id: ${_this.id}, isResolved: ${_this.isResolved}, path: ${_this.path}, line: ${_this.line}, originalLine: ${_this.originalLine}, comments: ${_this.comments})';
}


}

/// @nodoc
abstract mixin class $GhReviewThreadDtoCopyWith<$Res>  {
  factory $GhReviewThreadDtoCopyWith(GhReviewThreadDto value, $Res Function(GhReviewThreadDto) _then) = _$GhReviewThreadDtoCopyWithImpl;
@useResult
$Res call({
 String id, bool isResolved, String? path, int? line, int? originalLine, GhThreadCommentConnectionDto comments
});


$GhThreadCommentConnectionDtoCopyWith<$Res> get comments;

}
/// @nodoc
class _$GhReviewThreadDtoCopyWithImpl<$Res>
    implements $GhReviewThreadDtoCopyWith<$Res> {
  _$GhReviewThreadDtoCopyWithImpl(this._self, this._then);

  final GhReviewThreadDto _self;
  final $Res Function(GhReviewThreadDto) _then;

/// Create a copy of GhReviewThreadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? isResolved = null,Object? path = freezed,Object? line = freezed,Object? originalLine = freezed,Object? comments = null,}) {
  return _then(GhReviewThreadDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,isResolved: null == isResolved ? _self.isResolved : isResolved // ignore: cast_nullable_to_non_nullable
as bool,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,originalLine: freezed == originalLine ? _self.originalLine : originalLine // ignore: cast_nullable_to_non_nullable
as int?,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as GhThreadCommentConnectionDto,
  ));
}
/// Create a copy of GhReviewThreadDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhThreadCommentConnectionDtoCopyWith<$Res> get comments {
  
  return $GhThreadCommentConnectionDtoCopyWith<$Res>(_self.comments, (value) {
    return _then(_self.copyWith(comments: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhReviewThreadDto implements GhReviewThreadDto {
  const _GhReviewThreadDto({required this.id, required this.isResolved, required this.path, required this.line, required this.originalLine, required this.comments});
  factory _GhReviewThreadDto.fromJson(Map<String, dynamic> json) => _$GhReviewThreadDtoFromJson(json);

@override final  String id;
@override final  bool isResolved;
@override final  String? path;
@override final  int? line;
@override final  int? originalLine;
@override final  GhThreadCommentConnectionDto comments;

/// Create a copy of GhReviewThreadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhReviewThreadDtoCopyWith<_GhReviewThreadDto> get copyWith => __$GhReviewThreadDtoCopyWithImpl<_GhReviewThreadDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhReviewThreadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.isResolved, isResolved) || other.isResolved == isResolved)&&(identical(other.path, path) || other.path == path)&&(identical(other.line, line) || other.line == line)&&(identical(other.originalLine, originalLine) || other.originalLine == originalLine)&&(identical(other.comments, comments) || other.comments == comments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,isResolved,path,line,originalLine,comments);
}

@override
String toString() {
    return 'GhReviewThreadDto(id: $id, isResolved: $isResolved, path: $path, line: $line, originalLine: $originalLine, comments: $comments)';
}


}

/// @nodoc
abstract mixin class _$GhReviewThreadDtoCopyWith<$Res> implements $GhReviewThreadDtoCopyWith<$Res> {
  factory _$GhReviewThreadDtoCopyWith(_GhReviewThreadDto value, $Res Function(_GhReviewThreadDto) _then) = __$GhReviewThreadDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, bool isResolved, String? path, int? line, int? originalLine, GhThreadCommentConnectionDto comments
});


@override $GhThreadCommentConnectionDtoCopyWith<$Res> get comments;

}
/// @nodoc
class __$GhReviewThreadDtoCopyWithImpl<$Res>
    implements _$GhReviewThreadDtoCopyWith<$Res> {
  __$GhReviewThreadDtoCopyWithImpl(this._self, this._then);

  final _GhReviewThreadDto _self;
  final $Res Function(_GhReviewThreadDto) _then;

/// Create a copy of GhReviewThreadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? isResolved = null,Object? path = freezed,Object? line = freezed,Object? originalLine = freezed,Object? comments = null,}) {
  return _then(_GhReviewThreadDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,isResolved: null == isResolved ? _self.isResolved : isResolved // ignore: cast_nullable_to_non_nullable
as bool,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,originalLine: freezed == originalLine ? _self.originalLine : originalLine // ignore: cast_nullable_to_non_nullable
as int?,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as GhThreadCommentConnectionDto,
  ));
}

/// Create a copy of GhReviewThreadDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhThreadCommentConnectionDtoCopyWith<$Res> get comments {
  
  return $GhThreadCommentConnectionDtoCopyWith<$Res>(_self.comments, (value) {
    return _then(_self.copyWith(comments: value));
  });
}
}


/// @nodoc
mixin _$GhThreadCommentConnectionDto {

 List<GhCommentDto> get nodes;
/// Create a copy of GhThreadCommentConnectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhThreadCommentConnectionDtoCopyWith<GhThreadCommentConnectionDto> get copyWith => _$GhThreadCommentConnectionDtoCopyWithImpl<GhThreadCommentConnectionDto>(this as GhThreadCommentConnectionDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhThreadCommentConnectionDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhThreadCommentConnectionDto&&const DeepCollectionEquality().equals(other.nodes, _this.nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhThreadCommentConnectionDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.nodes));
}

@override
String toString() {
  final _this = this as GhThreadCommentConnectionDto;
  return 'GhThreadCommentConnectionDto(nodes: ${_this.nodes})';
}


}

/// @nodoc
abstract mixin class $GhThreadCommentConnectionDtoCopyWith<$Res>  {
  factory $GhThreadCommentConnectionDtoCopyWith(GhThreadCommentConnectionDto value, $Res Function(GhThreadCommentConnectionDto) _then) = _$GhThreadCommentConnectionDtoCopyWithImpl;
@useResult
$Res call({
 List<GhCommentDto> nodes
});




}
/// @nodoc
class _$GhThreadCommentConnectionDtoCopyWithImpl<$Res>
    implements $GhThreadCommentConnectionDtoCopyWith<$Res> {
  _$GhThreadCommentConnectionDtoCopyWithImpl(this._self, this._then);

  final GhThreadCommentConnectionDto _self;
  final $Res Function(GhThreadCommentConnectionDto) _then;

/// Create a copy of GhThreadCommentConnectionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nodes = null,}) {
  return _then(GhThreadCommentConnectionDto(
nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhCommentDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhThreadCommentConnectionDto implements GhThreadCommentConnectionDto {
  const _GhThreadCommentConnectionDto({required  List<GhCommentDto> nodes}): _nodes = nodes;
  factory _GhThreadCommentConnectionDto.fromJson(Map<String, dynamic> json) => _$GhThreadCommentConnectionDtoFromJson(json);

 final  List<GhCommentDto> _nodes;
@override List<GhCommentDto> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}


/// Create a copy of GhThreadCommentConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhThreadCommentConnectionDtoCopyWith<_GhThreadCommentConnectionDto> get copyWith => __$GhThreadCommentConnectionDtoCopyWithImpl<_GhThreadCommentConnectionDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhThreadCommentConnectionDto&&const DeepCollectionEquality().equals(other.nodes, _nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_nodes));
}

@override
String toString() {
    return 'GhThreadCommentConnectionDto(nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class _$GhThreadCommentConnectionDtoCopyWith<$Res> implements $GhThreadCommentConnectionDtoCopyWith<$Res> {
  factory _$GhThreadCommentConnectionDtoCopyWith(_GhThreadCommentConnectionDto value, $Res Function(_GhThreadCommentConnectionDto) _then) = __$GhThreadCommentConnectionDtoCopyWithImpl;
@override @useResult
$Res call({
 List<GhCommentDto> nodes
});




}
/// @nodoc
class __$GhThreadCommentConnectionDtoCopyWithImpl<$Res>
    implements _$GhThreadCommentConnectionDtoCopyWith<$Res> {
  __$GhThreadCommentConnectionDtoCopyWithImpl(this._self, this._then);

  final _GhThreadCommentConnectionDto _self;
  final $Res Function(_GhThreadCommentConnectionDto) _then;

/// Create a copy of GhThreadCommentConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nodes = null,}) {
  return _then(_GhThreadCommentConnectionDto(
nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhCommentDto>,
  ));
}


}


/// @nodoc
mixin _$GhIssueCommentConnectionDto {

 int get totalCount; List<GhCommentDto> get nodes;
/// Create a copy of GhIssueCommentConnectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhIssueCommentConnectionDtoCopyWith<GhIssueCommentConnectionDto> get copyWith => _$GhIssueCommentConnectionDtoCopyWithImpl<GhIssueCommentConnectionDto>(this as GhIssueCommentConnectionDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhIssueCommentConnectionDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhIssueCommentConnectionDto&&(identical(other.totalCount, _this.totalCount) || other.totalCount == _this.totalCount)&&const DeepCollectionEquality().equals(other.nodes, _this.nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhIssueCommentConnectionDto;
  return Object.hash(runtimeType,_this.totalCount,const DeepCollectionEquality().hash(_this.nodes));
}

@override
String toString() {
  final _this = this as GhIssueCommentConnectionDto;
  return 'GhIssueCommentConnectionDto(totalCount: ${_this.totalCount}, nodes: ${_this.nodes})';
}


}

/// @nodoc
abstract mixin class $GhIssueCommentConnectionDtoCopyWith<$Res>  {
  factory $GhIssueCommentConnectionDtoCopyWith(GhIssueCommentConnectionDto value, $Res Function(GhIssueCommentConnectionDto) _then) = _$GhIssueCommentConnectionDtoCopyWithImpl;
@useResult
$Res call({
 int totalCount, List<GhCommentDto> nodes
});




}
/// @nodoc
class _$GhIssueCommentConnectionDtoCopyWithImpl<$Res>
    implements $GhIssueCommentConnectionDtoCopyWith<$Res> {
  _$GhIssueCommentConnectionDtoCopyWithImpl(this._self, this._then);

  final GhIssueCommentConnectionDto _self;
  final $Res Function(GhIssueCommentConnectionDto) _then;

/// Create a copy of GhIssueCommentConnectionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalCount = null,Object? nodes = null,}) {
  return _then(GhIssueCommentConnectionDto(
totalCount: null == totalCount ? _self.totalCount : totalCount // ignore: cast_nullable_to_non_nullable
as int,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhCommentDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhIssueCommentConnectionDto implements GhIssueCommentConnectionDto {
  const _GhIssueCommentConnectionDto({required this.totalCount, required  List<GhCommentDto> nodes}): _nodes = nodes;
  factory _GhIssueCommentConnectionDto.fromJson(Map<String, dynamic> json) => _$GhIssueCommentConnectionDtoFromJson(json);

@override final  int totalCount;
 final  List<GhCommentDto> _nodes;
@override List<GhCommentDto> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}


/// Create a copy of GhIssueCommentConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhIssueCommentConnectionDtoCopyWith<_GhIssueCommentConnectionDto> get copyWith => __$GhIssueCommentConnectionDtoCopyWithImpl<_GhIssueCommentConnectionDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhIssueCommentConnectionDto&&(identical(other.totalCount, totalCount) || other.totalCount == totalCount)&&const DeepCollectionEquality().equals(other.nodes, _nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,totalCount,const DeepCollectionEquality().hash(_nodes));
}

@override
String toString() {
    return 'GhIssueCommentConnectionDto(totalCount: $totalCount, nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class _$GhIssueCommentConnectionDtoCopyWith<$Res> implements $GhIssueCommentConnectionDtoCopyWith<$Res> {
  factory _$GhIssueCommentConnectionDtoCopyWith(_GhIssueCommentConnectionDto value, $Res Function(_GhIssueCommentConnectionDto) _then) = __$GhIssueCommentConnectionDtoCopyWithImpl;
@override @useResult
$Res call({
 int totalCount, List<GhCommentDto> nodes
});




}
/// @nodoc
class __$GhIssueCommentConnectionDtoCopyWithImpl<$Res>
    implements _$GhIssueCommentConnectionDtoCopyWith<$Res> {
  __$GhIssueCommentConnectionDtoCopyWithImpl(this._self, this._then);

  final _GhIssueCommentConnectionDto _self;
  final $Res Function(_GhIssueCommentConnectionDto) _then;

/// Create a copy of GhIssueCommentConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalCount = null,Object? nodes = null,}) {
  return _then(_GhIssueCommentConnectionDto(
totalCount: null == totalCount ? _self.totalCount : totalCount // ignore: cast_nullable_to_non_nullable
as int,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhCommentDto>,
  ));
}


}


/// @nodoc
mixin _$GhCommentDto {

 String get id; GhActorDto? get author; String get body; DateTime get createdAt; GhCommentReviewDto? get pullRequestReview;
/// Create a copy of GhCommentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhCommentDtoCopyWith<GhCommentDto> get copyWith => _$GhCommentDtoCopyWithImpl<GhCommentDto>(this as GhCommentDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhCommentDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhCommentDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.body, _this.body) || other.body == _this.body)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.pullRequestReview, _this.pullRequestReview) || other.pullRequestReview == _this.pullRequestReview));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhCommentDto;
  return Object.hash(runtimeType,_this.id,_this.author,_this.body,_this.createdAt,_this.pullRequestReview);
}

@override
String toString() {
  final _this = this as GhCommentDto;
  return 'GhCommentDto(id: ${_this.id}, author: ${_this.author}, body: ${_this.body}, createdAt: ${_this.createdAt}, pullRequestReview: ${_this.pullRequestReview})';
}


}

/// @nodoc
abstract mixin class $GhCommentDtoCopyWith<$Res>  {
  factory $GhCommentDtoCopyWith(GhCommentDto value, $Res Function(GhCommentDto) _then) = _$GhCommentDtoCopyWithImpl;
@useResult
$Res call({
 String id, GhActorDto? author, String body, DateTime createdAt, GhCommentReviewDto? pullRequestReview
});


$GhActorDtoCopyWith<$Res>? get author;$GhCommentReviewDtoCopyWith<$Res>? get pullRequestReview;

}
/// @nodoc
class _$GhCommentDtoCopyWithImpl<$Res>
    implements $GhCommentDtoCopyWith<$Res> {
  _$GhCommentDtoCopyWithImpl(this._self, this._then);

  final GhCommentDto _self;
  final $Res Function(GhCommentDto) _then;

/// Create a copy of GhCommentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? author = freezed,Object? body = null,Object? createdAt = null,Object? pullRequestReview = freezed,}) {
  return _then(GhCommentDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as GhActorDto?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,pullRequestReview: freezed == pullRequestReview ? _self.pullRequestReview : pullRequestReview // ignore: cast_nullable_to_non_nullable
as GhCommentReviewDto?,
  ));
}
/// Create a copy of GhCommentDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhActorDtoCopyWith<$Res>? get author {
    if (_self.author == null) {
    return null;
  }

  return $GhActorDtoCopyWith<$Res>(_self.author!, (value) {
    return _then(_self.copyWith(author: value));
  });
}/// Create a copy of GhCommentDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhCommentReviewDtoCopyWith<$Res>? get pullRequestReview {
    if (_self.pullRequestReview == null) {
    return null;
  }

  return $GhCommentReviewDtoCopyWith<$Res>(_self.pullRequestReview!, (value) {
    return _then(_self.copyWith(pullRequestReview: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhCommentDto implements GhCommentDto {
  const _GhCommentDto({required this.id, required this.author, required this.body, required this.createdAt, required this.pullRequestReview});
  factory _GhCommentDto.fromJson(Map<String, dynamic> json) => _$GhCommentDtoFromJson(json);

@override final  String id;
@override final  GhActorDto? author;
@override final  String body;
@override final  DateTime createdAt;
@override final  GhCommentReviewDto? pullRequestReview;

/// Create a copy of GhCommentDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhCommentDtoCopyWith<_GhCommentDto> get copyWith => __$GhCommentDtoCopyWithImpl<_GhCommentDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhCommentDto&&(identical(other.id, id) || other.id == id)&&(identical(other.author, author) || other.author == author)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.pullRequestReview, pullRequestReview) || other.pullRequestReview == pullRequestReview));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,author,body,createdAt,pullRequestReview);
}

@override
String toString() {
    return 'GhCommentDto(id: $id, author: $author, body: $body, createdAt: $createdAt, pullRequestReview: $pullRequestReview)';
}


}

/// @nodoc
abstract mixin class _$GhCommentDtoCopyWith<$Res> implements $GhCommentDtoCopyWith<$Res> {
  factory _$GhCommentDtoCopyWith(_GhCommentDto value, $Res Function(_GhCommentDto) _then) = __$GhCommentDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, GhActorDto? author, String body, DateTime createdAt, GhCommentReviewDto? pullRequestReview
});


@override $GhActorDtoCopyWith<$Res>? get author;@override $GhCommentReviewDtoCopyWith<$Res>? get pullRequestReview;

}
/// @nodoc
class __$GhCommentDtoCopyWithImpl<$Res>
    implements _$GhCommentDtoCopyWith<$Res> {
  __$GhCommentDtoCopyWithImpl(this._self, this._then);

  final _GhCommentDto _self;
  final $Res Function(_GhCommentDto) _then;

/// Create a copy of GhCommentDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? author = freezed,Object? body = null,Object? createdAt = null,Object? pullRequestReview = freezed,}) {
  return _then(_GhCommentDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as GhActorDto?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,pullRequestReview: freezed == pullRequestReview ? _self.pullRequestReview : pullRequestReview // ignore: cast_nullable_to_non_nullable
as GhCommentReviewDto?,
  ));
}

/// Create a copy of GhCommentDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhActorDtoCopyWith<$Res>? get author {
    if (_self.author == null) {
    return null;
  }

  return $GhActorDtoCopyWith<$Res>(_self.author!, (value) {
    return _then(_self.copyWith(author: value));
  });
}/// Create a copy of GhCommentDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhCommentReviewDtoCopyWith<$Res>? get pullRequestReview {
    if (_self.pullRequestReview == null) {
    return null;
  }

  return $GhCommentReviewDtoCopyWith<$Res>(_self.pullRequestReview!, (value) {
    return _then(_self.copyWith(pullRequestReview: value));
  });
}
}


/// @nodoc
mixin _$GhCommentReviewDto {

@JsonKey(unknownEnumValue: GhReviewStateDto.unknown) GhReviewStateDto get state;
/// Create a copy of GhCommentReviewDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhCommentReviewDtoCopyWith<GhCommentReviewDto> get copyWith => _$GhCommentReviewDtoCopyWithImpl<GhCommentReviewDto>(this as GhCommentReviewDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhCommentReviewDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhCommentReviewDto&&(identical(other.state, _this.state) || other.state == _this.state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhCommentReviewDto;
  return Object.hash(runtimeType,_this.state);
}

@override
String toString() {
  final _this = this as GhCommentReviewDto;
  return 'GhCommentReviewDto(state: ${_this.state})';
}


}

/// @nodoc
abstract mixin class $GhCommentReviewDtoCopyWith<$Res>  {
  factory $GhCommentReviewDtoCopyWith(GhCommentReviewDto value, $Res Function(GhCommentReviewDto) _then) = _$GhCommentReviewDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: GhReviewStateDto.unknown) GhReviewStateDto state
});




}
/// @nodoc
class _$GhCommentReviewDtoCopyWithImpl<$Res>
    implements $GhCommentReviewDtoCopyWith<$Res> {
  _$GhCommentReviewDtoCopyWithImpl(this._self, this._then);

  final GhCommentReviewDto _self;
  final $Res Function(GhCommentReviewDto) _then;

/// Create a copy of GhCommentReviewDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = null,}) {
  return _then(GhCommentReviewDto(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as GhReviewStateDto,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhCommentReviewDto implements GhCommentReviewDto {
  const _GhCommentReviewDto({@JsonKey(unknownEnumValue: GhReviewStateDto.unknown) required this.state});
  factory _GhCommentReviewDto.fromJson(Map<String, dynamic> json) => _$GhCommentReviewDtoFromJson(json);

@override@JsonKey(unknownEnumValue: GhReviewStateDto.unknown) final  GhReviewStateDto state;

/// Create a copy of GhCommentReviewDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhCommentReviewDtoCopyWith<_GhCommentReviewDto> get copyWith => __$GhCommentReviewDtoCopyWithImpl<_GhCommentReviewDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhCommentReviewDto&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,state);
}

@override
String toString() {
    return 'GhCommentReviewDto(state: $state)';
}


}

/// @nodoc
abstract mixin class _$GhCommentReviewDtoCopyWith<$Res> implements $GhCommentReviewDtoCopyWith<$Res> {
  factory _$GhCommentReviewDtoCopyWith(_GhCommentReviewDto value, $Res Function(_GhCommentReviewDto) _then) = __$GhCommentReviewDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: GhReviewStateDto.unknown) GhReviewStateDto state
});




}
/// @nodoc
class __$GhCommentReviewDtoCopyWithImpl<$Res>
    implements _$GhCommentReviewDtoCopyWith<$Res> {
  __$GhCommentReviewDtoCopyWithImpl(this._self, this._then);

  final _GhCommentReviewDto _self;
  final $Res Function(_GhCommentReviewDto) _then;

/// Create a copy of GhCommentReviewDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = null,}) {
  return _then(_GhCommentReviewDto(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as GhReviewStateDto,
  ));
}


}


/// @nodoc
mixin _$GhActorDto {

 String get login;@JsonKey(name: "__typename", unknownEnumValue: GhActorKindDto.other) GhActorKindDto get kind;
/// Create a copy of GhActorDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhActorDtoCopyWith<GhActorDto> get copyWith => _$GhActorDtoCopyWithImpl<GhActorDto>(this as GhActorDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhActorDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhActorDto&&(identical(other.login, _this.login) || other.login == _this.login)&&(identical(other.kind, _this.kind) || other.kind == _this.kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhActorDto;
  return Object.hash(runtimeType,_this.login,_this.kind);
}

@override
String toString() {
  final _this = this as GhActorDto;
  return 'GhActorDto(login: ${_this.login}, kind: ${_this.kind})';
}


}

/// @nodoc
abstract mixin class $GhActorDtoCopyWith<$Res>  {
  factory $GhActorDtoCopyWith(GhActorDto value, $Res Function(GhActorDto) _then) = _$GhActorDtoCopyWithImpl;
@useResult
$Res call({
 String login,@JsonKey(name: "__typename", unknownEnumValue: GhActorKindDto.other) GhActorKindDto kind
});




}
/// @nodoc
class _$GhActorDtoCopyWithImpl<$Res>
    implements $GhActorDtoCopyWith<$Res> {
  _$GhActorDtoCopyWithImpl(this._self, this._then);

  final GhActorDto _self;
  final $Res Function(GhActorDto) _then;

/// Create a copy of GhActorDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? login = null,Object? kind = null,}) {
  return _then(GhActorDto(
login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as GhActorKindDto,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhActorDto implements GhActorDto {
  const _GhActorDto({required this.login, @JsonKey(name: "__typename", unknownEnumValue: GhActorKindDto.other) required this.kind});
  factory _GhActorDto.fromJson(Map<String, dynamic> json) => _$GhActorDtoFromJson(json);

@override final  String login;
@override@JsonKey(name: "__typename", unknownEnumValue: GhActorKindDto.other) final  GhActorKindDto kind;

/// Create a copy of GhActorDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhActorDtoCopyWith<_GhActorDto> get copyWith => __$GhActorDtoCopyWithImpl<_GhActorDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhActorDto&&(identical(other.login, login) || other.login == login)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,login,kind);
}

@override
String toString() {
    return 'GhActorDto(login: $login, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$GhActorDtoCopyWith<$Res> implements $GhActorDtoCopyWith<$Res> {
  factory _$GhActorDtoCopyWith(_GhActorDto value, $Res Function(_GhActorDto) _then) = __$GhActorDtoCopyWithImpl;
@override @useResult
$Res call({
 String login,@JsonKey(name: "__typename", unknownEnumValue: GhActorKindDto.other) GhActorKindDto kind
});




}
/// @nodoc
class __$GhActorDtoCopyWithImpl<$Res>
    implements _$GhActorDtoCopyWith<$Res> {
  __$GhActorDtoCopyWithImpl(this._self, this._then);

  final _GhActorDto _self;
  final $Res Function(_GhActorDto) _then;

/// Create a copy of GhActorDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? login = null,Object? kind = null,}) {
  return _then(_GhActorDto(
login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as GhActorKindDto,
  ));
}


}


/// @nodoc
mixin _$GhTotalCountDto {

 int get totalCount;
/// Create a copy of GhTotalCountDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhTotalCountDtoCopyWith<GhTotalCountDto> get copyWith => _$GhTotalCountDtoCopyWithImpl<GhTotalCountDto>(this as GhTotalCountDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhTotalCountDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhTotalCountDto&&(identical(other.totalCount, _this.totalCount) || other.totalCount == _this.totalCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhTotalCountDto;
  return Object.hash(runtimeType,_this.totalCount);
}

@override
String toString() {
  final _this = this as GhTotalCountDto;
  return 'GhTotalCountDto(totalCount: ${_this.totalCount})';
}


}

/// @nodoc
abstract mixin class $GhTotalCountDtoCopyWith<$Res>  {
  factory $GhTotalCountDtoCopyWith(GhTotalCountDto value, $Res Function(GhTotalCountDto) _then) = _$GhTotalCountDtoCopyWithImpl;
@useResult
$Res call({
 int totalCount
});




}
/// @nodoc
class _$GhTotalCountDtoCopyWithImpl<$Res>
    implements $GhTotalCountDtoCopyWith<$Res> {
  _$GhTotalCountDtoCopyWithImpl(this._self, this._then);

  final GhTotalCountDto _self;
  final $Res Function(GhTotalCountDto) _then;

/// Create a copy of GhTotalCountDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalCount = null,}) {
  return _then(GhTotalCountDto(
totalCount: null == totalCount ? _self.totalCount : totalCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhTotalCountDto implements GhTotalCountDto {
  const _GhTotalCountDto({required this.totalCount});
  factory _GhTotalCountDto.fromJson(Map<String, dynamic> json) => _$GhTotalCountDtoFromJson(json);

@override final  int totalCount;

/// Create a copy of GhTotalCountDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhTotalCountDtoCopyWith<_GhTotalCountDto> get copyWith => __$GhTotalCountDtoCopyWithImpl<_GhTotalCountDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhTotalCountDto&&(identical(other.totalCount, totalCount) || other.totalCount == totalCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,totalCount);
}

@override
String toString() {
    return 'GhTotalCountDto(totalCount: $totalCount)';
}


}

/// @nodoc
abstract mixin class _$GhTotalCountDtoCopyWith<$Res> implements $GhTotalCountDtoCopyWith<$Res> {
  factory _$GhTotalCountDtoCopyWith(_GhTotalCountDto value, $Res Function(_GhTotalCountDto) _then) = __$GhTotalCountDtoCopyWithImpl;
@override @useResult
$Res call({
 int totalCount
});




}
/// @nodoc
class __$GhTotalCountDtoCopyWithImpl<$Res>
    implements _$GhTotalCountDtoCopyWith<$Res> {
  __$GhTotalCountDtoCopyWithImpl(this._self, this._then);

  final _GhTotalCountDto _self;
  final $Res Function(_GhTotalCountDto) _then;

/// Create a copy of GhTotalCountDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalCount = null,}) {
  return _then(_GhTotalCountDto(
totalCount: null == totalCount ? _self.totalCount : totalCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$GhLabelConnectionDto {

 GhPageInfoDto get pageInfo; List<GhLabelDto> get nodes;
/// Create a copy of GhLabelConnectionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhLabelConnectionDtoCopyWith<GhLabelConnectionDto> get copyWith => _$GhLabelConnectionDtoCopyWithImpl<GhLabelConnectionDto>(this as GhLabelConnectionDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhLabelConnectionDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhLabelConnectionDto&&(identical(other.pageInfo, _this.pageInfo) || other.pageInfo == _this.pageInfo)&&const DeepCollectionEquality().equals(other.nodes, _this.nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhLabelConnectionDto;
  return Object.hash(runtimeType,_this.pageInfo,const DeepCollectionEquality().hash(_this.nodes));
}

@override
String toString() {
  final _this = this as GhLabelConnectionDto;
  return 'GhLabelConnectionDto(pageInfo: ${_this.pageInfo}, nodes: ${_this.nodes})';
}


}

/// @nodoc
abstract mixin class $GhLabelConnectionDtoCopyWith<$Res>  {
  factory $GhLabelConnectionDtoCopyWith(GhLabelConnectionDto value, $Res Function(GhLabelConnectionDto) _then) = _$GhLabelConnectionDtoCopyWithImpl;
@useResult
$Res call({
 GhPageInfoDto pageInfo, List<GhLabelDto> nodes
});


$GhPageInfoDtoCopyWith<$Res> get pageInfo;

}
/// @nodoc
class _$GhLabelConnectionDtoCopyWithImpl<$Res>
    implements $GhLabelConnectionDtoCopyWith<$Res> {
  _$GhLabelConnectionDtoCopyWithImpl(this._self, this._then);

  final GhLabelConnectionDto _self;
  final $Res Function(GhLabelConnectionDto) _then;

/// Create a copy of GhLabelConnectionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pageInfo = null,Object? nodes = null,}) {
  return _then(GhLabelConnectionDto(
pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as GhPageInfoDto,nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhLabelDto>,
  ));
}
/// Create a copy of GhLabelConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPageInfoDtoCopyWith<$Res> get pageInfo {
  
  return $GhPageInfoDtoCopyWith<$Res>(_self.pageInfo, (value) {
    return _then(_self.copyWith(pageInfo: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhLabelConnectionDto implements GhLabelConnectionDto {
  const _GhLabelConnectionDto({required this.pageInfo, required  List<GhLabelDto> nodes}): _nodes = nodes;
  factory _GhLabelConnectionDto.fromJson(Map<String, dynamic> json) => _$GhLabelConnectionDtoFromJson(json);

@override final  GhPageInfoDto pageInfo;
 final  List<GhLabelDto> _nodes;
@override List<GhLabelDto> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}


/// Create a copy of GhLabelConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhLabelConnectionDtoCopyWith<_GhLabelConnectionDto> get copyWith => __$GhLabelConnectionDtoCopyWithImpl<_GhLabelConnectionDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhLabelConnectionDto&&(identical(other.pageInfo, pageInfo) || other.pageInfo == pageInfo)&&const DeepCollectionEquality().equals(other.nodes, _nodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,pageInfo,const DeepCollectionEquality().hash(_nodes));
}

@override
String toString() {
    return 'GhLabelConnectionDto(pageInfo: $pageInfo, nodes: $nodes)';
}


}

/// @nodoc
abstract mixin class _$GhLabelConnectionDtoCopyWith<$Res> implements $GhLabelConnectionDtoCopyWith<$Res> {
  factory _$GhLabelConnectionDtoCopyWith(_GhLabelConnectionDto value, $Res Function(_GhLabelConnectionDto) _then) = __$GhLabelConnectionDtoCopyWithImpl;
@override @useResult
$Res call({
 GhPageInfoDto pageInfo, List<GhLabelDto> nodes
});


@override $GhPageInfoDtoCopyWith<$Res> get pageInfo;

}
/// @nodoc
class __$GhLabelConnectionDtoCopyWithImpl<$Res>
    implements _$GhLabelConnectionDtoCopyWith<$Res> {
  __$GhLabelConnectionDtoCopyWithImpl(this._self, this._then);

  final _GhLabelConnectionDto _self;
  final $Res Function(_GhLabelConnectionDto) _then;

/// Create a copy of GhLabelConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pageInfo = null,Object? nodes = null,}) {
  return _then(_GhLabelConnectionDto(
pageInfo: null == pageInfo ? _self.pageInfo : pageInfo // ignore: cast_nullable_to_non_nullable
as GhPageInfoDto,nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<GhLabelDto>,
  ));
}

/// Create a copy of GhLabelConnectionDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhPageInfoDtoCopyWith<$Res> get pageInfo {
  
  return $GhPageInfoDtoCopyWith<$Res>(_self.pageInfo, (value) {
    return _then(_self.copyWith(pageInfo: value));
  });
}
}


/// @nodoc
mixin _$GhLabelDto {

 String get name;
/// Create a copy of GhLabelDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhLabelDtoCopyWith<GhLabelDto> get copyWith => _$GhLabelDtoCopyWithImpl<GhLabelDto>(this as GhLabelDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhLabelDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhLabelDto&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhLabelDto;
  return Object.hash(runtimeType,_this.name);
}

@override
String toString() {
  final _this = this as GhLabelDto;
  return 'GhLabelDto(name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $GhLabelDtoCopyWith<$Res>  {
  factory $GhLabelDtoCopyWith(GhLabelDto value, $Res Function(GhLabelDto) _then) = _$GhLabelDtoCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$GhLabelDtoCopyWithImpl<$Res>
    implements $GhLabelDtoCopyWith<$Res> {
  _$GhLabelDtoCopyWithImpl(this._self, this._then);

  final GhLabelDto _self;
  final $Res Function(GhLabelDto) _then;

/// Create a copy of GhLabelDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,}) {
  return _then(GhLabelDto(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhLabelDto implements GhLabelDto {
  const _GhLabelDto({required this.name});
  factory _GhLabelDto.fromJson(Map<String, dynamic> json) => _$GhLabelDtoFromJson(json);

@override final  String name;

/// Create a copy of GhLabelDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhLabelDtoCopyWith<_GhLabelDto> get copyWith => __$GhLabelDtoCopyWithImpl<_GhLabelDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhLabelDto&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'GhLabelDto(name: $name)';
}


}

/// @nodoc
abstract mixin class _$GhLabelDtoCopyWith<$Res> implements $GhLabelDtoCopyWith<$Res> {
  factory _$GhLabelDtoCopyWith(_GhLabelDto value, $Res Function(_GhLabelDto) _then) = __$GhLabelDtoCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class __$GhLabelDtoCopyWithImpl<$Res>
    implements _$GhLabelDtoCopyWith<$Res> {
  __$GhLabelDtoCopyWithImpl(this._self, this._then);

  final _GhLabelDto _self;
  final $Res Function(_GhLabelDto) _then;

/// Create a copy of GhLabelDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(_GhLabelDto(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
