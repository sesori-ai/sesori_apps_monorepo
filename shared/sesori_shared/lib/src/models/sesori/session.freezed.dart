// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionListResponse {

 List<Session> get items;
/// Create a copy of SessionListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListResponseCopyWith<SessionListResponse> get copyWith => _$SessionListResponseCopyWithImpl<SessionListResponse>(this as SessionListResponse, _$identity);

  /// Serializes this SessionListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListResponse&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'SessionListResponse(items: $items)';
}


}

/// @nodoc
abstract mixin class $SessionListResponseCopyWith<$Res>  {
  factory $SessionListResponseCopyWith(SessionListResponse value, $Res Function(SessionListResponse) _then) = _$SessionListResponseCopyWithImpl;
@useResult
$Res call({
 List<Session> items
});




}
/// @nodoc
class _$SessionListResponseCopyWithImpl<$Res>
    implements $SessionListResponseCopyWith<$Res> {
  _$SessionListResponseCopyWithImpl(this._self, this._then);

  final SessionListResponse _self;
  final $Res Function(SessionListResponse) _then;

/// Create a copy of SessionListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Session>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionListResponse implements SessionListResponse {
  const _SessionListResponse({required final  List<Session> items}): _items = items;
  factory _SessionListResponse.fromJson(Map<String, dynamic> json) => _$SessionListResponseFromJson(json);

 final  List<Session> _items;
@override List<Session> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of SessionListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionListResponseCopyWith<_SessionListResponse> get copyWith => __$SessionListResponseCopyWithImpl<_SessionListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionListResponse&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'SessionListResponse(items: $items)';
}


}

/// @nodoc
abstract mixin class _$SessionListResponseCopyWith<$Res> implements $SessionListResponseCopyWith<$Res> {
  factory _$SessionListResponseCopyWith(_SessionListResponse value, $Res Function(_SessionListResponse) _then) = __$SessionListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<Session> items
});




}
/// @nodoc
class __$SessionListResponseCopyWithImpl<$Res>
    implements _$SessionListResponseCopyWith<$Res> {
  __$SessionListResponseCopyWithImpl(this._self, this._then);

  final _SessionListResponse _self;
  final $Res Function(_SessionListResponse) _then;

/// Create a copy of SessionListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(_SessionListResponse(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Session>,
  ));
}


}


/// @nodoc
mixin _$SessionListRequest {

 String get projectId; int? get start; int? get limit;
/// Create a copy of SessionListRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListRequestCopyWith<SessionListRequest> get copyWith => _$SessionListRequestCopyWithImpl<SessionListRequest>(this as SessionListRequest, _$identity);

  /// Serializes this SessionListRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.start, start) || other.start == start)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,start,limit);

@override
String toString() {
  return 'SessionListRequest(projectId: $projectId, start: $start, limit: $limit)';
}


}

