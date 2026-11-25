// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pull_request_watch.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionPullRequestWatch {

/// `owner/repo`.
 String get repository; int get number;/// The PR's title at the watch's last report.
 String get title; String get url;/// Whether this session's watch merges the PR once it is ready.
 bool get autoMerge; PullRequestWatchStatus get status;
/// Create a copy of SessionPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionPullRequestWatchCopyWith<SessionPullRequestWatch> get copyWith => _$SessionPullRequestWatchCopyWithImpl<SessionPullRequestWatch>(this as SessionPullRequestWatch, _$identity);

  /// Serializes this SessionPullRequestWatch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionPullRequestWatch;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPullRequestWatch&&(identical(other.repository, _this.repository) || other.repository == _this.repository)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.autoMerge, _this.autoMerge) || other.autoMerge == _this.autoMerge)&&(identical(other.status, _this.status) || other.status == _this.status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionPullRequestWatch;
  return Object.hash(runtimeType,_this.repository,_this.number,_this.title,_this.url,_this.autoMerge,_this.status);
}

@override
String toString() {
  final _this = this as SessionPullRequestWatch;
  return 'SessionPullRequestWatch(repository: ${_this.repository}, number: ${_this.number}, title: ${_this.title}, url: ${_this.url}, autoMerge: ${_this.autoMerge}, status: ${_this.status})';
}


}

/// @nodoc
abstract mixin class $SessionPullRequestWatchCopyWith<$Res>  {
  factory $SessionPullRequestWatchCopyWith(SessionPullRequestWatch value, $Res Function(SessionPullRequestWatch) _then) = _$SessionPullRequestWatchCopyWithImpl;
@useResult
$Res call({
 String repository, int number, String title, String url, bool autoMerge, PullRequestWatchStatus status
});


$PullRequestWatchStatusCopyWith<$Res> get status;

}
/// @nodoc
class _$SessionPullRequestWatchCopyWithImpl<$Res>
    implements $SessionPullRequestWatchCopyWith<$Res> {
  _$SessionPullRequestWatchCopyWithImpl(this._self, this._then);

  final SessionPullRequestWatch _self;
  final $Res Function(SessionPullRequestWatch) _then;

/// Create a copy of SessionPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? repository = null,Object? number = null,Object? title = null,Object? url = null,Object? autoMerge = null,Object? status = null,}) {
  return _then(SessionPullRequestWatch(
repository: null == repository ? _self.repository : repository // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,autoMerge: null == autoMerge ? _self.autoMerge : autoMerge // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PullRequestWatchStatus,
  ));
}
/// Create a copy of SessionPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestWatchStatusCopyWith<$Res> get status {
  
  return $PullRequestWatchStatusCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _SessionPullRequestWatch implements SessionPullRequestWatch {
  const _SessionPullRequestWatch({required this.repository, required this.number, required this.title, required this.url, required this.autoMerge, required this.status});
  factory _SessionPullRequestWatch.fromJson(Map<String, dynamic> json) => _$SessionPullRequestWatchFromJson(json);

/// `owner/repo`.
@override final  String repository;
@override final  int number;
/// The PR's title at the watch's last report.
@override final  String title;
@override final  String url;
/// Whether this session's watch merges the PR once it is ready.
@override final  bool autoMerge;
@override final  PullRequestWatchStatus status;

/// Create a copy of SessionPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionPullRequestWatchCopyWith<_SessionPullRequestWatch> get copyWith => __$SessionPullRequestWatchCopyWithImpl<_SessionPullRequestWatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionPullRequestWatchToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPullRequestWatch&&(identical(other.repository, repository) || other.repository == repository)&&(identical(other.number, number) || other.number == number)&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.autoMerge, autoMerge) || other.autoMerge == autoMerge)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,repository,number,title,url,autoMerge,status);
}

@override
String toString() {
    return 'SessionPullRequestWatch(repository: $repository, number: $number, title: $title, url: $url, autoMerge: $autoMerge, status: $status)';
}


}

