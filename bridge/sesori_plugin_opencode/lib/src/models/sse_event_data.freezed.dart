// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sse_event_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
SseEventData _$SseEventDataFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'server.connected':
          return SseServerConnected.fromJson(
            json
          );
                case 'server.heartbeat':
          return SseServerHeartbeat.fromJson(
            json
          );
                case 'server.instance.disposed':
          return SseServerInstanceDisposed.fromJson(
            json
          );
                case 'global.disposed':
          return SseGlobalDisposed.fromJson(
            json
          );
                case 'session.created':
          return SseSessionCreated.fromJson(
            json
          );
                case 'session.updated':
          return SseSessionUpdated.fromJson(
            json
          );
                case 'session.deleted':
          return SseSessionDeleted.fromJson(
            json
          );
                case 'session.diff':
          return SseSessionDiff.fromJson(
            json
          );
                case 'session.error':
          return SseSessionError.fromJson(
            json
          );
                case 'session.compacted':
          return SseSessionCompacted.fromJson(
            json
          );
                case 'session.status':
          return SseSessionStatus.fromJson(
            json
          );
                case 'session.idle':
          return SseSessionIdle.fromJson(
            json
          );
                case 'message.updated':
          return SseMessageUpdated.fromJson(
            json
          );
                case 'message.removed':
          return SseMessageRemoved.fromJson(
            json
          );
                case 'message.part.updated':
          return SseMessagePartUpdated.fromJson(
            json
          );
                case 'message.part.delta':
          return SseMessagePartDelta.fromJson(
            json
          );
                case 'message.part.removed':
          return SseMessagePartRemoved.fromJson(
            json
          );
                case 'pty.created':
          return SsePtyCreated.fromJson(
            json
          );
                case 'pty.updated':
          return SsePtyUpdated.fromJson(
            json
          );
                case 'pty.exited':
          return SsePtyExited.fromJson(
            json
          );
                case 'pty.deleted':
          return SsePtyDeleted.fromJson(
            json
          );
                case 'permission.asked':
          return SsePermissionAsked.fromJson(
            json
          );
                case 'permission.replied':
          return SsePermissionReplied.fromJson(
            json
          );
                case 'permission.updated':
          return SsePermissionUpdated.fromJson(
            json
          );
                case 'question.asked':
          return SseQuestionAsked.fromJson(
            json
          );
                case 'question.replied':
          return SseQuestionReplied.fromJson(
            json
          );
                case 'question.rejected':
          return SseQuestionRejected.fromJson(
            json
          );
                case 'todo.updated':
          return SseTodoUpdated.fromJson(
            json
          );
                case 'project.updated':
          return SseProjectUpdated.fromJson(
            json
          );
                case 'vcs.branch.updated':
          return SseVcsBranchUpdated.fromJson(
            json
          );
                case 'file.edited':
          return SseFileEdited.fromJson(
            json
          );
                case 'file.watcher.updated':
          return SseFileWatcherUpdated.fromJson(
            json
          );
                case 'lsp.updated':
          return SseLspUpdated.fromJson(
            json
          );
                case 'lsp.client.diagnostics':
          return SseLspClientDiagnostics.fromJson(
            json
          );
                case 'mcp.tools.changed':
          return SseMcpToolsChanged.fromJson(
            json
          );
                case 'mcp.browser.open.failed':
          return SseMcpBrowserOpenFailed.fromJson(
            json
          );
                case 'installation.updated':
          return SseInstallationUpdated.fromJson(
            json
          );
                case 'installation.update-available':
          return SseInstallationUpdateAvailable.fromJson(
            json
          );
                case 'workspace.ready':
          return SseWorkspaceReady.fromJson(
            json
          );
                case 'workspace.failed':
          return SseWorkspaceFailed.fromJson(
            json
          );
                case 'tui.toast.show':
          return SseTuiToastShow.fromJson(
            json
          );
                case 'worktree.ready':
          return SseWorktreeReady.fromJson(
            json
          );
                case 'worktree.failed':
          return SseWorktreeFailed.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'SseEventData',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$SseEventData {



  /// Serializes this SseEventData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseEventData);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData()';
}


}

/// @nodoc
class $SseEventDataCopyWith<$Res>  {
$SseEventDataCopyWith(SseEventData _, $Res Function(SseEventData) __);
}



/// @nodoc
@JsonSerializable()

class SseServerConnected implements SseEventData {
  const SseServerConnected({final  String? $type}): $type = $type ?? 'server.connected';
  factory SseServerConnected.fromJson(Map<String, dynamic> json) => _$SseServerConnectedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SseServerConnectedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseServerConnected);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.serverConnected()';
}


}




/// @nodoc
@JsonSerializable()

class SseServerHeartbeat implements SseEventData {
  const SseServerHeartbeat({final  String? $type}): $type = $type ?? 'server.heartbeat';
  factory SseServerHeartbeat.fromJson(Map<String, dynamic> json) => _$SseServerHeartbeatFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SseServerHeartbeatToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseServerHeartbeat);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.serverHeartbeat()';
}


}




/// @nodoc
@JsonSerializable()

class SseServerInstanceDisposed implements SseEventData {
  const SseServerInstanceDisposed({this.directory, final  String? $type}): $type = $type ?? 'server.instance.disposed';
  factory SseServerInstanceDisposed.fromJson(Map<String, dynamic> json) => _$SseServerInstanceDisposedFromJson(json);

 final  String? directory;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseServerInstanceDisposedCopyWith<SseServerInstanceDisposed> get copyWith => _$SseServerInstanceDisposedCopyWithImpl<SseServerInstanceDisposed>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseServerInstanceDisposedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseServerInstanceDisposed&&(identical(other.directory, directory) || other.directory == directory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,directory);

@override
String toString() {
  return 'SseEventData.serverInstanceDisposed(directory: $directory)';
}


}

