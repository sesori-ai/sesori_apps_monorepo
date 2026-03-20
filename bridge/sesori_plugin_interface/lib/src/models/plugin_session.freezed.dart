// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginSession {

 String get id; String get projectID; String get directory; String? get parentID; String? get title; PluginSessionTime? get time; PluginSessionSummary? get summary;
/// Create a copy of PluginSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSessionCopyWith<PluginSession> get copyWith => _$PluginSessionCopyWithImpl<PluginSession>(this as PluginSession, _$identity);

  /// Serializes this PluginSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSession&&(identical(other.id, id) || other.id == id)&&(identical(other.projectID, projectID) || other.projectID == projectID)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.parentID, parentID) || other.parentID == parentID)&&(identical(other.title, title) || other.title == title)&&(identical(other.time, time) || other.time == time)&&(identical(other.summary, summary) || other.summary == summary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,projectID,directory,parentID,title,time,summary);

@override
String toString() {
  return 'PluginSession(id: $id, projectID: $projectID, directory: $directory, parentID: $parentID, title: $title, time: $time, summary: $summary)';
}


}

/// @nodoc
abstract mixin class $PluginSessionCopyWith<$Res>  {
  factory $PluginSessionCopyWith(PluginSession value, $Res Function(PluginSession) _then) = _$PluginSessionCopyWithImpl;
@useResult
$Res call({
 String id, String projectID, String directory, String? parentID, String? title, PluginSessionTime? time, PluginSessionSummary? summary
});


$PluginSessionTimeCopyWith<$Res>? get time;$PluginSessionSummaryCopyWith<$Res>? get summary;

}
/// @nodoc
class _$PluginSessionCopyWithImpl<$Res>
    implements $PluginSessionCopyWith<$Res> {
  _$PluginSessionCopyWithImpl(this._self, this._then);

  final PluginSession _self;
  final $Res Function(PluginSession) _then;

/// Create a copy of PluginSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? projectID = null,Object? directory = null,Object? parentID = freezed,Object? title = freezed,Object? time = freezed,Object? summary = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectID: null == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,parentID: freezed == parentID ? _self.parentID : parentID // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PluginSessionTime?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as PluginSessionSummary?,
  ));
}
/// Create a copy of PluginSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginSessionTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PluginSessionTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of PluginSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginSessionSummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $PluginSessionSummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginSession implements PluginSession {
  const _PluginSession({required this.id, required this.projectID, required this.directory, required this.parentID, required this.title, required this.time, required this.summary});
  

@override final  String id;
@override final  String projectID;
@override final  String directory;
@override final  String? parentID;
@override final  String? title;
@override final  PluginSessionTime? time;
@override final  PluginSessionSummary? summary;

/// Create a copy of PluginSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSessionCopyWith<_PluginSession> get copyWith => __$PluginSessionCopyWithImpl<_PluginSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSession&&(identical(other.id, id) || other.id == id)&&(identical(other.projectID, projectID) || other.projectID == projectID)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.parentID, parentID) || other.parentID == parentID)&&(identical(other.title, title) || other.title == title)&&(identical(other.time, time) || other.time == time)&&(identical(other.summary, summary) || other.summary == summary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,projectID,directory,parentID,title,time,summary);

@override
String toString() {
  return 'PluginSession(id: $id, projectID: $projectID, directory: $directory, parentID: $parentID, title: $title, time: $time, summary: $summary)';
}


}

/// @nodoc
abstract mixin class _$PluginSessionCopyWith<$Res> implements $PluginSessionCopyWith<$Res> {
  factory _$PluginSessionCopyWith(_PluginSession value, $Res Function(_PluginSession) _then) = __$PluginSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String projectID, String directory, String? parentID, String? title, PluginSessionTime? time, PluginSessionSummary? summary
});


@override $PluginSessionTimeCopyWith<$Res>? get time;@override $PluginSessionSummaryCopyWith<$Res>? get summary;

}
/// @nodoc
class __$PluginSessionCopyWithImpl<$Res>
    implements _$PluginSessionCopyWith<$Res> {
  __$PluginSessionCopyWithImpl(this._self, this._then);

  final _PluginSession _self;
  final $Res Function(_PluginSession) _then;

/// Create a copy of PluginSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? projectID = null,Object? directory = null,Object? parentID = freezed,Object? title = freezed,Object? time = freezed,Object? summary = freezed,}) {
  return _then(_PluginSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectID: null == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,parentID: freezed == parentID ? _self.parentID : parentID // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PluginSessionTime?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as PluginSessionSummary?,
  ));
}

/// Create a copy of PluginSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginSessionTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PluginSessionTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of PluginSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginSessionSummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $PluginSessionSummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}

/// @nodoc
mixin _$PluginSessionTime {

 int get created; int get updated; int? get archived;
/// Create a copy of PluginSessionTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSessionTimeCopyWith<PluginSessionTime> get copyWith => _$PluginSessionTimeCopyWithImpl<PluginSessionTime>(this as PluginSessionTime, _$identity);

  /// Serializes this PluginSessionTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.archived, archived) || other.archived == archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated,archived);

@override
String toString() {
  return 'PluginSessionTime(created: $created, updated: $updated, archived: $archived)';
}


}