/// @nodoc
abstract mixin class _$SessionPullRequestWatchCopyWith<$Res> implements $SessionPullRequestWatchCopyWith<$Res> {
  factory _$SessionPullRequestWatchCopyWith(_SessionPullRequestWatch value, $Res Function(_SessionPullRequestWatch) _then) = __$SessionPullRequestWatchCopyWithImpl;
@override @useResult
$Res call({
 String repository, int number, String title, String url, bool autoMerge, PullRequestWatchStatus status
});


@override $PullRequestWatchStatusCopyWith<$Res> get status;

}
/// @nodoc
class __$SessionPullRequestWatchCopyWithImpl<$Res>
    implements _$SessionPullRequestWatchCopyWith<$Res> {
  __$SessionPullRequestWatchCopyWithImpl(this._self, this._then);

  final _SessionPullRequestWatch _self;
  final $Res Function(_SessionPullRequestWatch) _then;

/// Create a copy of SessionPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? repository = null,Object? number = null,Object? title = null,Object? url = null,Object? autoMerge = null,Object? status = null,}) {
  return _then(_SessionPullRequestWatch(
repository: null == repository ? _self.repository : repository // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,autoMerge: null == autoMerge ? _self.autoMerge : autoMerge // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PullRequestWatchStatus,
  ));
}

/// Create a copy of SessionPullRequestWatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestWatchStatusCopyWith<$Res> get status {
  
  return $PullRequestWatchStatusCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}

PullRequestWatchStatus _$PullRequestWatchStatusFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'needsYou':
          return PullRequestWatchStatusNeedsYou.fromJson(
            json
          );
                case 'waiting':
          return PullRequestWatchStatusWaiting.fromJson(
            json
          );
                case 'ready':
          return PullRequestWatchStatusReady.fromJson(
            json
          );
                case 'merged':
          return PullRequestWatchStatusMerged.fromJson(
            json
          );
        
          default:
            return PullRequestWatchStatusUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PullRequestWatchStatus {



  /// Serializes this PullRequestWatchStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestWatchStatus);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PullRequestWatchStatus()';
}


}

/// @nodoc
class $PullRequestWatchStatusCopyWith<$Res>  {
$PullRequestWatchStatusCopyWith(PullRequestWatchStatus _, $Res Function(PullRequestWatchStatus) __);
}



/// @nodoc
@JsonSerializable()

class PullRequestWatchStatusUnknown implements PullRequestWatchStatus {
  const PullRequestWatchStatusUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory PullRequestWatchStatusUnknown.fromJson(Map<String, dynamic> json) => _$PullRequestWatchStatusUnknownFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PullRequestWatchStatusUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestWatchStatusUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PullRequestWatchStatus.unknown()';
}


}




/// @nodoc
@JsonSerializable()

class PullRequestWatchStatusNeedsYou implements PullRequestWatchStatus {
  const PullRequestWatchStatusNeedsYou({@JsonKey(unknownEnumValue: PullRequestWatchNeed.unknown) required  List<PullRequestWatchNeed> reasons,  String? $type}): _reasons = reasons,$type = $type ?? 'needsYou';
  factory PullRequestWatchStatusNeedsYou.fromJson(Map<String, dynamic> json) => _$PullRequestWatchStatusNeedsYouFromJson(json);

 final  List<PullRequestWatchNeed> _reasons;
@JsonKey(unknownEnumValue: PullRequestWatchNeed.unknown) List<PullRequestWatchNeed> get reasons {
  if (_reasons is EqualUnmodifiableListView) return _reasons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reasons);
}


@JsonKey(name: 'kind')
final String $type;


/// Create a copy of PullRequestWatchStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestWatchStatusNeedsYouCopyWith<PullRequestWatchStatusNeedsYou> get copyWith => _$PullRequestWatchStatusNeedsYouCopyWithImpl<PullRequestWatchStatusNeedsYou>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestWatchStatusNeedsYouToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestWatchStatusNeedsYou&&const DeepCollectionEquality().equals(other.reasons, _reasons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_reasons));
}

@override
String toString() {
    return 'PullRequestWatchStatus.needsYou(reasons: $reasons)';
}


}