/// @nodoc
abstract mixin class $SseServerInstanceDisposedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseServerInstanceDisposedCopyWith(SseServerInstanceDisposed value, $Res Function(SseServerInstanceDisposed) _then) = _$SseServerInstanceDisposedCopyWithImpl;
@useResult
$Res call({
 String? directory
});




}
/// @nodoc
class _$SseServerInstanceDisposedCopyWithImpl<$Res>
    implements $SseServerInstanceDisposedCopyWith<$Res> {
  _$SseServerInstanceDisposedCopyWithImpl(this._self, this._then);

  final SseServerInstanceDisposed _self;
  final $Res Function(SseServerInstanceDisposed) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? directory = freezed,}) {
  return _then(SseServerInstanceDisposed(
directory: freezed == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseGlobalDisposed implements SseEventData {
  const SseGlobalDisposed({final  String? $type}): $type = $type ?? 'global.disposed';
  factory SseGlobalDisposed.fromJson(Map<String, dynamic> json) => _$SseGlobalDisposedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SseGlobalDisposedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseGlobalDisposed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.globalDisposed()';
}


}




/// @nodoc
@JsonSerializable()

class SseSessionCreated implements SseEventData, SseSessionEventData {
  const SseSessionCreated({required this.info, final  String? $type}): $type = $type ?? 'session.created';
  factory SseSessionCreated.fromJson(Map<String, dynamic> json) => _$SseSessionCreatedFromJson(json);

 final  Session info;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseSessionCreatedCopyWith<SseSessionCreated> get copyWith => _$SseSessionCreatedCopyWithImpl<SseSessionCreated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseSessionCreatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseSessionCreated&&(identical(other.info, info) || other.info == info));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info);

@override
String toString() {
  return 'SseEventData.sessionCreated(info: $info)';
}


}

/// @nodoc
abstract mixin class $SseSessionCreatedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseSessionCreatedCopyWith(SseSessionCreated value, $Res Function(SseSessionCreated) _then) = _$SseSessionCreatedCopyWithImpl;
@useResult
$Res call({
 Session info
});