/// @nodoc
abstract mixin class $SessionListRequestCopyWith<$Res>  {
  factory $SessionListRequestCopyWith(SessionListRequest value, $Res Function(SessionListRequest) _then) = _$SessionListRequestCopyWithImpl;
@useResult
$Res call({
 String projectId, int? start, int? limit
});




}
/// @nodoc
class _$SessionListRequestCopyWithImpl<$Res>
    implements $SessionListRequestCopyWith<$Res> {
  _$SessionListRequestCopyWithImpl(this._self, this._then);

  final SessionListRequest _self;
  final $Res Function(SessionListRequest) _then;

/// Create a copy of SessionListRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? start = freezed,Object? limit = freezed,}) {
  return _then(_self.copyWith(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionListRequest implements SessionListRequest {
  const _SessionListRequest({required this.projectId, required this.start, required this.limit});
  factory _SessionListRequest.fromJson(Map<String, dynamic> json) => _$SessionListRequestFromJson(json);

@override final  String projectId;
@override final  int? start;
@override final  int? limit;

/// Create a copy of SessionListRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionListRequestCopyWith<_SessionListRequest> get copyWith => __$SessionListRequestCopyWithImpl<_SessionListRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionListRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionListRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.start, start) || other.start == start)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,start,limit);

@override
String toString() {
  return 'SessionListRequest(projectId: $projectId, start: $start, limit: $limit)';
}


}

/// @nodoc
abstract mixin class _$SessionListRequestCopyWith<$Res> implements $SessionListRequestCopyWith<$Res> {
  factory _$SessionListRequestCopyWith(_SessionListRequest value, $Res Function(_SessionListRequest) _then) = __$SessionListRequestCopyWithImpl;
@override @useResult
$Res call({
 String projectId, int? start, int? limit
});




}
/// @nodoc
class __$SessionListRequestCopyWithImpl<$Res>
    implements _$SessionListRequestCopyWith<$Res> {
  __$SessionListRequestCopyWithImpl(this._self, this._then);

  final _SessionListRequest _self;
  final $Res Function(_SessionListRequest) _then;

/// Create a copy of SessionListRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? start = freezed,Object? limit = freezed,}) {
  return _then(_SessionListRequest(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$Session {

 String get id; String get projectID; String get directory; String? get parentID; String? get title; SessionTime? get time; SessionSummary? get summary;
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCopyWith<Session> get copyWith => _$SessionCopyWithImpl<Session>(this as Session, _$identity);

  /// Serializes this Session to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Session&&(identical(other.id, id) || other.id == id)&&(identical(other.projectID, projectID) || other.projectID == projectID)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.parentID, parentID) || other.parentID == parentID)&&(identical(other.title, title) || other.title == title)&&(identical(other.time, time) || other.time == time)&&(identical(other.summary, summary) || other.summary == summary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,projectID,directory,parentID,title,time,summary);

@override
String toString() {
  return 'Session(id: $id, projectID: $projectID, directory: $directory, parentID: $parentID, title: $title, time: $time, summary: $summary)';
}


}

/// @nodoc
abstract mixin class $SessionCopyWith<$Res>  {
  factory $SessionCopyWith(Session value, $Res Function(Session) _then) = _$SessionCopyWithImpl;
@useResult
$Res call({
 String id, String projectID, String directory, String? parentID, String? title, SessionTime? time, SessionSummary? summary
});


$SessionTimeCopyWith<$Res>? get time;$SessionSummaryCopyWith<$Res>? get summary;

}
/// @nodoc
class _$SessionCopyWithImpl<$Res>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._self, this._then);

  final Session _self;
  final $Res Function(Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? projectID = null,Object? directory = null,Object? parentID = freezed,Object? title = freezed,Object? time = freezed,Object? summary = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectID: null == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,parentID: freezed == parentID ? _self.parentID : parentID // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as SessionTime?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as SessionSummary?,
  ));
}
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $SessionTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionSummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $SessionSummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _Session implements Session {
  const _Session({required this.id, required this.projectID, required this.directory, required this.parentID, required this.title, required this.time, required this.summary});
  factory _Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);

@override final  String id;
@override final  String projectID;
@override final  String directory;
@override final  String? parentID;
@override final  String? title;
@override final  SessionTime? time;
@override final  SessionSummary? summary;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCopyWith<_Session> get copyWith => __$SessionCopyWithImpl<_Session>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Session&&(identical(other.id, id) || other.id == id)&&(identical(other.projectID, projectID) || other.projectID == projectID)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.parentID, parentID) || other.parentID == parentID)&&(identical(other.title, title) || other.title == title)&&(identical(other.time, time) || other.time == time)&&(identical(other.summary, summary) || other.summary == summary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,projectID,directory,parentID,title,time,summary);

@override
String toString() {
  return 'Session(id: $id, projectID: $projectID, directory: $directory, parentID: $parentID, title: $title, time: $time, summary: $summary)';
}


}

/// @nodoc
abstract mixin class _$SessionCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$SessionCopyWith(_Session value, $Res Function(_Session) _then) = __$SessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String projectID, String directory, String? parentID, String? title, SessionTime? time, SessionSummary? summary
});