/// @nodoc
abstract mixin class $PullRequestWatchStatusNeedsYouCopyWith<$Res> implements $PullRequestWatchStatusCopyWith<$Res> {
  factory $PullRequestWatchStatusNeedsYouCopyWith(PullRequestWatchStatusNeedsYou value, $Res Function(PullRequestWatchStatusNeedsYou) _then) = _$PullRequestWatchStatusNeedsYouCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: PullRequestWatchNeed.unknown) List<PullRequestWatchNeed> reasons
});




}
/// @nodoc
class _$PullRequestWatchStatusNeedsYouCopyWithImpl<$Res>
    implements $PullRequestWatchStatusNeedsYouCopyWith<$Res> {
  _$PullRequestWatchStatusNeedsYouCopyWithImpl(this._self, this._then);

  final PullRequestWatchStatusNeedsYou _self;
  final $Res Function(PullRequestWatchStatusNeedsYou) _then;

/// Create a copy of PullRequestWatchStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reasons = null,}) {
  return _then(PullRequestWatchStatusNeedsYou(
reasons: null == reasons ? _self._reasons : reasons // ignore: cast_nullable_to_non_nullable
as List<PullRequestWatchNeed>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class PullRequestWatchStatusWaiting implements PullRequestWatchStatus {
  const PullRequestWatchStatusWaiting({ String? $type}): $type = $type ?? 'waiting';
  factory PullRequestWatchStatusWaiting.fromJson(Map<String, dynamic> json) => _$PullRequestWatchStatusWaitingFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PullRequestWatchStatusWaitingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestWatchStatusWaiting);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PullRequestWatchStatus.waiting()';
}


}




/// @nodoc
@JsonSerializable()

class PullRequestWatchStatusReady implements PullRequestWatchStatus {
  const PullRequestWatchStatusReady({ String? $type}): $type = $type ?? 'ready';
  factory PullRequestWatchStatusReady.fromJson(Map<String, dynamic> json) => _$PullRequestWatchStatusReadyFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PullRequestWatchStatusReadyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestWatchStatusReady);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PullRequestWatchStatus.ready()';
}


}




/// @nodoc
@JsonSerializable()

class PullRequestWatchStatusMerged implements PullRequestWatchStatus {
  const PullRequestWatchStatusMerged({required this.mergedAt,  String? $type}): $type = $type ?? 'merged';
  factory PullRequestWatchStatusMerged.fromJson(Map<String, dynamic> json) => _$PullRequestWatchStatusMergedFromJson(json);

 final  int mergedAt;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of PullRequestWatchStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestWatchStatusMergedCopyWith<PullRequestWatchStatusMerged> get copyWith => _$PullRequestWatchStatusMergedCopyWithImpl<PullRequestWatchStatusMerged>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestWatchStatusMergedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestWatchStatusMerged&&(identical(other.mergedAt, mergedAt) || other.mergedAt == mergedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mergedAt);
}

@override
String toString() {
    return 'PullRequestWatchStatus.merged(mergedAt: $mergedAt)';
}


}