$SessionCopyWith<$Res> get info;

}
/// @nodoc
class _$SseSessionCreatedCopyWithImpl<$Res>
    implements $SseSessionCreatedCopyWith<$Res> {
  _$SseSessionCreatedCopyWithImpl(this._self, this._then);

  final SseSessionCreated _self;
  final $Res Function(SseSessionCreated) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? info = null,}) {
  return _then(SseSessionCreated(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get info {
  
  return $SessionCopyWith<$Res>(_self.info, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SseSessionUpdated implements SseEventData, SseSessionEventData {
  const SseSessionUpdated({required this.info, final  String? $type}): $type = $type ?? 'session.updated';
  factory SseSessionUpdated.fromJson(Map<String, dynamic> json) => _$SseSessionUpdatedFromJson(json);

 final  Session info;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseSessionUpdatedCopyWith<SseSessionUpdated> get copyWith => _$SseSessionUpdatedCopyWithImpl<SseSessionUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseSessionUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseSessionUpdated&&(identical(other.info, info) || other.info == info));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info);

@override
String toString() {
  return 'SseEventData.sessionUpdated(info: $info)';
}


}

/// @nodoc
abstract mixin class $SseSessionUpdatedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseSessionUpdatedCopyWith(SseSessionUpdated value, $Res Function(SseSessionUpdated) _then) = _$SseSessionUpdatedCopyWithImpl;
@useResult
$Res call({
 Session info
});


$SessionCopyWith<$Res> get info;

}
/// @nodoc
class _$SseSessionUpdatedCopyWithImpl<$Res>
    implements $SseSessionUpdatedCopyWith<$Res> {
  _$SseSessionUpdatedCopyWithImpl(this._self, this._then);

  final SseSessionUpdated _self;
  final $Res Function(SseSessionUpdated) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? info = null,}) {
  return _then(SseSessionUpdated(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get info {
  
  return $SessionCopyWith<$Res>(_self.info, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SseSessionDeleted implements SseEventData, SseSessionEventData {
  const SseSessionDeleted({required this.info, final  String? $type}): $type = $type ?? 'session.deleted';
  factory SseSessionDeleted.fromJson(Map<String, dynamic> json) => _$SseSessionDeletedFromJson(json);

 final  Session info;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseSessionDeletedCopyWith<SseSessionDeleted> get copyWith => _$SseSessionDeletedCopyWithImpl<SseSessionDeleted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseSessionDeletedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseSessionDeleted&&(identical(other.info, info) || other.info == info));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info);

@override
String toString() {
  return 'SseEventData.sessionDeleted(info: $info)';
}


}

/// @nodoc
abstract mixin class $SseSessionDeletedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseSessionDeletedCopyWith(SseSessionDeleted value, $Res Function(SseSessionDeleted) _then) = _$SseSessionDeletedCopyWithImpl;
@useResult
$Res call({
 Session info
});


$SessionCopyWith<$Res> get info;

}
/// @nodoc
class _$SseSessionDeletedCopyWithImpl<$Res>
    implements $SseSessionDeletedCopyWith<$Res> {
  _$SseSessionDeletedCopyWithImpl(this._self, this._then);

  final SseSessionDeleted _self;
  final $Res Function(SseSessionDeleted) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? info = null,}) {
  return _then(SseSessionDeleted(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get info {
  
  return $SessionCopyWith<$Res>(_self.info, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SseSessionDiff implements SseEventData, SseSessionEventData {
  const SseSessionDiff({required this.sessionID, required final  List<FileDiff> diff, final  String? $type}): _diff = diff,$type = $type ?? 'session.diff';
  factory SseSessionDiff.fromJson(Map<String, dynamic> json) => _$SseSessionDiffFromJson(json);

 final  String sessionID;
 final  List<FileDiff> _diff;
 List<FileDiff> get diff {
  if (_diff is EqualUnmodifiableListView) return _diff;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_diff);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseSessionDiffCopyWith<SseSessionDiff> get copyWith => _$SseSessionDiffCopyWithImpl<SseSessionDiff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseSessionDiffToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseSessionDiff&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&const DeepCollectionEquality().equals(other._diff, _diff));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,const DeepCollectionEquality().hash(_diff));

@override
String toString() {
  return 'SseEventData.sessionDiff(sessionID: $sessionID, diff: $diff)';
}


}

/// @nodoc
abstract mixin class $SseSessionDiffCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseSessionDiffCopyWith(SseSessionDiff value, $Res Function(SseSessionDiff) _then) = _$SseSessionDiffCopyWithImpl;
@useResult
$Res call({
 String sessionID, List<FileDiff> diff
});




}
/// @nodoc
class _$SseSessionDiffCopyWithImpl<$Res>
    implements $SseSessionDiffCopyWith<$Res> {
  _$SseSessionDiffCopyWithImpl(this._self, this._then);

  final SseSessionDiff _self;
  final $Res Function(SseSessionDiff) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? diff = null,}) {
  return _then(SseSessionDiff(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,diff: null == diff ? _self._diff : diff // ignore: cast_nullable_to_non_nullable
as List<FileDiff>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseSessionError implements SseEventData, SseSessionEventData {
  const SseSessionError({required this.sessionID, final  String? $type}): $type = $type ?? 'session.error';
  factory SseSessionError.fromJson(Map<String, dynamic> json) => _$SseSessionErrorFromJson(json);

 final  String? sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseSessionErrorCopyWith<SseSessionError> get copyWith => _$SseSessionErrorCopyWithImpl<SseSessionError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseSessionErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseSessionError&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID);

@override
String toString() {
  return 'SseEventData.sessionError(sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SseSessionErrorCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseSessionErrorCopyWith(SseSessionError value, $Res Function(SseSessionError) _then) = _$SseSessionErrorCopyWithImpl;
@useResult
$Res call({
 String? sessionID
});




}
/// @nodoc
class _$SseSessionErrorCopyWithImpl<$Res>
    implements $SseSessionErrorCopyWith<$Res> {
  _$SseSessionErrorCopyWithImpl(this._self, this._then);

  final SseSessionError _self;
  final $Res Function(SseSessionError) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = freezed,}) {
  return _then(SseSessionError(
sessionID: freezed == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseSessionCompacted implements SseEventData, SseSessionEventData {
  const SseSessionCompacted({required this.sessionID, final  String? $type}): $type = $type ?? 'session.compacted';
  factory SseSessionCompacted.fromJson(Map<String, dynamic> json) => _$SseSessionCompactedFromJson(json);

 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseSessionCompactedCopyWith<SseSessionCompacted> get copyWith => _$SseSessionCompactedCopyWithImpl<SseSessionCompacted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseSessionCompactedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseSessionCompacted&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID);

@override
String toString() {
  return 'SseEventData.sessionCompacted(sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SseSessionCompactedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseSessionCompactedCopyWith(SseSessionCompacted value, $Res Function(SseSessionCompacted) _then) = _$SseSessionCompactedCopyWithImpl;
@useResult
$Res call({
 String sessionID
});




}
/// @nodoc
class _$SseSessionCompactedCopyWithImpl<$Res>
    implements $SseSessionCompactedCopyWith<$Res> {
  _$SseSessionCompactedCopyWithImpl(this._self, this._then);

  final SseSessionCompacted _self;
  final $Res Function(SseSessionCompacted) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,}) {
  return _then(SseSessionCompacted(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseSessionStatus implements SseEventData, SseSessionEventData {
  const SseSessionStatus({required this.sessionID, required this.status, final  String? $type}): $type = $type ?? 'session.status';
  factory SseSessionStatus.fromJson(Map<String, dynamic> json) => _$SseSessionStatusFromJson(json);

 final  String sessionID;
 final  SessionStatus status;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseSessionStatusCopyWith<SseSessionStatus> get copyWith => _$SseSessionStatusCopyWithImpl<SseSessionStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseSessionStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseSessionStatus&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,status);

@override
String toString() {
  return 'SseEventData.sessionStatus(sessionID: $sessionID, status: $status)';
}


}

/// @nodoc
abstract mixin class $SseSessionStatusCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseSessionStatusCopyWith(SseSessionStatus value, $Res Function(SseSessionStatus) _then) = _$SseSessionStatusCopyWithImpl;
@useResult
$Res call({
 String sessionID, SessionStatus status
});


$SessionStatusCopyWith<$Res> get status;

}
/// @nodoc
class _$SseSessionStatusCopyWithImpl<$Res>
    implements $SseSessionStatusCopyWith<$Res> {
  _$SseSessionStatusCopyWithImpl(this._self, this._then);

  final SseSessionStatus _self;
  final $Res Function(SseSessionStatus) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? status = null,}) {
  return _then(SseSessionStatus(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SessionStatus,
  ));
}

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionStatusCopyWith<$Res> get status {
  
  return $SessionStatusCopyWith<$Res>(_self.status, (value) {
    return _then(_self.copyWith(status: value));
  });
}
}

/// @nodoc
@JsonSerializable()
@Deprecated("Use sessionStatus instead. Emitted for backward compatibility.")
class SseSessionIdle implements SseEventData, SseSessionEventData {
  const SseSessionIdle({required this.sessionID, final  String? $type}): $type = $type ?? 'session.idle';
  factory SseSessionIdle.fromJson(Map<String, dynamic> json) => _$SseSessionIdleFromJson(json);

 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseSessionIdleCopyWith<SseSessionIdle> get copyWith => _$SseSessionIdleCopyWithImpl<SseSessionIdle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseSessionIdleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseSessionIdle&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID);

@override
String toString() {
  return 'SseEventData.sessionIdle(sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SseSessionIdleCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseSessionIdleCopyWith(SseSessionIdle value, $Res Function(SseSessionIdle) _then) = _$SseSessionIdleCopyWithImpl;
@useResult
$Res call({
 String sessionID
});




}
/// @nodoc
class _$SseSessionIdleCopyWithImpl<$Res>
    implements $SseSessionIdleCopyWith<$Res> {
  _$SseSessionIdleCopyWithImpl(this._self, this._then);

  final SseSessionIdle _self;
  final $Res Function(SseSessionIdle) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,}) {
  return _then(SseSessionIdle(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseMessageUpdated implements SseEventData, SseSessionEventData {
  const SseMessageUpdated({required this.info, final  String? $type}): $type = $type ?? 'message.updated';
  factory SseMessageUpdated.fromJson(Map<String, dynamic> json) => _$SseMessageUpdatedFromJson(json);

 final  Message info;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseMessageUpdatedCopyWith<SseMessageUpdated> get copyWith => _$SseMessageUpdatedCopyWithImpl<SseMessageUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseMessageUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseMessageUpdated&&(identical(other.info, info) || other.info == info));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info);

@override
String toString() {
  return 'SseEventData.messageUpdated(info: $info)';
}


}

/// @nodoc
abstract mixin class $SseMessageUpdatedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseMessageUpdatedCopyWith(SseMessageUpdated value, $Res Function(SseMessageUpdated) _then) = _$SseMessageUpdatedCopyWithImpl;
@useResult
$Res call({
 Message info
});


$MessageCopyWith<$Res> get info;

}
/// @nodoc
class _$SseMessageUpdatedCopyWithImpl<$Res>
    implements $SseMessageUpdatedCopyWith<$Res> {
  _$SseMessageUpdatedCopyWithImpl(this._self, this._then);

  final SseMessageUpdated _self;
  final $Res Function(SseMessageUpdated) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? info = null,}) {
  return _then(SseMessageUpdated(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Message,
  ));
}

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res> get info {
  
  return $MessageCopyWith<$Res>(_self.info, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SseMessageRemoved implements SseEventData, SseSessionEventData {
  const SseMessageRemoved({required this.sessionID, required this.messageID, final  String? $type}): $type = $type ?? 'message.removed';
  factory SseMessageRemoved.fromJson(Map<String, dynamic> json) => _$SseMessageRemovedFromJson(json);

 final  String sessionID;
 final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseMessageRemovedCopyWith<SseMessageRemoved> get copyWith => _$SseMessageRemovedCopyWithImpl<SseMessageRemoved>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseMessageRemovedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseMessageRemoved&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,messageID);

@override
String toString() {
  return 'SseEventData.messageRemoved(sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $SseMessageRemovedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseMessageRemovedCopyWith(SseMessageRemoved value, $Res Function(SseMessageRemoved) _then) = _$SseMessageRemovedCopyWithImpl;
@useResult
$Res call({
 String sessionID, String messageID
});




}
/// @nodoc
class _$SseMessageRemovedCopyWithImpl<$Res>
    implements $SseMessageRemovedCopyWith<$Res> {
  _$SseMessageRemovedCopyWithImpl(this._self, this._then);

  final SseMessageRemoved _self;
  final $Res Function(SseMessageRemoved) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? messageID = null,}) {
  return _then(SseMessageRemoved(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseMessagePartUpdated implements SseEventData, SseSessionEventData {
  const SseMessagePartUpdated({required this.part, final  String? $type}): $type = $type ?? 'message.part.updated';
  factory SseMessagePartUpdated.fromJson(Map<String, dynamic> json) => _$SseMessagePartUpdatedFromJson(json);

 final  MessagePart part;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseMessagePartUpdatedCopyWith<SseMessagePartUpdated> get copyWith => _$SseMessagePartUpdatedCopyWithImpl<SseMessagePartUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseMessagePartUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseMessagePartUpdated&&(identical(other.part, part) || other.part == part));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,part);

@override
String toString() {
  return 'SseEventData.messagePartUpdated(part: $part)';
}


}

/// @nodoc
abstract mixin class $SseMessagePartUpdatedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseMessagePartUpdatedCopyWith(SseMessagePartUpdated value, $Res Function(SseMessagePartUpdated) _then) = _$SseMessagePartUpdatedCopyWithImpl;
@useResult
$Res call({
 MessagePart part
});


$MessagePartCopyWith<$Res> get part;

}
/// @nodoc
class _$SseMessagePartUpdatedCopyWithImpl<$Res>
    implements $SseMessagePartUpdatedCopyWith<$Res> {
  _$SseMessagePartUpdatedCopyWithImpl(this._self, this._then);

  final SseMessagePartUpdated _self;
  final $Res Function(SseMessagePartUpdated) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? part = null,}) {
  return _then(SseMessagePartUpdated(
part: null == part ? _self.part : part // ignore: cast_nullable_to_non_nullable
as MessagePart,
  ));
}

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessagePartCopyWith<$Res> get part {
  
  return $MessagePartCopyWith<$Res>(_self.part, (value) {
    return _then(_self.copyWith(part: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SseMessagePartDelta implements SseEventData, SseSessionEventData {
  const SseMessagePartDelta({required this.sessionID, required this.messageID, required this.partID, required this.field, required this.delta, final  String? $type}): $type = $type ?? 'message.part.delta';
  factory SseMessagePartDelta.fromJson(Map<String, dynamic> json) => _$SseMessagePartDeltaFromJson(json);

 final  String sessionID;
 final  String messageID;
 final  String partID;
 final  String field;
 final  String delta;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseMessagePartDeltaCopyWith<SseMessagePartDelta> get copyWith => _$SseMessagePartDeltaCopyWithImpl<SseMessagePartDelta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseMessagePartDeltaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseMessagePartDelta&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.partID, partID) || other.partID == partID)&&(identical(other.field, field) || other.field == field)&&(identical(other.delta, delta) || other.delta == delta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,messageID,partID,field,delta);

@override
String toString() {
  return 'SseEventData.messagePartDelta(sessionID: $sessionID, messageID: $messageID, partID: $partID, field: $field, delta: $delta)';
}


}

/// @nodoc
abstract mixin class $SseMessagePartDeltaCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseMessagePartDeltaCopyWith(SseMessagePartDelta value, $Res Function(SseMessagePartDelta) _then) = _$SseMessagePartDeltaCopyWithImpl;
@useResult
$Res call({
 String sessionID, String messageID, String partID, String field, String delta
});




}
/// @nodoc
class _$SseMessagePartDeltaCopyWithImpl<$Res>
    implements $SseMessagePartDeltaCopyWith<$Res> {
  _$SseMessagePartDeltaCopyWithImpl(this._self, this._then);

  final SseMessagePartDelta _self;
  final $Res Function(SseMessagePartDelta) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? messageID = null,Object? partID = null,Object? field = null,Object? delta = null,}) {
  return _then(SseMessagePartDelta(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,partID: null == partID ? _self.partID : partID // ignore: cast_nullable_to_non_nullable
as String,field: null == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as String,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseMessagePartRemoved implements SseEventData, SseSessionEventData {
  const SseMessagePartRemoved({required this.sessionID, required this.messageID, required this.partID, final  String? $type}): $type = $type ?? 'message.part.removed';
  factory SseMessagePartRemoved.fromJson(Map<String, dynamic> json) => _$SseMessagePartRemovedFromJson(json);

 final  String sessionID;
 final  String messageID;
 final  String partID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseMessagePartRemovedCopyWith<SseMessagePartRemoved> get copyWith => _$SseMessagePartRemovedCopyWithImpl<SseMessagePartRemoved>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseMessagePartRemovedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseMessagePartRemoved&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.partID, partID) || other.partID == partID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,messageID,partID);

@override
String toString() {
  return 'SseEventData.messagePartRemoved(sessionID: $sessionID, messageID: $messageID, partID: $partID)';
}


}

/// @nodoc
abstract mixin class $SseMessagePartRemovedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseMessagePartRemovedCopyWith(SseMessagePartRemoved value, $Res Function(SseMessagePartRemoved) _then) = _$SseMessagePartRemovedCopyWithImpl;
@useResult
$Res call({
 String sessionID, String messageID, String partID
});




}
/// @nodoc
class _$SseMessagePartRemovedCopyWithImpl<$Res>
    implements $SseMessagePartRemovedCopyWith<$Res> {
  _$SseMessagePartRemovedCopyWithImpl(this._self, this._then);

  final SseMessagePartRemoved _self;
  final $Res Function(SseMessagePartRemoved) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? messageID = null,Object? partID = null,}) {
  return _then(SseMessagePartRemoved(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,partID: null == partID ? _self.partID : partID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SsePtyCreated implements SseEventData {
  const SsePtyCreated({final  String? $type}): $type = $type ?? 'pty.created';
  factory SsePtyCreated.fromJson(Map<String, dynamic> json) => _$SsePtyCreatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SsePtyCreatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SsePtyCreated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.ptyCreated()';
}


}




/// @nodoc
@JsonSerializable()

class SsePtyUpdated implements SseEventData {
  const SsePtyUpdated({final  String? $type}): $type = $type ?? 'pty.updated';
  factory SsePtyUpdated.fromJson(Map<String, dynamic> json) => _$SsePtyUpdatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SsePtyUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SsePtyUpdated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.ptyUpdated()';
}


}




/// @nodoc
@JsonSerializable()

class SsePtyExited implements SseEventData {
  const SsePtyExited({this.id, this.exitCode, final  String? $type}): $type = $type ?? 'pty.exited';
  factory SsePtyExited.fromJson(Map<String, dynamic> json) => _$SsePtyExitedFromJson(json);

 final  String? id;
 final  int? exitCode;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SsePtyExitedCopyWith<SsePtyExited> get copyWith => _$SsePtyExitedCopyWithImpl<SsePtyExited>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SsePtyExitedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SsePtyExited&&(identical(other.id, id) || other.id == id)&&(identical(other.exitCode, exitCode) || other.exitCode == exitCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,exitCode);

@override
String toString() {
  return 'SseEventData.ptyExited(id: $id, exitCode: $exitCode)';
}


}

/// @nodoc
abstract mixin class $SsePtyExitedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SsePtyExitedCopyWith(SsePtyExited value, $Res Function(SsePtyExited) _then) = _$SsePtyExitedCopyWithImpl;
@useResult
$Res call({
 String? id, int? exitCode
});




}
/// @nodoc
class _$SsePtyExitedCopyWithImpl<$Res>
    implements $SsePtyExitedCopyWith<$Res> {
  _$SsePtyExitedCopyWithImpl(this._self, this._then);

  final SsePtyExited _self;
  final $Res Function(SsePtyExited) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? exitCode = freezed,}) {
  return _then(SsePtyExited(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,exitCode: freezed == exitCode ? _self.exitCode : exitCode // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SsePtyDeleted implements SseEventData {
  const SsePtyDeleted({this.id, final  String? $type}): $type = $type ?? 'pty.deleted';
  factory SsePtyDeleted.fromJson(Map<String, dynamic> json) => _$SsePtyDeletedFromJson(json);

 final  String? id;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SsePtyDeletedCopyWith<SsePtyDeleted> get copyWith => _$SsePtyDeletedCopyWithImpl<SsePtyDeleted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SsePtyDeletedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SsePtyDeleted&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'SseEventData.ptyDeleted(id: $id)';
}


}

/// @nodoc
abstract mixin class $SsePtyDeletedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SsePtyDeletedCopyWith(SsePtyDeleted value, $Res Function(SsePtyDeleted) _then) = _$SsePtyDeletedCopyWithImpl;
@useResult
$Res call({
 String? id
});




}
/// @nodoc
class _$SsePtyDeletedCopyWithImpl<$Res>
    implements $SsePtyDeletedCopyWith<$Res> {
  _$SsePtyDeletedCopyWithImpl(this._self, this._then);

  final SsePtyDeleted _self;
  final $Res Function(SsePtyDeleted) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,}) {
  return _then(SsePtyDeleted(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SsePermissionAsked implements SseEventData, SseSessionEventData {
  const SsePermissionAsked({required this.requestID, required this.sessionID, required this.tool, required this.description, final  String? $type}): $type = $type ?? 'permission.asked';
  factory SsePermissionAsked.fromJson(Map<String, dynamic> json) => _$SsePermissionAskedFromJson(json);

 final  String requestID;
 final  String sessionID;
 final  String tool;
 final  String description;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SsePermissionAskedCopyWith<SsePermissionAsked> get copyWith => _$SsePermissionAskedCopyWithImpl<SsePermissionAsked>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SsePermissionAskedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SsePermissionAsked&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID,tool,description);

@override
String toString() {
  return 'SseEventData.permissionAsked(requestID: $requestID, sessionID: $sessionID, tool: $tool, description: $description)';
}


}

/// @nodoc
abstract mixin class $SsePermissionAskedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SsePermissionAskedCopyWith(SsePermissionAsked value, $Res Function(SsePermissionAsked) _then) = _$SsePermissionAskedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID, String tool, String description
});




}
/// @nodoc
class _$SsePermissionAskedCopyWithImpl<$Res>
    implements $SsePermissionAskedCopyWith<$Res> {
  _$SsePermissionAskedCopyWithImpl(this._self, this._then);

  final SsePermissionAsked _self;
  final $Res Function(SsePermissionAsked) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,Object? tool = null,Object? description = null,}) {
  return _then(SsePermissionAsked(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SsePermissionReplied implements SseEventData {
  const SsePermissionReplied({required this.requestID, required this.reply, final  String? $type}): $type = $type ?? 'permission.replied';
  factory SsePermissionReplied.fromJson(Map<String, dynamic> json) => _$SsePermissionRepliedFromJson(json);

 final  String requestID;
 final  String reply;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SsePermissionRepliedCopyWith<SsePermissionReplied> get copyWith => _$SsePermissionRepliedCopyWithImpl<SsePermissionReplied>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SsePermissionRepliedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SsePermissionReplied&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.reply, reply) || other.reply == reply));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,reply);

