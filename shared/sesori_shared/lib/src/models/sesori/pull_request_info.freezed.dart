// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pull_request_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PullRequestInfo {

 int get number; String get url; String get title; String get state; String? get mergeableStatus; String? get reviewDecision; String? get checkStatus;
/// Create a copy of PullRequestInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestInfoCopyWith<PullRequestInfo> get copyWith => _$PullRequestInfoCopyWithImpl<PullRequestInfo>(this as PullRequestInfo, _$identity);

  /// Serializes this PullRequestInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestInfo&&(identical(other.number, number) || other.number == number)&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.state, state) || other.state == state)&&(identical(other.mergeableStatus, mergeableStatus) || other.mergeableStatus == mergeableStatus)&&(identical(other.reviewDecision, reviewDecision) || other.reviewDecision == reviewDecision)&&(identical(other.checkStatus, checkStatus) || other.checkStatus == checkStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,number,url,title,state,mergeableStatus,reviewDecision,checkStatus);

@override
String toString() {
  return 'PullRequestInfo(number: $number, url: $url, title: $title, state: $state, mergeableStatus: $mergeableStatus, reviewDecision: $reviewDecision, checkStatus: $checkStatus)';
}


}

/// @nodoc
abstract mixin class $PullRequestInfoCopyWith<$Res>  {
  factory $PullRequestInfoCopyWith(PullRequestInfo value, $Res Function(PullRequestInfo) _then) = _$PullRequestInfoCopyWithImpl;
@useResult
$Res call({
 int number, String url, String title, String state, String? mergeableStatus, String? reviewDecision, String? checkStatus
});




}
/// @nodoc
class _$PullRequestInfoCopyWithImpl<$Res>
    implements $PullRequestInfoCopyWith<$Res> {
  _$PullRequestInfoCopyWithImpl(this._self, this._then);

  final PullRequestInfo _self;
  final $Res Function(PullRequestInfo) _then;

/// Create a copy of PullRequestInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? number = null,Object? url = null,Object? title = null,Object? state = null,Object? mergeableStatus = freezed,Object? reviewDecision = freezed,Object? checkStatus = freezed,}) {
  return _then(_self.copyWith(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,mergeableStatus: freezed == mergeableStatus ? _self.mergeableStatus : mergeableStatus // ignore: cast_nullable_to_non_nullable
as String?,reviewDecision: freezed == reviewDecision ? _self.reviewDecision : reviewDecision // ignore: cast_nullable_to_non_nullable
as String?,checkStatus: freezed == checkStatus ? _self.checkStatus : checkStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PullRequestInfo implements PullRequestInfo {
  const _PullRequestInfo({required this.number, required this.url, required this.title, required this.state, required this.mergeableStatus, required this.reviewDecision, required this.checkStatus});
  factory _PullRequestInfo.fromJson(Map<String, dynamic> json) => _$PullRequestInfoFromJson(json);

@override final  int number;
@override final  String url;
@override final  String title;
@override final  String state;
@override final  String? mergeableStatus;
@override final  String? reviewDecision;
@override final  String? checkStatus;

/// Create a copy of PullRequestInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestInfoCopyWith<_PullRequestInfo> get copyWith => __$PullRequestInfoCopyWithImpl<_PullRequestInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestInfo&&(identical(other.number, number) || other.number == number)&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.state, state) || other.state == state)&&(identical(other.mergeableStatus, mergeableStatus) || other.mergeableStatus == mergeableStatus)&&(identical(other.reviewDecision, reviewDecision) || other.reviewDecision == reviewDecision)&&(identical(other.checkStatus, checkStatus) || other.checkStatus == checkStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,number,url,title,state,mergeableStatus,reviewDecision,checkStatus);

@override
String toString() {
  return 'PullRequestInfo(number: $number, url: $url, title: $title, state: $state, mergeableStatus: $mergeableStatus, reviewDecision: $reviewDecision, checkStatus: $checkStatus)';
}


}

/// @nodoc
abstract mixin class _$PullRequestInfoCopyWith<$Res> implements $PullRequestInfoCopyWith<$Res> {
  factory _$PullRequestInfoCopyWith(_PullRequestInfo value, $Res Function(_PullRequestInfo) _then) = __$PullRequestInfoCopyWithImpl;
@override @useResult
$Res call({
 int number, String url, String title, String state, String? mergeableStatus, String? reviewDecision, String? checkStatus
});




}
/// @nodoc
class __$PullRequestInfoCopyWithImpl<$Res>
    implements _$PullRequestInfoCopyWith<$Res> {
  __$PullRequestInfoCopyWithImpl(this._self, this._then);

  final _PullRequestInfo _self;
  final $Res Function(_PullRequestInfo) _then;

/// Create a copy of PullRequestInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? number = null,Object? url = null,Object? title = null,Object? state = null,Object? mergeableStatus = freezed,Object? reviewDecision = freezed,Object? checkStatus = freezed,}) {
  return _then(_PullRequestInfo(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,mergeableStatus: freezed == mergeableStatus ? _self.mergeableStatus : mergeableStatus // ignore: cast_nullable_to_non_nullable
as String?,reviewDecision: freezed == reviewDecision ? _self.reviewDecision : reviewDecision // ignore: cast_nullable_to_non_nullable
as String?,checkStatus: freezed == checkStatus ? _self.checkStatus : checkStatus // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