/// @nodoc
abstract mixin class $PluginSessionTimeCopyWith<$Res>  {
  factory $PluginSessionTimeCopyWith(PluginSessionTime value, $Res Function(PluginSessionTime) _then) = _$PluginSessionTimeCopyWithImpl;
@useResult
$Res call({
 int created, int updated, int? archived
});




}
/// @nodoc
class _$PluginSessionTimeCopyWithImpl<$Res>
    implements $PluginSessionTimeCopyWith<$Res> {
  _$PluginSessionTimeCopyWithImpl(this._self, this._then);

  final PluginSessionTime _self;
  final $Res Function(PluginSessionTime) _then;

/// Create a copy of PluginSessionTime
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
@JsonSerializable(createFactory: false)

class _PluginSessionTime implements PluginSessionTime {
  const _PluginSessionTime({required this.created, required this.updated, required this.archived});
  

@override final  int created;
@override final  int updated;
@override final  int? archived;

/// Create a copy of PluginSessionTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSessionTimeCopyWith<_PluginSessionTime> get copyWith => __$PluginSessionTimeCopyWithImpl<_PluginSessionTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSessionTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSessionTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.archived, archived) || other.archived == archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated,archived);

@override
String toString() {
  return 'PluginSessionTime(created: $created, updated: $updated, archived: $archived)';
}


}

/// @nodoc
abstract mixin class _$PluginSessionTimeCopyWith<$Res> implements $PluginSessionTimeCopyWith<$Res> {
  factory _$PluginSessionTimeCopyWith(_PluginSessionTime value, $Res Function(_PluginSessionTime) _then) = __$PluginSessionTimeCopyWithImpl;
@override @useResult
$Res call({
 int created, int updated, int? archived
});




}
/// @nodoc
class __$PluginSessionTimeCopyWithImpl<$Res>
    implements _$PluginSessionTimeCopyWith<$Res> {
  __$PluginSessionTimeCopyWithImpl(this._self, this._then);

  final _PluginSessionTime _self;
  final $Res Function(_PluginSessionTime) _then;

/// Create a copy of PluginSessionTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,Object? updated = null,Object? archived = freezed,}) {
  return _then(_PluginSessionTime(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,archived: freezed == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$PluginSessionSummary {

 int get additions; int get deletions; int get files;
/// Create a copy of PluginSessionSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSessionSummaryCopyWith<PluginSessionSummary> get copyWith => _$PluginSessionSummaryCopyWithImpl<PluginSessionSummary>(this as PluginSessionSummary, _$identity);

  /// Serializes this PluginSessionSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionSummary&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.files, files) || other.files == files));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,additions,deletions,files);

@override
String toString() {
  return 'PluginSessionSummary(additions: $additions, deletions: $deletions, files: $files)';
}


}

/// @nodoc
abstract mixin class $PluginSessionSummaryCopyWith<$Res>  {
  factory $PluginSessionSummaryCopyWith(PluginSessionSummary value, $Res Function(PluginSessionSummary) _then) = _$PluginSessionSummaryCopyWithImpl;
@useResult
$Res call({
 int additions, int deletions, int files
});




}
/// @nodoc
class _$PluginSessionSummaryCopyWithImpl<$Res>
    implements $PluginSessionSummaryCopyWith<$Res> {
  _$PluginSessionSummaryCopyWithImpl(this._self, this._then);

  final PluginSessionSummary _self;
  final $Res Function(PluginSessionSummary) _then;

/// Create a copy of PluginSessionSummary
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
@JsonSerializable(createFactory: false)

class _PluginSessionSummary implements PluginSessionSummary {
  const _PluginSessionSummary({required this.additions, required this.deletions, required this.files});
  

@override final  int additions;
@override final  int deletions;
@override final  int files;

/// Create a copy of PluginSessionSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSessionSummaryCopyWith<_PluginSessionSummary> get copyWith => __$PluginSessionSummaryCopyWithImpl<_PluginSessionSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSessionSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSessionSummary&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.files, files) || other.files == files));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,additions,deletions,files);

@override
String toString() {
  return 'PluginSessionSummary(additions: $additions, deletions: $deletions, files: $files)';
}


}

/// @nodoc
abstract mixin class _$PluginSessionSummaryCopyWith<$Res> implements $PluginSessionSummaryCopyWith<$Res> {
  factory _$PluginSessionSummaryCopyWith(_PluginSessionSummary value, $Res Function(_PluginSessionSummary) _then) = __$PluginSessionSummaryCopyWithImpl;
@override @useResult
$Res call({
 int additions, int deletions, int files
});




}
/// @nodoc
class __$PluginSessionSummaryCopyWithImpl<$Res>
    implements _$PluginSessionSummaryCopyWith<$Res> {
  __$PluginSessionSummaryCopyWithImpl(this._self, this._then);

  final _PluginSessionSummary _self;
  final $Res Function(_PluginSessionSummary) _then;

/// Create a copy of PluginSessionSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? additions = null,Object? deletions = null,Object? files = null,}) {
  return _then(_PluginSessionSummary(
additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