@override
String toString() {
  return 'SseEventData.permissionReplied(requestID: $requestID, reply: $reply)';
}


}

/// @nodoc
abstract mixin class $SsePermissionRepliedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SsePermissionRepliedCopyWith(SsePermissionReplied value, $Res Function(SsePermissionReplied) _then) = _$SsePermissionRepliedCopyWithImpl;
@useResult
$Res call({
 String requestID, String reply
});




}
/// @nodoc
class _$SsePermissionRepliedCopyWithImpl<$Res>
    implements $SsePermissionRepliedCopyWith<$Res> {
  _$SsePermissionRepliedCopyWithImpl(this._self, this._then);

  final SsePermissionReplied _self;
  final $Res Function(SsePermissionReplied) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? reply = null,}) {
  return _then(SsePermissionReplied(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,reply: null == reply ? _self.reply : reply // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SsePermissionUpdated implements SseEventData {
  const SsePermissionUpdated({final  String? $type}): $type = $type ?? 'permission.updated';
  factory SsePermissionUpdated.fromJson(Map<String, dynamic> json) => _$SsePermissionUpdatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SsePermissionUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SsePermissionUpdated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.permissionUpdated()';
}


}




/// @nodoc
@JsonSerializable()

class SseQuestionAsked implements SseEventData, SseSessionEventData {
  const SseQuestionAsked({required this.id, required this.sessionID, required final  List<QuestionInfo> questions, final  String? $type}): _questions = questions,$type = $type ?? 'question.asked';
  factory SseQuestionAsked.fromJson(Map<String, dynamic> json) => _$SseQuestionAskedFromJson(json);

 final  String id;
 final  String sessionID;
 final  List<QuestionInfo> _questions;
 List<QuestionInfo> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseQuestionAskedCopyWith<SseQuestionAsked> get copyWith => _$SseQuestionAskedCopyWithImpl<SseQuestionAsked>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseQuestionAskedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseQuestionAsked&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&const DeepCollectionEquality().equals(other._questions, _questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,const DeepCollectionEquality().hash(_questions));

@override
String toString() {
  return 'SseEventData.questionAsked(id: $id, sessionID: $sessionID, questions: $questions)';
}


}

/// @nodoc
abstract mixin class $SseQuestionAskedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseQuestionAskedCopyWith(SseQuestionAsked value, $Res Function(SseQuestionAsked) _then) = _$SseQuestionAskedCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, List<QuestionInfo> questions
});




}
/// @nodoc
class _$SseQuestionAskedCopyWithImpl<$Res>
    implements $SseQuestionAskedCopyWith<$Res> {
  _$SseQuestionAskedCopyWithImpl(this._self, this._then);

  final SseQuestionAsked _self;
  final $Res Function(SseQuestionAsked) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? questions = null,}) {
  return _then(SseQuestionAsked(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<QuestionInfo>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseQuestionReplied implements SseEventData, SseSessionEventData {
  const SseQuestionReplied({required this.requestID, required this.sessionID, final  String? $type}): $type = $type ?? 'question.replied';
  factory SseQuestionReplied.fromJson(Map<String, dynamic> json) => _$SseQuestionRepliedFromJson(json);

 final  String requestID;
 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseQuestionRepliedCopyWith<SseQuestionReplied> get copyWith => _$SseQuestionRepliedCopyWithImpl<SseQuestionReplied>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseQuestionRepliedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseQuestionReplied&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID);

@override
String toString() {
  return 'SseEventData.questionReplied(requestID: $requestID, sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SseQuestionRepliedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseQuestionRepliedCopyWith(SseQuestionReplied value, $Res Function(SseQuestionReplied) _then) = _$SseQuestionRepliedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID
});




}
/// @nodoc
class _$SseQuestionRepliedCopyWithImpl<$Res>
    implements $SseQuestionRepliedCopyWith<$Res> {
  _$SseQuestionRepliedCopyWithImpl(this._self, this._then);

  final SseQuestionReplied _self;
  final $Res Function(SseQuestionReplied) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,}) {
  return _then(SseQuestionReplied(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseQuestionRejected implements SseEventData, SseSessionEventData {
  const SseQuestionRejected({required this.requestID, required this.sessionID, final  String? $type}): $type = $type ?? 'question.rejected';
  factory SseQuestionRejected.fromJson(Map<String, dynamic> json) => _$SseQuestionRejectedFromJson(json);

 final  String requestID;
 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseQuestionRejectedCopyWith<SseQuestionRejected> get copyWith => _$SseQuestionRejectedCopyWithImpl<SseQuestionRejected>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseQuestionRejectedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseQuestionRejected&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID);

@override
String toString() {
  return 'SseEventData.questionRejected(requestID: $requestID, sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SseQuestionRejectedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseQuestionRejectedCopyWith(SseQuestionRejected value, $Res Function(SseQuestionRejected) _then) = _$SseQuestionRejectedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID
});




}
/// @nodoc
class _$SseQuestionRejectedCopyWithImpl<$Res>
    implements $SseQuestionRejectedCopyWith<$Res> {
  _$SseQuestionRejectedCopyWithImpl(this._self, this._then);

  final SseQuestionRejected _self;
  final $Res Function(SseQuestionRejected) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,}) {
  return _then(SseQuestionRejected(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseTodoUpdated implements SseEventData, SseSessionEventData {
  const SseTodoUpdated({required this.sessionID, final  String? $type}): $type = $type ?? 'todo.updated';
  factory SseTodoUpdated.fromJson(Map<String, dynamic> json) => _$SseTodoUpdatedFromJson(json);

 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseTodoUpdatedCopyWith<SseTodoUpdated> get copyWith => _$SseTodoUpdatedCopyWithImpl<SseTodoUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseTodoUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseTodoUpdated&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID);

@override
String toString() {
  return 'SseEventData.todoUpdated(sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SseTodoUpdatedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseTodoUpdatedCopyWith(SseTodoUpdated value, $Res Function(SseTodoUpdated) _then) = _$SseTodoUpdatedCopyWithImpl;
@useResult
$Res call({
 String sessionID
});




}
/// @nodoc
class _$SseTodoUpdatedCopyWithImpl<$Res>
    implements $SseTodoUpdatedCopyWith<$Res> {
  _$SseTodoUpdatedCopyWithImpl(this._self, this._then);

  final SseTodoUpdated _self;
  final $Res Function(SseTodoUpdated) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,}) {
  return _then(SseTodoUpdated(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseProjectUpdated implements SseEventData {
  const SseProjectUpdated({final  String? $type}): $type = $type ?? 'project.updated';
  factory SseProjectUpdated.fromJson(Map<String, dynamic> json) => _$SseProjectUpdatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SseProjectUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseProjectUpdated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.projectUpdated()';
}


}




/// @nodoc
@JsonSerializable()

class SseVcsBranchUpdated implements SseEventData {
  const SseVcsBranchUpdated({final  String? $type}): $type = $type ?? 'vcs.branch.updated';
  factory SseVcsBranchUpdated.fromJson(Map<String, dynamic> json) => _$SseVcsBranchUpdatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SseVcsBranchUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseVcsBranchUpdated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.vcsBranchUpdated()';
}


}




/// @nodoc
@JsonSerializable()

class SseFileEdited implements SseEventData {
  const SseFileEdited({this.file, final  String? $type}): $type = $type ?? 'file.edited';
  factory SseFileEdited.fromJson(Map<String, dynamic> json) => _$SseFileEditedFromJson(json);

 final  String? file;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseFileEditedCopyWith<SseFileEdited> get copyWith => _$SseFileEditedCopyWithImpl<SseFileEdited>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseFileEditedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseFileEdited&&(identical(other.file, file) || other.file == file));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file);

@override
String toString() {
  return 'SseEventData.fileEdited(file: $file)';
}


}

/// @nodoc
abstract mixin class $SseFileEditedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseFileEditedCopyWith(SseFileEdited value, $Res Function(SseFileEdited) _then) = _$SseFileEditedCopyWithImpl;
@useResult
$Res call({
 String? file
});




}
/// @nodoc
class _$SseFileEditedCopyWithImpl<$Res>
    implements $SseFileEditedCopyWith<$Res> {
  _$SseFileEditedCopyWithImpl(this._self, this._then);

  final SseFileEdited _self;
  final $Res Function(SseFileEdited) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? file = freezed,}) {
  return _then(SseFileEdited(
file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseFileWatcherUpdated implements SseEventData {
  const SseFileWatcherUpdated({this.file, this.event, final  String? $type}): $type = $type ?? 'file.watcher.updated';
  factory SseFileWatcherUpdated.fromJson(Map<String, dynamic> json) => _$SseFileWatcherUpdatedFromJson(json);

 final  String? file;
 final  String? event;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseFileWatcherUpdatedCopyWith<SseFileWatcherUpdated> get copyWith => _$SseFileWatcherUpdatedCopyWithImpl<SseFileWatcherUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseFileWatcherUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseFileWatcherUpdated&&(identical(other.file, file) || other.file == file)&&(identical(other.event, event) || other.event == event));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,event);

@override
String toString() {
  return 'SseEventData.fileWatcherUpdated(file: $file, event: $event)';
}


}

/// @nodoc
abstract mixin class $SseFileWatcherUpdatedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseFileWatcherUpdatedCopyWith(SseFileWatcherUpdated value, $Res Function(SseFileWatcherUpdated) _then) = _$SseFileWatcherUpdatedCopyWithImpl;
@useResult
$Res call({
 String? file, String? event
});




}
/// @nodoc
class _$SseFileWatcherUpdatedCopyWithImpl<$Res>
    implements $SseFileWatcherUpdatedCopyWith<$Res> {
  _$SseFileWatcherUpdatedCopyWithImpl(this._self, this._then);

  final SseFileWatcherUpdated _self;
  final $Res Function(SseFileWatcherUpdated) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? file = freezed,Object? event = freezed,}) {
  return _then(SseFileWatcherUpdated(
file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,event: freezed == event ? _self.event : event // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseLspUpdated implements SseEventData {
  const SseLspUpdated({final  String? $type}): $type = $type ?? 'lsp.updated';
  factory SseLspUpdated.fromJson(Map<String, dynamic> json) => _$SseLspUpdatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SseLspUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseLspUpdated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.lspUpdated()';
}


}




/// @nodoc
@JsonSerializable()

class SseLspClientDiagnostics implements SseEventData {
  const SseLspClientDiagnostics({this.serverID, this.path, final  String? $type}): $type = $type ?? 'lsp.client.diagnostics';
  factory SseLspClientDiagnostics.fromJson(Map<String, dynamic> json) => _$SseLspClientDiagnosticsFromJson(json);

 final  String? serverID;
 final  String? path;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseLspClientDiagnosticsCopyWith<SseLspClientDiagnostics> get copyWith => _$SseLspClientDiagnosticsCopyWithImpl<SseLspClientDiagnostics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseLspClientDiagnosticsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseLspClientDiagnostics&&(identical(other.serverID, serverID) || other.serverID == serverID)&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverID,path);

@override
String toString() {
  return 'SseEventData.lspClientDiagnostics(serverID: $serverID, path: $path)';
}


}