@override $SessionTimeCopyWith<$Res>? get time;@override $SessionSummaryCopyWith<$Res>? get summary;

}
/// @nodoc
class __$SessionCopyWithImpl<$Res>
    implements _$SessionCopyWith<$Res> {
  __$SessionCopyWithImpl(this._self, this._then);

  final _Session _self;
  final $Res Function(_Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? projectID = null,Object? directory = null,Object? parentID = freezed,Object? title = freezed,Object? time = freezed,Object? summary = freezed,}) {
  return _then(_Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectID: null == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,parentID: freezed == parentID ? _self.parentID : parentID // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as SessionTime?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as SessionSummary?,
  ));
}

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $SessionTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionSummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $SessionSummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}


/// @nodoc
mixin _$SessionTime {

 int get created; int get updated; int? get archived;
/// Create a copy of SessionTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionTimeCopyWith<SessionTime> get copyWith => _$SessionTimeCopyWithImpl<SessionTime>(this as SessionTime, _$identity);

  /// Serializes this SessionTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.archived, archived) || other.archived == archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated,archived);

@override
String toString() {
  return 'SessionTime(created: $created, updated: $updated, archived: $archived)';
}


}

/// @nodoc
abstract mixin class $SessionTimeCopyWith<$Res>  {
  factory $SessionTimeCopyWith(SessionTime value, $Res Function(SessionTime) _then) = _$SessionTimeCopyWithImpl;
@useResult
$Res call({
 int created, int updated, int? archived
});




}
/// @nodoc
class _$SessionTimeCopyWithImpl<$Res>
    implements $SessionTimeCopyWith<$Res> {
  _$SessionTimeCopyWithImpl(this._self, this._then);

  final SessionTime _self;
  final $Res Function(SessionTime) _then;

/// Create a copy of SessionTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? created = null,Object? updated = null,Object? archived = freezed,}) {
  return _then(_self.copyWith(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,archived: freezed == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionTime implements SessionTime {
  const _SessionTime({required this.created, required this.updated, required this.archived});
  factory _SessionTime.fromJson(Map<String, dynamic> json) => _$SessionTimeFromJson(json);

@override final  int created;
@override final  int updated;
@override final  int? archived;

/// Create a copy of SessionTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionTimeCopyWith<_SessionTime> get copyWith => __$SessionTimeCopyWithImpl<_SessionTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.archived, archived) || other.archived == archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated,archived);

@override
String toString() {
  return 'SessionTime(created: $created, updated: $updated, archived: $archived)';
}


}

/// @nodoc
abstract mixin class _$SessionTimeCopyWith<$Res> implements $SessionTimeCopyWith<$Res> {
  factory _$SessionTimeCopyWith(_SessionTime value, $Res Function(_SessionTime) _then) = __$SessionTimeCopyWithImpl;
@override @useResult
$Res call({
 int created, int updated, int? archived
});




}
/// @nodoc
class __$SessionTimeCopyWithImpl<$Res>
    implements _$SessionTimeCopyWith<$Res> {
  __$SessionTimeCopyWithImpl(this._self, this._then);

  final _SessionTime _self;
  final $Res Function(_SessionTime) _then;

/// Create a copy of SessionTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,Object? updated = null,Object? archived = freezed,}) {
  return _then(_SessionTime(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,archived: freezed == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$SessionSummary {

 int get additions; int get deletions; int get files;
/// Create a copy of SessionSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionSummaryCopyWith<SessionSummary> get copyWith => _$SessionSummaryCopyWithImpl<SessionSummary>(this as SessionSummary, _$identity);

  /// Serializes this SessionSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionSummary&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.files, files) || other.files == files));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,additions,deletions,files);

@override
String toString() {
  return 'SessionSummary(additions: $additions, deletions: $deletions, files: $files)';
}


}

/// @nodoc
abstract mixin class $SessionSummaryCopyWith<$Res>  {
  factory $SessionSummaryCopyWith(SessionSummary value, $Res Function(SessionSummary) _then) = _$SessionSummaryCopyWithImpl;
@useResult
$Res call({
 int additions, int deletions, int files
});




}
/// @nodoc
class _$SessionSummaryCopyWithImpl<$Res>
    implements $SessionSummaryCopyWith<$Res> {
  _$SessionSummaryCopyWithImpl(this._self, this._then);

  final SessionSummary _self;
  final $Res Function(SessionSummary) _then;

/// Create a copy of SessionSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? additions = null,Object? deletions = null,Object? files = null,}) {
  return _then(_self.copyWith(
additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionSummary implements SessionSummary {
  const _SessionSummary({this.additions = 0, this.deletions = 0, this.files = 0});
  factory _SessionSummary.fromJson(Map<String, dynamic> json) => _$SessionSummaryFromJson(json);

@override@JsonKey() final  int additions;
@override@JsonKey() final  int deletions;
@override@JsonKey() final  int files;

/// Create a copy of SessionSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionSummaryCopyWith<_SessionSummary> get copyWith => __$SessionSummaryCopyWithImpl<_SessionSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionSummary&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.files, files) || other.files == files));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,additions,deletions,files);

@override
String toString() {
  return 'SessionSummary(additions: $additions, deletions: $deletions, files: $files)';
}


}

/// @nodoc
abstract mixin class _$SessionSummaryCopyWith<$Res> implements $SessionSummaryCopyWith<$Res> {
  factory _$SessionSummaryCopyWith(_SessionSummary value, $Res Function(_SessionSummary) _then) = __$SessionSummaryCopyWithImpl;
@override @useResult
$Res call({
 int additions, int deletions, int files
});




}
/// @nodoc
class __$SessionSummaryCopyWithImpl<$Res>
    implements _$SessionSummaryCopyWith<$Res> {
  __$SessionSummaryCopyWithImpl(this._self, this._then);

  final _SessionSummary _self;
  final $Res Function(_SessionSummary) _then;

/// Create a copy of SessionSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? additions = null,Object? deletions = null,Object? files = null,}) {
  return _then(_SessionSummary(
additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$GlobalSession {

 String get id; String get projectID; String get directory; String? get parentID; String? get title; SessionTime? get time; SessionSummary? get summary; SessionProject? get project;
/// Create a copy of GlobalSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GlobalSessionCopyWith<GlobalSession> get copyWith => _$GlobalSessionCopyWithImpl<GlobalSession>(this as GlobalSession, _$identity);

  /// Serializes this GlobalSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GlobalSession&&(identical(other.id, id) || other.id == id)&&(identical(other.projectID, projectID) || other.projectID == projectID)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.parentID, parentID) || other.parentID == parentID)&&(identical(other.title, title) || other.title == title)&&(identical(other.time, time) || other.time == time)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.project, project) || other.project == project));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,projectID,directory,parentID,title,time,summary,project);

@override
String toString() {
  return 'GlobalSession(id: $id, projectID: $projectID, directory: $directory, parentID: $parentID, title: $title, time: $time, summary: $summary, project: $project)';
}


}

/// @nodoc
abstract mixin class $GlobalSessionCopyWith<$Res>  {
  factory $GlobalSessionCopyWith(GlobalSession value, $Res Function(GlobalSession) _then) = _$GlobalSessionCopyWithImpl;
@useResult
$Res call({
 String id, String projectID, String directory, String? parentID, String? title, SessionTime? time, SessionSummary? summary, SessionProject? project
});


$SessionTimeCopyWith<$Res>? get time;$SessionSummaryCopyWith<$Res>? get summary;$SessionProjectCopyWith<$Res>? get project;

}
/// @nodoc
class _$GlobalSessionCopyWithImpl<$Res>
    implements $GlobalSessionCopyWith<$Res> {
  _$GlobalSessionCopyWithImpl(this._self, this._then);

  final GlobalSession _self;
  final $Res Function(GlobalSession) _then;

/// Create a copy of GlobalSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? projectID = null,Object? directory = null,Object? parentID = freezed,Object? title = freezed,Object? time = freezed,Object? summary = freezed,Object? project = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectID: null == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,parentID: freezed == parentID ? _self.parentID : parentID // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as SessionTime?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as SessionSummary?,project: freezed == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as SessionProject?,
  ));
}
/// Create a copy of GlobalSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $SessionTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of GlobalSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionSummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $SessionSummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of GlobalSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionProjectCopyWith<$Res>? get project {
    if (_self.project == null) {
    return null;
  }

  return $SessionProjectCopyWith<$Res>(_self.project!, (value) {
    return _then(_self.copyWith(project: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _GlobalSession implements GlobalSession {
  const _GlobalSession({required this.id, required this.projectID, required this.directory, required this.parentID, required this.title, required this.time, required this.summary, required this.project});
  factory _GlobalSession.fromJson(Map<String, dynamic> json) => _$GlobalSessionFromJson(json);

@override final  String id;
@override final  String projectID;
@override final  String directory;
@override final  String? parentID;
@override final  String? title;
@override final  SessionTime? time;
@override final  SessionSummary? summary;
@override final  SessionProject? project;

/// Create a copy of GlobalSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GlobalSessionCopyWith<_GlobalSession> get copyWith => __$GlobalSessionCopyWithImpl<_GlobalSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GlobalSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GlobalSession&&(identical(other.id, id) || other.id == id)&&(identical(other.projectID, projectID) || other.projectID == projectID)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.parentID, parentID) || other.parentID == parentID)&&(identical(other.title, title) || other.title == title)&&(identical(other.time, time) || other.time == time)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.project, project) || other.project == project));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,projectID,directory,parentID,title,time,summary,project);

@override
String toString() {
  return 'GlobalSession(id: $id, projectID: $projectID, directory: $directory, parentID: $parentID, title: $title, time: $time, summary: $summary, project: $project)';
}


}

/// @nodoc
abstract mixin class _$GlobalSessionCopyWith<$Res> implements $GlobalSessionCopyWith<$Res> {
  factory _$GlobalSessionCopyWith(_GlobalSession value, $Res Function(_GlobalSession) _then) = __$GlobalSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String projectID, String directory, String? parentID, String? title, SessionTime? time, SessionSummary? summary, SessionProject? project
});


@override $SessionTimeCopyWith<$Res>? get time;@override $SessionSummaryCopyWith<$Res>? get summary;@override $SessionProjectCopyWith<$Res>? get project;

}
/// @nodoc
class __$GlobalSessionCopyWithImpl<$Res>
    implements _$GlobalSessionCopyWith<$Res> {
  __$GlobalSessionCopyWithImpl(this._self, this._then);

  final _GlobalSession _self;
  final $Res Function(_GlobalSession) _then;

/// Create a copy of GlobalSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? projectID = null,Object? directory = null,Object? parentID = freezed,Object? title = freezed,Object? time = freezed,Object? summary = freezed,Object? project = freezed,}) {
  return _then(_GlobalSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectID: null == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,parentID: freezed == parentID ? _self.parentID : parentID // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as SessionTime?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as SessionSummary?,project: freezed == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as SessionProject?,
  ));
}

/// Create a copy of GlobalSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $SessionTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of GlobalSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionSummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $SessionSummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of GlobalSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionProjectCopyWith<$Res>? get project {
    if (_self.project == null) {
    return null;
  }

  return $SessionProjectCopyWith<$Res>(_self.project!, (value) {
    return _then(_self.copyWith(project: value));
  });
}
}


/// @nodoc
mixin _$SessionProject {

 String get id; String? get name; String get worktree;
/// Create a copy of SessionProject
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionProjectCopyWith<SessionProject> get copyWith => _$SessionProjectCopyWithImpl<SessionProject>(this as SessionProject, _$identity);

  /// Serializes this SessionProject to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionProject&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.worktree, worktree) || other.worktree == worktree));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,worktree);

@override
String toString() {
  return 'SessionProject(id: $id, name: $name, worktree: $worktree)';
}


}

/// @nodoc
abstract mixin class $SessionProjectCopyWith<$Res>  {
  factory $SessionProjectCopyWith(SessionProject value, $Res Function(SessionProject) _then) = _$SessionProjectCopyWithImpl;
@useResult
$Res call({
 String id, String? name, String worktree
});




}
/// @nodoc
class _$SessionProjectCopyWithImpl<$Res>
    implements $SessionProjectCopyWith<$Res> {
  _$SessionProjectCopyWithImpl(this._self, this._then);

  final SessionProject _self;
  final $Res Function(SessionProject) _then;

/// Create a copy of SessionProject
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? worktree = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,worktree: null == worktree ? _self.worktree : worktree // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionProject implements SessionProject {
  const _SessionProject({required this.id, required this.name, required this.worktree});
  factory _SessionProject.fromJson(Map<String, dynamic> json) => _$SessionProjectFromJson(json);

@override final  String id;
@override final  String? name;
@override final  String worktree;

/// Create a copy of SessionProject
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionProjectCopyWith<_SessionProject> get copyWith => __$SessionProjectCopyWithImpl<_SessionProject>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionProjectToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionProject&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.worktree, worktree) || other.worktree == worktree));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,worktree);

@override
String toString() {
  return 'SessionProject(id: $id, name: $name, worktree: $worktree)';
}


}

/// @nodoc
abstract mixin class _$SessionProjectCopyWith<$Res> implements $SessionProjectCopyWith<$Res> {
  factory _$SessionProjectCopyWith(_SessionProject value, $Res Function(_SessionProject) _then) = __$SessionProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, String worktree
});




}
/// @nodoc
class __$SessionProjectCopyWithImpl<$Res>
    implements _$SessionProjectCopyWith<$Res> {
  __$SessionProjectCopyWithImpl(this._self, this._then);

  final _SessionProject _self;
  final $Res Function(_SessionProject) _then;

/// Create a copy of SessionProject
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? worktree = null,}) {
  return _then(_SessionProject(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,worktree: null == worktree ? _self.worktree : worktree // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SessionIdRequest {

 String get sessionId;
/// Create a copy of SessionIdRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionIdRequestCopyWith<SessionIdRequest> get copyWith => _$SessionIdRequestCopyWithImpl<SessionIdRequest>(this as SessionIdRequest, _$identity);

  /// Serializes this SessionIdRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionIdRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'SessionIdRequest(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $SessionIdRequestCopyWith<$Res>  {
  factory $SessionIdRequestCopyWith(SessionIdRequest value, $Res Function(SessionIdRequest) _then) = _$SessionIdRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class _$SessionIdRequestCopyWithImpl<$Res>
    implements $SessionIdRequestCopyWith<$Res> {
  _$SessionIdRequestCopyWithImpl(this._self, this._then);

  final SessionIdRequest _self;
  final $Res Function(SessionIdRequest) _then;

/// Create a copy of SessionIdRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionIdRequest implements SessionIdRequest {
  const _SessionIdRequest({required this.sessionId});
  factory _SessionIdRequest.fromJson(Map<String, dynamic> json) => _$SessionIdRequestFromJson(json);

@override final  String sessionId;

/// Create a copy of SessionIdRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionIdRequestCopyWith<_SessionIdRequest> get copyWith => __$SessionIdRequestCopyWithImpl<_SessionIdRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionIdRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionIdRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'SessionIdRequest(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class _$SessionIdRequestCopyWith<$Res> implements $SessionIdRequestCopyWith<$Res> {
  factory _$SessionIdRequestCopyWith(_SessionIdRequest value, $Res Function(_SessionIdRequest) _then) = __$SessionIdRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class __$SessionIdRequestCopyWithImpl<$Res>
    implements _$SessionIdRequestCopyWith<$Res> {
  __$SessionIdRequestCopyWithImpl(this._self, this._then);

  final _SessionIdRequest _self;
  final $Res Function(_SessionIdRequest) _then;

/// Create a copy of SessionIdRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,}) {
  return _then(_SessionIdRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
