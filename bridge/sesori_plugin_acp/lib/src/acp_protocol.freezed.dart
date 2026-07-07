// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'acp_protocol.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AcpSessionInfo {

 String get sessionId;/// The session's working directory. Required by the spec, but kept
/// nullable — a missing value falls back to the directory the caller
/// scanned.
 String? get cwd; String? get title;/// Last-activity time in epoch milliseconds (see [AcpTimestampMsConverter]).
@AcpTimestampMsConverter()@JsonKey(name: "updatedAt") int? get updatedAtMs;
/// Create a copy of AcpSessionInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpSessionInfoCopyWith<AcpSessionInfo> get copyWith => _$AcpSessionInfoCopyWithImpl<AcpSessionInfo>(this as AcpSessionInfo, _$identity);

  /// Serializes this AcpSessionInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpSessionInfo&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.title, title) || other.title == title)&&(identical(other.updatedAtMs, updatedAtMs) || other.updatedAtMs == updatedAtMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,cwd,title,updatedAtMs);

@override
String toString() {
  return 'AcpSessionInfo(sessionId: $sessionId, cwd: $cwd, title: $title, updatedAtMs: $updatedAtMs)';
}


}

/// @nodoc
abstract mixin class $AcpSessionInfoCopyWith<$Res>  {
  factory $AcpSessionInfoCopyWith(AcpSessionInfo value, $Res Function(AcpSessionInfo) _then) = _$AcpSessionInfoCopyWithImpl;
@useResult
$Res call({
 String sessionId, String? cwd, String? title,@AcpTimestampMsConverter()@JsonKey(name: "updatedAt") int? updatedAtMs
});




}
/// @nodoc
class _$AcpSessionInfoCopyWithImpl<$Res>
    implements $AcpSessionInfoCopyWith<$Res> {
  _$AcpSessionInfoCopyWithImpl(this._self, this._then);

  final AcpSessionInfo _self;
  final $Res Function(AcpSessionInfo) _then;

/// Create a copy of AcpSessionInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? cwd = freezed,Object? title = freezed,Object? updatedAtMs = freezed,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,updatedAtMs: freezed == updatedAtMs ? _self.updatedAtMs : updatedAtMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _AcpSessionInfo implements AcpSessionInfo {
  const _AcpSessionInfo({this.sessionId = "", required this.cwd, required this.title, @AcpTimestampMsConverter()@JsonKey(name: "updatedAt") required this.updatedAtMs});
  factory _AcpSessionInfo.fromJson(Map<String, dynamic> json) => _$AcpSessionInfoFromJson(json);

@override@JsonKey() final  String sessionId;
/// The session's working directory. Required by the spec, but kept
/// nullable — a missing value falls back to the directory the caller
/// scanned.
@override final  String? cwd;
@override final  String? title;
/// Last-activity time in epoch milliseconds (see [AcpTimestampMsConverter]).
@override@AcpTimestampMsConverter()@JsonKey(name: "updatedAt") final  int? updatedAtMs;

/// Create a copy of AcpSessionInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AcpSessionInfoCopyWith<_AcpSessionInfo> get copyWith => __$AcpSessionInfoCopyWithImpl<_AcpSessionInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AcpSessionInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AcpSessionInfo&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.title, title) || other.title == title)&&(identical(other.updatedAtMs, updatedAtMs) || other.updatedAtMs == updatedAtMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,cwd,title,updatedAtMs);

@override
String toString() {
  return 'AcpSessionInfo(sessionId: $sessionId, cwd: $cwd, title: $title, updatedAtMs: $updatedAtMs)';
}


}