/// @nodoc
abstract mixin class $SseLspClientDiagnosticsCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseLspClientDiagnosticsCopyWith(SseLspClientDiagnostics value, $Res Function(SseLspClientDiagnostics) _then) = _$SseLspClientDiagnosticsCopyWithImpl;
@useResult
$Res call({
 String? serverID, String? path
});




}
/// @nodoc
class _$SseLspClientDiagnosticsCopyWithImpl<$Res>
    implements $SseLspClientDiagnosticsCopyWith<$Res> {
  _$SseLspClientDiagnosticsCopyWithImpl(this._self, this._then);

  final SseLspClientDiagnostics _self;
  final $Res Function(SseLspClientDiagnostics) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? serverID = freezed,Object? path = freezed,}) {
  return _then(SseLspClientDiagnostics(
serverID: freezed == serverID ? _self.serverID : serverID // ignore: cast_nullable_to_non_nullable
as String?,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseMcpToolsChanged implements SseEventData {
  const SseMcpToolsChanged({final  String? $type}): $type = $type ?? 'mcp.tools.changed';
  factory SseMcpToolsChanged.fromJson(Map<String, dynamic> json) => _$SseMcpToolsChangedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SseMcpToolsChangedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseMcpToolsChanged);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.mcpToolsChanged()';
}


}




/// @nodoc
@JsonSerializable()

class SseMcpBrowserOpenFailed implements SseEventData {
  const SseMcpBrowserOpenFailed({final  String? $type}): $type = $type ?? 'mcp.browser.open.failed';
  factory SseMcpBrowserOpenFailed.fromJson(Map<String, dynamic> json) => _$SseMcpBrowserOpenFailedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SseMcpBrowserOpenFailedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseMcpBrowserOpenFailed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.mcpBrowserOpenFailed()';
}


}