/// @nodoc
abstract mixin class $PullRequestWatchStatusMergedCopyWith<$Res> implements $PullRequestWatchStatusCopyWith<$Res> {
  factory $PullRequestWatchStatusMergedCopyWith(PullRequestWatchStatusMerged value, $Res Function(PullRequestWatchStatusMerged) _then) = _$PullRequestWatchStatusMergedCopyWithImpl;
@useResult
$Res call({
 int mergedAt
});




}
/// @nodoc
class _$PullRequestWatchStatusMergedCopyWithImpl<$Res>
    implements $PullRequestWatchStatusMergedCopyWith<$Res> {
  _$PullRequestWatchStatusMergedCopyWithImpl(this._self, this._then);

  final PullRequestWatchStatusMerged _self;
  final $Res Function(PullRequestWatchStatusMerged) _then;

/// Create a copy of PullRequestWatchStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mergedAt = null,}) {
  return _then(PullRequestWatchStatusMerged(
mergedAt: null == mergedAt ? _self.mergedAt : mergedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$PullRequestWatchListResponse {

 List<PullRequestWatchListItem> get watches;
/// Create a copy of PullRequestWatchListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestWatchListResponseCopyWith<PullRequestWatchListResponse> get copyWith => _$PullRequestWatchListResponseCopyWithImpl<PullRequestWatchListResponse>(this as PullRequestWatchListResponse, _$identity);

  /// Serializes this PullRequestWatchListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PullRequestWatchListResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestWatchListResponse&&const DeepCollectionEquality().equals(other.watches, _this.watches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PullRequestWatchListResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.watches));
}

@override
String toString() {
  final _this = this as PullRequestWatchListResponse;
  return 'PullRequestWatchListResponse(watches: ${_this.watches})';
}


}

/// @nodoc
abstract mixin class $PullRequestWatchListResponseCopyWith<$Res>  {
  factory $PullRequestWatchListResponseCopyWith(PullRequestWatchListResponse value, $Res Function(PullRequestWatchListResponse) _then) = _$PullRequestWatchListResponseCopyWithImpl;
@useResult
$Res call({
 List<PullRequestWatchListItem> watches
});




}
/// @nodoc
class _$PullRequestWatchListResponseCopyWithImpl<$Res>
    implements $PullRequestWatchListResponseCopyWith<$Res> {
  _$PullRequestWatchListResponseCopyWithImpl(this._self, this._then);

  final PullRequestWatchListResponse _self;
  final $Res Function(PullRequestWatchListResponse) _then;

/// Create a copy of PullRequestWatchListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? watches = null,}) {
  return _then(PullRequestWatchListResponse(
watches: null == watches ? _self.watches : watches // ignore: cast_nullable_to_non_nullable
as List<PullRequestWatchListItem>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PullRequestWatchListResponse implements PullRequestWatchListResponse {
  const _PullRequestWatchListResponse({required  List<PullRequestWatchListItem> watches}): _watches = watches;
  factory _PullRequestWatchListResponse.fromJson(Map<String, dynamic> json) => _$PullRequestWatchListResponseFromJson(json);

 final  List<PullRequestWatchListItem> _watches;
@override List<PullRequestWatchListItem> get watches {
  if (_watches is EqualUnmodifiableListView) return _watches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_watches);
}


/// Create a copy of PullRequestWatchListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestWatchListResponseCopyWith<_PullRequestWatchListResponse> get copyWith => __$PullRequestWatchListResponseCopyWithImpl<_PullRequestWatchListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestWatchListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestWatchListResponse&&const DeepCollectionEquality().equals(other.watches, _watches));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_watches));
}

@override
String toString() {
    return 'PullRequestWatchListResponse(watches: $watches)';
}


}

/// @nodoc
abstract mixin class _$PullRequestWatchListResponseCopyWith<$Res> implements $PullRequestWatchListResponseCopyWith<$Res> {
  factory _$PullRequestWatchListResponseCopyWith(_PullRequestWatchListResponse value, $Res Function(_PullRequestWatchListResponse) _then) = __$PullRequestWatchListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<PullRequestWatchListItem> watches
});




}
/// @nodoc
class __$PullRequestWatchListResponseCopyWithImpl<$Res>
    implements _$PullRequestWatchListResponseCopyWith<$Res> {
  __$PullRequestWatchListResponseCopyWithImpl(this._self, this._then);

  final _PullRequestWatchListResponse _self;
  final $Res Function(_PullRequestWatchListResponse) _then;

/// Create a copy of PullRequestWatchListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? watches = null,}) {
  return _then(_PullRequestWatchListResponse(
watches: null == watches ? _self._watches : watches // ignore: cast_nullable_to_non_nullable
as List<PullRequestWatchListItem>,
  ));
}


}


/// @nodoc
mixin _$PullRequestWatchListItem {

/// The root session that watches the PR.
 String get sessionId; String? get sessionTitle; String get projectId; SessionPullRequestWatch get watch;
/// Create a copy of PullRequestWatchListItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestWatchListItemCopyWith<PullRequestWatchListItem> get copyWith => _$PullRequestWatchListItemCopyWithImpl<PullRequestWatchListItem>(this as PullRequestWatchListItem, _$identity);

  /// Serializes this PullRequestWatchListItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PullRequestWatchListItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestWatchListItem&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.sessionTitle, _this.sessionTitle) || other.sessionTitle == _this.sessionTitle)&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.watch, _this.watch) || other.watch == _this.watch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PullRequestWatchListItem;
  return Object.hash(runtimeType,_this.sessionId,_this.sessionTitle,_this.projectId,_this.watch);
}

@override
String toString() {
  final _this = this as PullRequestWatchListItem;
  return 'PullRequestWatchListItem(sessionId: ${_this.sessionId}, sessionTitle: ${_this.sessionTitle}, projectId: ${_this.projectId}, watch: ${_this.watch})';
}


}

