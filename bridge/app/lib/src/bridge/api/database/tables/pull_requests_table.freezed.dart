// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pull_requests_table.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PullRequestDto {

 String get projectId; int get prNumber; String get branchName; String get url; String get title; PrState get state; PrMergeableStatus get mergeableStatus; PrReviewDecision get reviewDecision; PrCheckStatus get checkStatus; int get lastCheckedAt; int get createdAt;
/// Create a copy of PullRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestDtoCopyWith<PullRequestDto> get copyWith => _$PullRequestDtoCopyWithImpl<PullRequestDto>(this as PullRequestDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestDto&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.prNumber, prNumber) || other.prNumber == prNumber)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.state, state) || other.state == state)&&(identical(other.mergeableStatus, mergeableStatus) || other.mergeableStatus == mergeableStatus)&&(identical(other.reviewDecision, reviewDecision) || other.reviewDecision == reviewDecision)&&(identical(other.checkStatus, checkStatus) || other.checkStatus == checkStatus)&&(identical(other.lastCheckedAt, lastCheckedAt) || other.lastCheckedAt == lastCheckedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,projectId,prNumber,branchName,url,title,state,mergeableStatus,reviewDecision,checkStatus,lastCheckedAt,createdAt);

@override
String toString() {
  return 'PullRequestDto(projectId: $projectId, prNumber: $prNumber, branchName: $branchName, url: $url, title: $title, state: $state, mergeableStatus: $mergeableStatus, reviewDecision: $reviewDecision, checkStatus: $checkStatus, lastCheckedAt: $lastCheckedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PullRequestDtoCopyWith<$Res>  {
  factory $PullRequestDtoCopyWith(PullRequestDto value, $Res Function(PullRequestDto) _then) = _$PullRequestDtoCopyWithImpl;
@useResult
$Res call({
 String projectId, int prNumber, String branchName, String url, String title, PrState state, PrMergeableStatus mergeableStatus, PrReviewDecision reviewDecision, PrCheckStatus checkStatus, int lastCheckedAt, int createdAt
});




}
/// @nodoc
class _$PullRequestDtoCopyWithImpl<$Res>
    implements $PullRequestDtoCopyWith<$Res> {
  _$PullRequestDtoCopyWithImpl(this._self, this._then);

  final PullRequestDto _self;
  final $Res Function(PullRequestDto) _then;

/// Create a copy of PullRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? prNumber = null,Object? branchName = null,Object? url = null,Object? title = null,Object? state = null,Object? mergeableStatus = null,Object? reviewDecision = null,Object? checkStatus = null,Object? lastCheckedAt = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,prNumber: null == prNumber ? _self.prNumber : prNumber // ignore: cast_nullable_to_non_nullable
as int,branchName: null == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PrState,mergeableStatus: null == mergeableStatus ? _self.mergeableStatus : mergeableStatus // ignore: cast_nullable_to_non_nullable
as PrMergeableStatus,reviewDecision: null == reviewDecision ? _self.reviewDecision : reviewDecision // ignore: cast_nullable_to_non_nullable
as PrReviewDecision,checkStatus: null == checkStatus ? _self.checkStatus : checkStatus // ignore: cast_nullable_to_non_nullable
as PrCheckStatus,lastCheckedAt: null == lastCheckedAt ? _self.lastCheckedAt : lastCheckedAt // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc


class _PullRequestDto extends PullRequestDto {
  const _PullRequestDto({required this.projectId, required this.prNumber, required this.branchName, required this.url, required this.title, required this.state, required this.mergeableStatus, required this.reviewDecision, required this.checkStatus, required this.lastCheckedAt, required this.createdAt}): super._();
  

@override final  String projectId;
@override final  int prNumber;
@override final  String branchName;
@override final  String url;
@override final  String title;
@override final  PrState state;
@override final  PrMergeableStatus mergeableStatus;
@override final  PrReviewDecision reviewDecision;
@override final  PrCheckStatus checkStatus;
@override final  int lastCheckedAt;
@override final  int createdAt;

/// Create a copy of PullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestDtoCopyWith<_PullRequestDto> get copyWith => __$PullRequestDtoCopyWithImpl<_PullRequestDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestDto&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.prNumber, prNumber) || other.prNumber == prNumber)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.state, state) || other.state == state)&&(identical(other.mergeableStatus, mergeableStatus) || other.mergeableStatus == mergeableStatus)&&(identical(other.reviewDecision, reviewDecision) || other.reviewDecision == reviewDecision)&&(identical(other.checkStatus, checkStatus) || other.checkStatus == checkStatus)&&(identical(other.lastCheckedAt, lastCheckedAt) || other.lastCheckedAt == lastCheckedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,projectId,prNumber,branchName,url,title,state,mergeableStatus,reviewDecision,checkStatus,lastCheckedAt,createdAt);

@override
String toString() {
  return 'PullRequestDto(projectId: $projectId, prNumber: $prNumber, branchName: $branchName, url: $url, title: $title, state: $state, mergeableStatus: $mergeableStatus, reviewDecision: $reviewDecision, checkStatus: $checkStatus, lastCheckedAt: $lastCheckedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PullRequestDtoCopyWith<$Res> implements $PullRequestDtoCopyWith<$Res> {
  factory _$PullRequestDtoCopyWith(_PullRequestDto value, $Res Function(_PullRequestDto) _then) = __$PullRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String projectId, int prNumber, String branchName, String url, String title, PrState state, PrMergeableStatus mergeableStatus, PrReviewDecision reviewDecision, PrCheckStatus checkStatus, int lastCheckedAt, int createdAt
});




}
/// @nodoc
class __$PullRequestDtoCopyWithImpl<$Res>
    implements _$PullRequestDtoCopyWith<$Res> {
  __$PullRequestDtoCopyWithImpl(this._self, this._then);

  final _PullRequestDto _self;
  final $Res Function(_PullRequestDto) _then;

/// Create a copy of PullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? prNumber = null,Object? branchName = null,Object? url = null,Object? title = null,Object? state = null,Object? mergeableStatus = null,Object? reviewDecision = null,Object? checkStatus = null,Object? lastCheckedAt = null,Object? createdAt = null,}) {
  return _then(_PullRequestDto(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,prNumber: null == prNumber ? _self.prNumber : prNumber // ignore: cast_nullable_to_non_nullable
as int,branchName: null == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PrState,mergeableStatus: null == mergeableStatus ? _self.mergeableStatus : mergeableStatus // ignore: cast_nullable_to_non_nullable
as PrMergeableStatus,reviewDecision: null == reviewDecision ? _self.reviewDecision : reviewDecision // ignore: cast_nullable_to_non_nullable
as PrReviewDecision,checkStatus: null == checkStatus ? _self.checkStatus : checkStatus // ignore: cast_nullable_to_non_nullable
as PrCheckStatus,lastCheckedAt: null == lastCheckedAt ? _self.lastCheckedAt : lastCheckedAt // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