/// @nodoc
@JsonSerializable()

class SseInstallationUpdated implements SseEventData {
  const SseInstallationUpdated({this.version, final  String? $type}): $type = $type ?? 'installation.updated';
  factory SseInstallationUpdated.fromJson(Map<String, dynamic> json) => _$SseInstallationUpdatedFromJson(json);

 final  String? version;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseInstallationUpdatedCopyWith<SseInstallationUpdated> get copyWith => _$SseInstallationUpdatedCopyWithImpl<SseInstallationUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseInstallationUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseInstallationUpdated&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version);

@override
String toString() {
  return 'SseEventData.installationUpdated(version: $version)';
}


}

/// @nodoc
abstract mixin class $SseInstallationUpdatedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseInstallationUpdatedCopyWith(SseInstallationUpdated value, $Res Function(SseInstallationUpdated) _then) = _$SseInstallationUpdatedCopyWithImpl;
@useResult
$Res call({
 String? version
});




}
/// @nodoc
class _$SseInstallationUpdatedCopyWithImpl<$Res>
    implements $SseInstallationUpdatedCopyWith<$Res> {
  _$SseInstallationUpdatedCopyWithImpl(this._self, this._then);

  final SseInstallationUpdated _self;
  final $Res Function(SseInstallationUpdated) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? version = freezed,}) {
  return _then(SseInstallationUpdated(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseInstallationUpdateAvailable implements SseEventData {
  const SseInstallationUpdateAvailable({this.version, final  String? $type}): $type = $type ?? 'installation.update-available';
  factory SseInstallationUpdateAvailable.fromJson(Map<String, dynamic> json) => _$SseInstallationUpdateAvailableFromJson(json);

 final  String? version;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseInstallationUpdateAvailableCopyWith<SseInstallationUpdateAvailable> get copyWith => _$SseInstallationUpdateAvailableCopyWithImpl<SseInstallationUpdateAvailable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseInstallationUpdateAvailableToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseInstallationUpdateAvailable&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version);

@override
String toString() {
  return 'SseEventData.installationUpdateAvailable(version: $version)';
}


}

/// @nodoc
abstract mixin class $SseInstallationUpdateAvailableCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseInstallationUpdateAvailableCopyWith(SseInstallationUpdateAvailable value, $Res Function(SseInstallationUpdateAvailable) _then) = _$SseInstallationUpdateAvailableCopyWithImpl;
@useResult
$Res call({
 String? version
});




}
/// @nodoc
class _$SseInstallationUpdateAvailableCopyWithImpl<$Res>
    implements $SseInstallationUpdateAvailableCopyWith<$Res> {
  _$SseInstallationUpdateAvailableCopyWithImpl(this._self, this._then);

  final SseInstallationUpdateAvailable _self;
  final $Res Function(SseInstallationUpdateAvailable) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? version = freezed,}) {
  return _then(SseInstallationUpdateAvailable(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseWorkspaceReady implements SseEventData {
  const SseWorkspaceReady({this.name, final  String? $type}): $type = $type ?? 'workspace.ready';
  factory SseWorkspaceReady.fromJson(Map<String, dynamic> json) => _$SseWorkspaceReadyFromJson(json);

 final  String? name;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseWorkspaceReadyCopyWith<SseWorkspaceReady> get copyWith => _$SseWorkspaceReadyCopyWithImpl<SseWorkspaceReady>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseWorkspaceReadyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseWorkspaceReady&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'SseEventData.workspaceReady(name: $name)';
}


}

/// @nodoc
abstract mixin class $SseWorkspaceReadyCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseWorkspaceReadyCopyWith(SseWorkspaceReady value, $Res Function(SseWorkspaceReady) _then) = _$SseWorkspaceReadyCopyWithImpl;
@useResult
$Res call({
 String? name
});




}
/// @nodoc
class _$SseWorkspaceReadyCopyWithImpl<$Res>
    implements $SseWorkspaceReadyCopyWith<$Res> {
  _$SseWorkspaceReadyCopyWithImpl(this._self, this._then);

  final SseWorkspaceReady _self;
  final $Res Function(SseWorkspaceReady) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = freezed,}) {
  return _then(SseWorkspaceReady(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseWorkspaceFailed implements SseEventData {
  const SseWorkspaceFailed({this.message, final  String? $type}): $type = $type ?? 'workspace.failed';
  factory SseWorkspaceFailed.fromJson(Map<String, dynamic> json) => _$SseWorkspaceFailedFromJson(json);

 final  String? message;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseWorkspaceFailedCopyWith<SseWorkspaceFailed> get copyWith => _$SseWorkspaceFailedCopyWithImpl<SseWorkspaceFailed>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseWorkspaceFailedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseWorkspaceFailed&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'SseEventData.workspaceFailed(message: $message)';
}


}

/// @nodoc
abstract mixin class $SseWorkspaceFailedCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseWorkspaceFailedCopyWith(SseWorkspaceFailed value, $Res Function(SseWorkspaceFailed) _then) = _$SseWorkspaceFailedCopyWithImpl;
@useResult
$Res call({
 String? message
});




}
/// @nodoc
class _$SseWorkspaceFailedCopyWithImpl<$Res>
    implements $SseWorkspaceFailedCopyWith<$Res> {
  _$SseWorkspaceFailedCopyWithImpl(this._self, this._then);

  final SseWorkspaceFailed _self;
  final $Res Function(SseWorkspaceFailed) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = freezed,}) {
  return _then(SseWorkspaceFailed(
message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseTuiToastShow implements SseEventData {
  const SseTuiToastShow({this.title, this.message, this.variant, final  String? $type}): $type = $type ?? 'tui.toast.show';
  factory SseTuiToastShow.fromJson(Map<String, dynamic> json) => _$SseTuiToastShowFromJson(json);

 final  String? title;
 final  String? message;
 final  String? variant;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseTuiToastShowCopyWith<SseTuiToastShow> get copyWith => _$SseTuiToastShowCopyWithImpl<SseTuiToastShow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SseTuiToastShowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseTuiToastShow&&(identical(other.title, title) || other.title == title)&&(identical(other.message, message) || other.message == message)&&(identical(other.variant, variant) || other.variant == variant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,message,variant);

@override
String toString() {
  return 'SseEventData.tuiToastShow(title: $title, message: $message, variant: $variant)';
}


}

/// @nodoc
abstract mixin class $SseTuiToastShowCopyWith<$Res> implements $SseEventDataCopyWith<$Res> {
  factory $SseTuiToastShowCopyWith(SseTuiToastShow value, $Res Function(SseTuiToastShow) _then) = _$SseTuiToastShowCopyWithImpl;
@useResult
$Res call({
 String? title, String? message, String? variant
});




}
/// @nodoc
class _$SseTuiToastShowCopyWithImpl<$Res>
    implements $SseTuiToastShowCopyWith<$Res> {
  _$SseTuiToastShowCopyWithImpl(this._self, this._then);

  final SseTuiToastShow _self;
  final $Res Function(SseTuiToastShow) _then;

/// Create a copy of SseEventData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? title = freezed,Object? message = freezed,Object? variant = freezed,}) {
  return _then(SseTuiToastShow(
title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SseWorktreeReady implements SseEventData {
  const SseWorktreeReady({final  String? $type}): $type = $type ?? 'worktree.ready';
  factory SseWorktreeReady.fromJson(Map<String, dynamic> json) => _$SseWorktreeReadyFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SseWorktreeReadyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseWorktreeReady);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.worktreeReady()';
}


}




/// @nodoc
@JsonSerializable()

class SseWorktreeFailed implements SseEventData {
  const SseWorktreeFailed({final  String? $type}): $type = $type ?? 'worktree.failed';
  factory SseWorktreeFailed.fromJson(Map<String, dynamic> json) => _$SseWorktreeFailedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SseWorktreeFailedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseWorktreeFailed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseEventData.worktreeFailed()';
}


}




// dart format on