/// @nodoc
abstract mixin class $PullRequestWatchListItemCopyWith<$Res>  {
  factory $PullRequestWatchListItemCopyWith(PullRequestWatchListItem value, $Res Function(PullRequestWatchListItem) _then) = _$PullRequestWatchListItemCopyWithImpl;
@useResult
$Res call({
 String sessionId, String? sessionTitle, String projectId, SessionPullRequestWatch watch
});


$SessionPullRequestWatchCopyWith<$Res> get watch;

}
/// @nodoc
class _$PullRequestWatchListItemCopyWithImpl<$Res>
    implements $PullRequestWatchListItemCopyWith<$Res> {
  _$PullRequestWatchListItemCopyWithImpl(this._self, this._then);

  final PullRequestWatchListItem _self;
  final $Res Function(PullRequestWatchListItem) _then;

/// Create a copy of PullRequestWatchListItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? sessionTitle = freezed,Object? projectId = null,Object? watch = null,}) {
  return _then(PullRequestWatchListItem(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sessionTitle: freezed == sessionTitle ? _self.sessionTitle : sessionTitle // ignore: cast_nullable_to_non_nullable
as String?,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,watch: null == watch ? _self.watch : watch // ignore: cast_nullable_to_non_nullable
as SessionPullRequestWatch,
  ));
}
/// Create a copy of PullRequestWatchListItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionPullRequestWatchCopyWith<$Res> get watch {
  
  return $SessionPullRequestWatchCopyWith<$Res>(_self.watch, (value) {
    return _then(_self.copyWith(watch: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _PullRequestWatchListItem implements PullRequestWatchListItem {
  const _PullRequestWatchListItem({required this.sessionId, required this.sessionTitle, required this.projectId, required this.watch});
  factory _PullRequestWatchListItem.fromJson(Map<String, dynamic> json) => _$PullRequestWatchListItemFromJson(json);

/// The root session that watches the PR.
@override final  String sessionId;
@override final  String? sessionTitle;
@override final  String projectId;
@override final  SessionPullRequestWatch watch;

/// Create a copy of PullRequestWatchListItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestWatchListItemCopyWith<_PullRequestWatchListItem> get copyWith => __$PullRequestWatchListItemCopyWithImpl<_PullRequestWatchListItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestWatchListItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestWatchListItem&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sessionTitle, sessionTitle) || other.sessionTitle == sessionTitle)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.watch, watch) || other.watch == watch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,sessionTitle,projectId,watch);
}

@override
String toString() {
    return 'PullRequestWatchListItem(sessionId: $sessionId, sessionTitle: $sessionTitle, projectId: $projectId, watch: $watch)';
}


}

/// @nodoc
abstract mixin class _$PullRequestWatchListItemCopyWith<$Res> implements $PullRequestWatchListItemCopyWith<$Res> {
  factory _$PullRequestWatchListItemCopyWith(_PullRequestWatchListItem value, $Res Function(_PullRequestWatchListItem) _then) = __$PullRequestWatchListItemCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String? sessionTitle, String projectId, SessionPullRequestWatch watch
});


@override $SessionPullRequestWatchCopyWith<$Res> get watch;

}
/// @nodoc
class __$PullRequestWatchListItemCopyWithImpl<$Res>
    implements _$PullRequestWatchListItemCopyWith<$Res> {
  __$PullRequestWatchListItemCopyWithImpl(this._self, this._then);

  final _PullRequestWatchListItem _self;
  final $Res Function(_PullRequestWatchListItem) _then;

/// Create a copy of PullRequestWatchListItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? sessionTitle = freezed,Object? projectId = null,Object? watch = null,}) {
  return _then(_PullRequestWatchListItem(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sessionTitle: freezed == sessionTitle ? _self.sessionTitle : sessionTitle // ignore: cast_nullable_to_non_nullable
as String?,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,watch: null == watch ? _self.watch : watch // ignore: cast_nullable_to_non_nullable
as SessionPullRequestWatch,
  ));
}

/// Create a copy of PullRequestWatchListItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionPullRequestWatchCopyWith<$Res> get watch {
  
  return $SessionPullRequestWatchCopyWith<$Res>(_self.watch, (value) {
    return _then(_self.copyWith(watch: value));
  });
}
}


