// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stored_pull_request_watch.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StoredPullRequestWatch {

 String get owner; String get repo; int get number;/// The PR's title at the last report, for lists.
 String get title; bool get autoMerge;/// What the last report to this session covered.
 PullRequestBaseline get baseline; DateTime get lastReportAt;
/// Create a copy of StoredPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoredPullRequestWatchCopyWith<StoredPullRequestWatch> get copyWith => _$StoredPullRequestWatchCopyWithImpl<StoredPullRequestWatch>(this as StoredPullRequestWatch, _$identity);

  /// Serializes this StoredPullRequestWatch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as StoredPullRequestWatch;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoredPullRequestWatch&&(identical(other.owner, _this.owner) || other.owner == _this.owner)&&(identical(other.repo, _this.repo) || other.repo == _this.repo)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.autoMerge, _this.autoMerge) || other.autoMerge == _this.autoMerge)&&(identical(other.baseline, _this.baseline) || other.baseline == _this.baseline)&&(identical(other.lastReportAt, _this.lastReportAt) || other.lastReportAt == _this.lastReportAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as StoredPullRequestWatch;
  return Object.hash(runtimeType,_this.owner,_this.repo,_this.number,_this.title,_this.autoMerge,_this.baseline,_this.lastReportAt);
}

@override
String toString() {
  final _this = this as StoredPullRequestWatch;
  return 'StoredPullRequestWatch(owner: ${_this.owner}, repo: ${_this.repo}, number: ${_this.number}, title: ${_this.title}, autoMerge: ${_this.autoMerge}, baseline: ${_this.baseline}, lastReportAt: ${_this.lastReportAt})';
}


}

/// @nodoc
abstract mixin class $StoredPullRequestWatchCopyWith<$Res>  {
  factory $StoredPullRequestWatchCopyWith(StoredPullRequestWatch value, $Res Function(StoredPullRequestWatch) _then) = _$StoredPullRequestWatchCopyWithImpl;
@useResult
$Res call({
 String owner, String repo, int number, String title, bool autoMerge, PullRequestBaseline baseline, DateTime lastReportAt
});


$PullRequestBaselineCopyWith<$Res> get baseline;

}
/// @nodoc
class _$StoredPullRequestWatchCopyWithImpl<$Res>
    implements $StoredPullRequestWatchCopyWith<$Res> {
  _$StoredPullRequestWatchCopyWithImpl(this._self, this._then);

  final StoredPullRequestWatch _self;
  final $Res Function(StoredPullRequestWatch) _then;

/// Create a copy of StoredPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? owner = null,Object? repo = null,Object? number = null,Object? title = null,Object? autoMerge = null,Object? baseline = null,Object? lastReportAt = null,}) {
  return _then(StoredPullRequestWatch(
owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as String,repo: null == repo ? _self.repo : repo // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,autoMerge: null == autoMerge ? _self.autoMerge : autoMerge // ignore: cast_nullable_to_non_nullable
as bool,baseline: null == baseline ? _self.baseline : baseline // ignore: cast_nullable_to_non_nullable
as PullRequestBaseline,lastReportAt: null == lastReportAt ? _self.lastReportAt : lastReportAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of StoredPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestBaselineCopyWith<$Res> get baseline {
  
  return $PullRequestBaselineCopyWith<$Res>(_self.baseline, (value) {
    return _then(_self.copyWith(baseline: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _StoredPullRequestWatch implements StoredPullRequestWatch {
  const _StoredPullRequestWatch({required this.owner, required this.repo, required this.number, required this.title, required this.autoMerge, required this.baseline, required this.lastReportAt});
  factory _StoredPullRequestWatch.fromJson(Map<String, dynamic> json) => _$StoredPullRequestWatchFromJson(json);

@override final  String owner;
@override final  String repo;
@override final  int number;
/// The PR's title at the last report, for lists.
@override final  String title;
@override final  bool autoMerge;
/// What the last report to this session covered.
@override final  PullRequestBaseline baseline;
@override final  DateTime lastReportAt;

/// Create a copy of StoredPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoredPullRequestWatchCopyWith<_StoredPullRequestWatch> get copyWith => __$StoredPullRequestWatchCopyWithImpl<_StoredPullRequestWatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StoredPullRequestWatchToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StoredPullRequestWatch&&(identical(other.owner, owner) || other.owner == owner)&&(identical(other.repo, repo) || other.repo == repo)&&(identical(other.number, number) || other.number == number)&&(identical(other.title, title) || other.title == title)&&(identical(other.autoMerge, autoMerge) || other.autoMerge == autoMerge)&&(identical(other.baseline, baseline) || other.baseline == baseline)&&(identical(other.lastReportAt, lastReportAt) || other.lastReportAt == lastReportAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,owner,repo,number,title,autoMerge,baseline,lastReportAt);
}

@override
String toString() {
    return 'StoredPullRequestWatch(owner: $owner, repo: $repo, number: $number, title: $title, autoMerge: $autoMerge, baseline: $baseline, lastReportAt: $lastReportAt)';
}


}

/// @nodoc
abstract mixin class _$StoredPullRequestWatchCopyWith<$Res> implements $StoredPullRequestWatchCopyWith<$Res> {
  factory _$StoredPullRequestWatchCopyWith(_StoredPullRequestWatch value, $Res Function(_StoredPullRequestWatch) _then) = __$StoredPullRequestWatchCopyWithImpl;
@override @useResult
$Res call({
 String owner, String repo, int number, String title, bool autoMerge, PullRequestBaseline baseline, DateTime lastReportAt
});


@override $PullRequestBaselineCopyWith<$Res> get baseline;

}
/// @nodoc
class __$StoredPullRequestWatchCopyWithImpl<$Res>
    implements _$StoredPullRequestWatchCopyWith<$Res> {
  __$StoredPullRequestWatchCopyWithImpl(this._self, this._then);

  final _StoredPullRequestWatch _self;
  final $Res Function(_StoredPullRequestWatch) _then;

/// Create a copy of StoredPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? owner = null,Object? repo = null,Object? number = null,Object? title = null,Object? autoMerge = null,Object? baseline = null,Object? lastReportAt = null,}) {
  return _then(_StoredPullRequestWatch(
owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as String,repo: null == repo ? _self.repo : repo // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,autoMerge: null == autoMerge ? _self.autoMerge : autoMerge // ignore: cast_nullable_to_non_nullable
as bool,baseline: null == baseline ? _self.baseline : baseline // ignore: cast_nullable_to_non_nullable
as PullRequestBaseline,lastReportAt: null == lastReportAt ? _self.lastReportAt : lastReportAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of StoredPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestBaselineCopyWith<$Res> get baseline {
  
  return $PullRequestBaselineCopyWith<$Res>(_self.baseline, (value) {
    return _then(_self.copyWith(baseline: value));
  });
}
}

// dart format on