/// @nodoc
abstract mixin class _$AcpSessionInfoCopyWith<$Res> implements $AcpSessionInfoCopyWith<$Res> {
  factory _$AcpSessionInfoCopyWith(_AcpSessionInfo value, $Res Function(_AcpSessionInfo) _then) = __$AcpSessionInfoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String? cwd, String? title,@AcpTimestampMsConverter()@JsonKey(name: "updatedAt") int? updatedAtMs
});




}
/// @nodoc
class __$AcpSessionInfoCopyWithImpl<$Res>
    implements _$AcpSessionInfoCopyWith<$Res> {
  __$AcpSessionInfoCopyWithImpl(this._self, this._then);

  final _AcpSessionInfo _self;
  final $Res Function(_AcpSessionInfo) _then;

/// Create a copy of AcpSessionInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? cwd = freezed,Object? title = freezed,Object? updatedAtMs = freezed,}) {
  return _then(_AcpSessionInfo(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,updatedAtMs: freezed == updatedAtMs ? _self.updatedAtMs : updatedAtMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$AcpSessionListResult {

 List<AcpSessionInfo> get sessions;/// Opaque continuation token — a non-empty value means more pages exist.
 String? get nextCursor;
/// Create a copy of AcpSessionListResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpSessionListResultCopyWith<AcpSessionListResult> get copyWith => _$AcpSessionListResultCopyWithImpl<AcpSessionListResult>(this as AcpSessionListResult, _$identity);

  /// Serializes this AcpSessionListResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpSessionListResult&&const DeepCollectionEquality().equals(other.sessions, sessions)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(sessions),nextCursor);

@override
String toString() {
  return 'AcpSessionListResult(sessions: $sessions, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class $AcpSessionListResultCopyWith<$Res>  {
  factory $AcpSessionListResultCopyWith(AcpSessionListResult value, $Res Function(AcpSessionListResult) _then) = _$AcpSessionListResultCopyWithImpl;
@useResult
$Res call({
 List<AcpSessionInfo> sessions, String? nextCursor
});




}
/// @nodoc
class _$AcpSessionListResultCopyWithImpl<$Res>
    implements $AcpSessionListResultCopyWith<$Res> {
  _$AcpSessionListResultCopyWithImpl(this._self, this._then);

  final AcpSessionListResult _self;
  final $Res Function(AcpSessionListResult) _then;

/// Create a copy of AcpSessionListResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessions = null,Object? nextCursor = freezed,}) {
  return _then(_self.copyWith(
sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<AcpSessionInfo>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _AcpSessionListResult implements AcpSessionListResult {
  const _AcpSessionListResult({final  List<AcpSessionInfo> sessions = const <AcpSessionInfo>[], required this.nextCursor}): _sessions = sessions;
  factory _AcpSessionListResult.fromJson(Map<String, dynamic> json) => _$AcpSessionListResultFromJson(json);

 final  List<AcpSessionInfo> _sessions;
@override@JsonKey() List<AcpSessionInfo> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}

/// Opaque continuation token — a non-empty value means more pages exist.
@override final  String? nextCursor;

/// Create a copy of AcpSessionListResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AcpSessionListResultCopyWith<_AcpSessionListResult> get copyWith => __$AcpSessionListResultCopyWithImpl<_AcpSessionListResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AcpSessionListResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AcpSessionListResult&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions),nextCursor);

@override
String toString() {
  return 'AcpSessionListResult(sessions: $sessions, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class _$AcpSessionListResultCopyWith<$Res> implements $AcpSessionListResultCopyWith<$Res> {
  factory _$AcpSessionListResultCopyWith(_AcpSessionListResult value, $Res Function(_AcpSessionListResult) _then) = __$AcpSessionListResultCopyWithImpl;
@override @useResult
$Res call({
 List<AcpSessionInfo> sessions, String? nextCursor
});




}
/// @nodoc
class __$AcpSessionListResultCopyWithImpl<$Res>
    implements _$AcpSessionListResultCopyWith<$Res> {
  __$AcpSessionListResultCopyWithImpl(this._self, this._then);

  final _AcpSessionListResult _self;
  final $Res Function(_AcpSessionListResult) _then;

/// Create a copy of AcpSessionListResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessions = null,Object? nextCursor = freezed,}) {
  return _then(_AcpSessionListResult(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<AcpSessionInfo>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