/// @nodoc
mixin _$StopPullRequestWatchRequest {

/// The root session that watches the PR.
 String get sessionId;/// `owner/repo`.
 String get repository; int get number;
/// Create a copy of StopPullRequestWatchRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StopPullRequestWatchRequestCopyWith<StopPullRequestWatchRequest> get copyWith => _$StopPullRequestWatchRequestCopyWithImpl<StopPullRequestWatchRequest>(this as StopPullRequestWatchRequest, _$identity);

  /// Serializes this StopPullRequestWatchRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as StopPullRequestWatchRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StopPullRequestWatchRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.repository, _this.repository) || other.repository == _this.repository)&&(identical(other.number, _this.number) || other.number == _this.number));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as StopPullRequestWatchRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.repository,_this.number);
}

@override
String toString() {
  final _this = this as StopPullRequestWatchRequest;
  return 'StopPullRequestWatchRequest(sessionId: ${_this.sessionId}, repository: ${_this.repository}, number: ${_this.number})';
}


}

/// @nodoc
abstract mixin class $StopPullRequestWatchRequestCopyWith<$Res>  {
  factory $StopPullRequestWatchRequestCopyWith(StopPullRequestWatchRequest value, $Res Function(StopPullRequestWatchRequest) _then) = _$StopPullRequestWatchRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, String repository, int number
});




}
/// @nodoc
class _$StopPullRequestWatchRequestCopyWithImpl<$Res>
    implements $StopPullRequestWatchRequestCopyWith<$Res> {
  _$StopPullRequestWatchRequestCopyWithImpl(this._self, this._then);

  final StopPullRequestWatchRequest _self;
  final $Res Function(StopPullRequestWatchRequest) _then;

/// Create a copy of StopPullRequestWatchRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? repository = null,Object? number = null,}) {
  return _then(StopPullRequestWatchRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,repository: null == repository ? _self.repository : repository // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _StopPullRequestWatchRequest implements StopPullRequestWatchRequest {
  const _StopPullRequestWatchRequest({required this.sessionId, required this.repository, required this.number});
  factory _StopPullRequestWatchRequest.fromJson(Map<String, dynamic> json) => _$StopPullRequestWatchRequestFromJson(json);

/// The root session that watches the PR.
@override final  String sessionId;
/// `owner/repo`.
@override final  String repository;
@override final  int number;

/// Create a copy of StopPullRequestWatchRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StopPullRequestWatchRequestCopyWith<_StopPullRequestWatchRequest> get copyWith => __$StopPullRequestWatchRequestCopyWithImpl<_StopPullRequestWatchRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StopPullRequestWatchRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StopPullRequestWatchRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.repository, repository) || other.repository == repository)&&(identical(other.number, number) || other.number == number));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,repository,number);
}

@override
String toString() {
    return 'StopPullRequestWatchRequest(sessionId: $sessionId, repository: $repository, number: $number)';
}


}

/// @nodoc
abstract mixin class _$StopPullRequestWatchRequestCopyWith<$Res> implements $StopPullRequestWatchRequestCopyWith<$Res> {
  factory _$StopPullRequestWatchRequestCopyWith(_StopPullRequestWatchRequest value, $Res Function(_StopPullRequestWatchRequest) _then) = __$StopPullRequestWatchRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String repository, int number
});




}
/// @nodoc
class __$StopPullRequestWatchRequestCopyWithImpl<$Res>
    implements _$StopPullRequestWatchRequestCopyWith<$Res> {
  __$StopPullRequestWatchRequestCopyWithImpl(this._self, this._then);

  final _StopPullRequestWatchRequest _self;
  final $Res Function(_StopPullRequestWatchRequest) _then;

/// Create a copy of StopPullRequestWatchRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? repository = null,Object? number = null,}) {
  return _then(_StopPullRequestWatchRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,repository: null == repository ? _self.repository : repository // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SetPullRequestWatchAutoMergeRequest {

/// The root session that watches the PR.
 String get sessionId;/// `owner/repo`.
 String get repository; int get number; bool get enabled;
/// Create a copy of SetPullRequestWatchAutoMergeRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetPullRequestWatchAutoMergeRequestCopyWith<SetPullRequestWatchAutoMergeRequest> get copyWith => _$SetPullRequestWatchAutoMergeRequestCopyWithImpl<SetPullRequestWatchAutoMergeRequest>(this as SetPullRequestWatchAutoMergeRequest, _$identity);

  /// Serializes this SetPullRequestWatchAutoMergeRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SetPullRequestWatchAutoMergeRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetPullRequestWatchAutoMergeRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.repository, _this.repository) || other.repository == _this.repository)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SetPullRequestWatchAutoMergeRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.repository,_this.number,_this.enabled);
}

@override
String toString() {
  final _this = this as SetPullRequestWatchAutoMergeRequest;
  return 'SetPullRequestWatchAutoMergeRequest(sessionId: ${_this.sessionId}, repository: ${_this.repository}, number: ${_this.number}, enabled: ${_this.enabled})';
}


}

/// @nodoc
abstract mixin class $SetPullRequestWatchAutoMergeRequestCopyWith<$Res>  {
  factory $SetPullRequestWatchAutoMergeRequestCopyWith(SetPullRequestWatchAutoMergeRequest value, $Res Function(SetPullRequestWatchAutoMergeRequest) _then) = _$SetPullRequestWatchAutoMergeRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, String repository, int number, bool enabled
});




}
/// @nodoc
class _$SetPullRequestWatchAutoMergeRequestCopyWithImpl<$Res>
    implements $SetPullRequestWatchAutoMergeRequestCopyWith<$Res> {
  _$SetPullRequestWatchAutoMergeRequestCopyWithImpl(this._self, this._then);

  final SetPullRequestWatchAutoMergeRequest _self;
  final $Res Function(SetPullRequestWatchAutoMergeRequest) _then;

/// Create a copy of SetPullRequestWatchAutoMergeRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? repository = null,Object? number = null,Object? enabled = null,}) {
  return _then(SetPullRequestWatchAutoMergeRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,repository: null == repository ? _self.repository : repository // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SetPullRequestWatchAutoMergeRequest implements SetPullRequestWatchAutoMergeRequest {
  const _SetPullRequestWatchAutoMergeRequest({required this.sessionId, required this.repository, required this.number, required this.enabled});
  factory _SetPullRequestWatchAutoMergeRequest.fromJson(Map<String, dynamic> json) => _$SetPullRequestWatchAutoMergeRequestFromJson(json);

/// The root session that watches the PR.
@override final  String sessionId;
/// `owner/repo`.
@override final  String repository;
@override final  int number;
@override final  bool enabled;

/// Create a copy of SetPullRequestWatchAutoMergeRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetPullRequestWatchAutoMergeRequestCopyWith<_SetPullRequestWatchAutoMergeRequest> get copyWith => __$SetPullRequestWatchAutoMergeRequestCopyWithImpl<_SetPullRequestWatchAutoMergeRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetPullRequestWatchAutoMergeRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetPullRequestWatchAutoMergeRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.repository, repository) || other.repository == repository)&&(identical(other.number, number) || other.number == number)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,repository,number,enabled);
}

@override
String toString() {
    return 'SetPullRequestWatchAutoMergeRequest(sessionId: $sessionId, repository: $repository, number: $number, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$SetPullRequestWatchAutoMergeRequestCopyWith<$Res> implements $SetPullRequestWatchAutoMergeRequestCopyWith<$Res> {
  factory _$SetPullRequestWatchAutoMergeRequestCopyWith(_SetPullRequestWatchAutoMergeRequest value, $Res Function(_SetPullRequestWatchAutoMergeRequest) _then) = __$SetPullRequestWatchAutoMergeRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String repository, int number, bool enabled
});




}
/// @nodoc
class __$SetPullRequestWatchAutoMergeRequestCopyWithImpl<$Res>
    implements _$SetPullRequestWatchAutoMergeRequestCopyWith<$Res> {
  __$SetPullRequestWatchAutoMergeRequestCopyWithImpl(this._self, this._then);

  final _SetPullRequestWatchAutoMergeRequest _self;
  final $Res Function(_SetPullRequestWatchAutoMergeRequest) _then;

/// Create a copy of SetPullRequestWatchAutoMergeRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? repository = null,Object? number = null,Object? enabled = null,}) {
  return _then(_SetPullRequestWatchAutoMergeRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,repository: null == repository ? _self.repository : repository // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
