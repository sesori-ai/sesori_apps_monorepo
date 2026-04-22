// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sesori_sse_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
SesoriSseEvent _$SesoriSseEventFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'server.connected':
          return SesoriServerConnected.fromJson(
            json
          );
                case 'server.heartbeat':
          return SesoriServerHeartbeat.fromJson(
            json
          );
                case 'server.instance.disposed':
          return SesoriServerInstanceDisposed.fromJson(
            json
          );
                case 'global.disposed':
          return SesoriGlobalDisposed.fromJson(
            json
          );
                case 'session.created':
          return SesoriSessionCreated.fromJson(
            json
          );
                case 'session.updated':
          return SesoriSessionUpdated.fromJson(
            json
          );
                case 'session.deleted':
          return SesoriSessionDeleted.fromJson(
            json
          );
                case 'session.diff':
          return SesoriSessionDiff.fromJson(
            json
          );
                case 'session.error':
          return SesoriSessionError.fromJson(
            json
          );
                case 'session.compacted':
          return SesoriSessionCompacted.fromJson(
            json
          );
                case 'session.status':
          return SesoriSessionStatus.fromJson(
            json
          );
                case 'session.idle':
          return SesoriSessionIdle.fromJson(
            json
          );
                case 'command.executed':
          return SesoriCommandExecuted.fromJson(
            json
          );
                case 'message.updated':
          return SesoriMessageUpdated.fromJson(
            json
          );
                case 'message.removed':
          return SesoriMessageRemoved.fromJson(
            json
          );
                case 'message.part.updated':
          return SesoriMessagePartUpdated.fromJson(
            json
          );
                case 'message.part.delta':
          return SesoriMessagePartDelta.fromJson(
            json
          );
                case 'message.part.removed':
          return SesoriMessagePartRemoved.fromJson(
            json
          );
                case 'pty.created':
          return SesoriPtyCreated.fromJson(
            json
          );
                case 'pty.updated':
          return SesoriPtyUpdated.fromJson(
            json
          );
                case 'pty.exited':
          return SesoriPtyExited.fromJson(
            json
          );
                case 'pty.deleted':
          return SesoriPtyDeleted.fromJson(
            json
          );
                case 'permission.asked':
          return SesoriPermissionAsked.fromJson(
            json
          );
                case 'permission.replied':
          return SesoriPermissionReplied.fromJson(
            json
          );
                case 'permission.updated':
          return SesoriPermissionUpdated.fromJson(
            json
          );
                case 'question.asked':
          return SesoriQuestionAsked.fromJson(
            json
          );
                case 'question.replied':
          return SesoriQuestionReplied.fromJson(
            json
          );
                case 'question.rejected':
          return SesoriQuestionRejected.fromJson(
            json
          );
                case 'todo.updated':
          return SesoriTodoUpdated.fromJson(
            json
          );
                case 'projects.summary':
          return SesoriProjectsSummary.fromJson(
            json
          );
                case 'project.updated':
          return SesoriProjectUpdated.fromJson(
            json
          );
                case 'vcs.branch.updated':
          return SesoriVcsBranchUpdated.fromJson(
            json
          );
                case 'sessions.updated':
          return SesoriSessionsUpdated.fromJson(
            json
          );
                case 'file.edited':
          return SesoriFileEdited.fromJson(
            json
          );
                case 'file.watcher.updated':
          return SesoriFileWatcherUpdated.fromJson(
            json
          );
                case 'lsp.updated':
          return SesoriLspUpdated.fromJson(
            json
          );
                case 'lsp.client.diagnostics':
          return SesoriLspClientDiagnostics.fromJson(
            json
          );
                case 'mcp.tools.changed':
          return SesoriMcpToolsChanged.fromJson(
            json
          );
                case 'mcp.browser.open.failed':
          return SesoriMcpBrowserOpenFailed.fromJson(
            json
          );
                case 'installation.updated':
          return SesoriInstallationUpdated.fromJson(
            json
          );
                case 'installation.update-available':
          return SesoriInstallationUpdateAvailable.fromJson(
            json
          );
                case 'workspace.ready':
          return SesoriWorkspaceReady.fromJson(
            json
          );
                case 'workspace.failed':
          return SesoriWorkspaceFailed.fromJson(
            json
          );
                case 'tui.toast.show':
          return SesoriTuiToastShow.fromJson(
            json
          );
                case 'worktree.ready':
          return SesoriWorktreeReady.fromJson(
            json
          );
                case 'worktree.failed':
          return SesoriWorktreeFailed.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'SesoriSseEvent',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$SesoriSseEvent {



  /// Serializes this SesoriSseEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSseEvent);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent()';
}


}

/// @nodoc
class $SesoriSseEventCopyWith<$Res>  {
$SesoriSseEventCopyWith(SesoriSseEvent _, $Res Function(SesoriSseEvent) __);
}



/// @nodoc
@JsonSerializable()

class SesoriServerConnected implements SesoriSseEvent {
  const SesoriServerConnected({final  String? $type}): $type = $type ?? 'server.connected';
  factory SesoriServerConnected.fromJson(Map<String, dynamic> json) => _$SesoriServerConnectedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriServerConnectedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriServerConnected);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.serverConnected()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriServerHeartbeat implements SesoriSseEvent {
  const SesoriServerHeartbeat({final  String? $type}): $type = $type ?? 'server.heartbeat';
  factory SesoriServerHeartbeat.fromJson(Map<String, dynamic> json) => _$SesoriServerHeartbeatFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriServerHeartbeatToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriServerHeartbeat);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.serverHeartbeat()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriServerInstanceDisposed implements SesoriSseEvent {
  const SesoriServerInstanceDisposed({this.directory, final  String? $type}): $type = $type ?? 'server.instance.disposed';
  factory SesoriServerInstanceDisposed.fromJson(Map<String, dynamic> json) => _$SesoriServerInstanceDisposedFromJson(json);

 final  String? directory;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriServerInstanceDisposedCopyWith<SesoriServerInstanceDisposed> get copyWith => _$SesoriServerInstanceDisposedCopyWithImpl<SesoriServerInstanceDisposed>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriServerInstanceDisposedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriServerInstanceDisposed&&(identical(other.directory, directory) || other.directory == directory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,directory);

@override
String toString() {
  return 'SesoriSseEvent.serverInstanceDisposed(directory: $directory)';
}


}

/// @nodoc
abstract mixin class $SesoriServerInstanceDisposedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriServerInstanceDisposedCopyWith(SesoriServerInstanceDisposed value, $Res Function(SesoriServerInstanceDisposed) _then) = _$SesoriServerInstanceDisposedCopyWithImpl;
@useResult
$Res call({
 String? directory
});




}
/// @nodoc
class _$SesoriServerInstanceDisposedCopyWithImpl<$Res>
    implements $SesoriServerInstanceDisposedCopyWith<$Res> {
  _$SesoriServerInstanceDisposedCopyWithImpl(this._self, this._then);

  final SesoriServerInstanceDisposed _self;
  final $Res Function(SesoriServerInstanceDisposed) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? directory = freezed,}) {
  return _then(SesoriServerInstanceDisposed(
directory: freezed == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriGlobalDisposed implements SesoriSseEvent {
  const SesoriGlobalDisposed({final  String? $type}): $type = $type ?? 'global.disposed';
  factory SesoriGlobalDisposed.fromJson(Map<String, dynamic> json) => _$SesoriGlobalDisposedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriGlobalDisposedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriGlobalDisposed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.globalDisposed()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriSessionCreated implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionCreated({required this.info, final  String? $type}): $type = $type ?? 'session.created';
  factory SesoriSessionCreated.fromJson(Map<String, dynamic> json) => _$SesoriSessionCreatedFromJson(json);

 final  Session info;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionCreatedCopyWith<SesoriSessionCreated> get copyWith => _$SesoriSessionCreatedCopyWithImpl<SesoriSessionCreated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionCreatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionCreated&&(identical(other.info, info) || other.info == info));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info);

@override
String toString() {
  return 'SesoriSseEvent.sessionCreated(info: $info)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionCreatedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionCreatedCopyWith(SesoriSessionCreated value, $Res Function(SesoriSessionCreated) _then) = _$SesoriSessionCreatedCopyWithImpl;
@useResult
$Res call({
 Session info
});


$SessionCopyWith<$Res> get info;

}
/// @nodoc
class _$SesoriSessionCreatedCopyWithImpl<$Res>
    implements $SesoriSessionCreatedCopyWith<$Res> {
  _$SesoriSessionCreatedCopyWithImpl(this._self, this._then);

  final SesoriSessionCreated _self;
  final $Res Function(SesoriSessionCreated) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? info = null,}) {
  return _then(SesoriSessionCreated(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of SesoriSseEvent
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

class SesoriSessionUpdated implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionUpdated({required this.info, final  String? $type}): $type = $type ?? 'session.updated';
  factory SesoriSessionUpdated.fromJson(Map<String, dynamic> json) => _$SesoriSessionUpdatedFromJson(json);

 final  Session info;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionUpdatedCopyWith<SesoriSessionUpdated> get copyWith => _$SesoriSessionUpdatedCopyWithImpl<SesoriSessionUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionUpdated&&(identical(other.info, info) || other.info == info));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info);

@override
String toString() {
  return 'SesoriSseEvent.sessionUpdated(info: $info)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionUpdatedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionUpdatedCopyWith(SesoriSessionUpdated value, $Res Function(SesoriSessionUpdated) _then) = _$SesoriSessionUpdatedCopyWithImpl;
@useResult
$Res call({
 Session info
});


$SessionCopyWith<$Res> get info;

}
/// @nodoc
class _$SesoriSessionUpdatedCopyWithImpl<$Res>
    implements $SesoriSessionUpdatedCopyWith<$Res> {
  _$SesoriSessionUpdatedCopyWithImpl(this._self, this._then);

  final SesoriSessionUpdated _self;
  final $Res Function(SesoriSessionUpdated) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? info = null,}) {
  return _then(SesoriSessionUpdated(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of SesoriSseEvent
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

class SesoriSessionDeleted implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionDeleted({required this.info, final  String? $type}): $type = $type ?? 'session.deleted';
  factory SesoriSessionDeleted.fromJson(Map<String, dynamic> json) => _$SesoriSessionDeletedFromJson(json);

 final  Session info;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionDeletedCopyWith<SesoriSessionDeleted> get copyWith => _$SesoriSessionDeletedCopyWithImpl<SesoriSessionDeleted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionDeletedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionDeleted&&(identical(other.info, info) || other.info == info));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info);

@override
String toString() {
  return 'SesoriSseEvent.sessionDeleted(info: $info)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionDeletedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionDeletedCopyWith(SesoriSessionDeleted value, $Res Function(SesoriSessionDeleted) _then) = _$SesoriSessionDeletedCopyWithImpl;
@useResult
$Res call({
 Session info
});


$SessionCopyWith<$Res> get info;

}
/// @nodoc
class _$SesoriSessionDeletedCopyWithImpl<$Res>
    implements $SesoriSessionDeletedCopyWith<$Res> {
  _$SesoriSessionDeletedCopyWithImpl(this._self, this._then);

  final SesoriSessionDeleted _self;
  final $Res Function(SesoriSessionDeleted) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? info = null,}) {
  return _then(SesoriSessionDeleted(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of SesoriSseEvent
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

class SesoriSessionDiff implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionDiff({required this.sessionID, final  String? $type}): $type = $type ?? 'session.diff';
  factory SesoriSessionDiff.fromJson(Map<String, dynamic> json) => _$SesoriSessionDiffFromJson(json);

 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionDiffCopyWith<SesoriSessionDiff> get copyWith => _$SesoriSessionDiffCopyWithImpl<SesoriSessionDiff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionDiffToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionDiff&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID);

@override
String toString() {
  return 'SesoriSseEvent.sessionDiff(sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionDiffCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionDiffCopyWith(SesoriSessionDiff value, $Res Function(SesoriSessionDiff) _then) = _$SesoriSessionDiffCopyWithImpl;
@useResult
$Res call({
 String sessionID
});




}
/// @nodoc
class _$SesoriSessionDiffCopyWithImpl<$Res>
    implements $SesoriSessionDiffCopyWith<$Res> {
  _$SesoriSessionDiffCopyWithImpl(this._self, this._then);

  final SesoriSessionDiff _self;
  final $Res Function(SesoriSessionDiff) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,}) {
  return _then(SesoriSessionDiff(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriSessionError implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionError({required this.sessionID, required this.error, final  String? $type}): $type = $type ?? 'session.error';
  factory SesoriSessionError.fromJson(Map<String, dynamic> json) => _$SesoriSessionErrorFromJson(json);

 final  String? sessionID;
 final  SessionError? error;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionErrorCopyWith<SesoriSessionError> get copyWith => _$SesoriSessionErrorCopyWithImpl<SesoriSessionError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionError&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,error);

@override
String toString() {
  return 'SesoriSseEvent.sessionError(sessionID: $sessionID, error: $error)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionErrorCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionErrorCopyWith(SesoriSessionError value, $Res Function(SesoriSessionError) _then) = _$SesoriSessionErrorCopyWithImpl;
@useResult
$Res call({
 String? sessionID, SessionError? error
});


$SessionErrorCopyWith<$Res>? get error;

}
/// @nodoc
class _$SesoriSessionErrorCopyWithImpl<$Res>
    implements $SesoriSessionErrorCopyWith<$Res> {
  _$SesoriSessionErrorCopyWithImpl(this._self, this._then);

  final SesoriSessionError _self;
  final $Res Function(SesoriSessionError) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = freezed,Object? error = freezed,}) {
  return _then(SesoriSessionError(
sessionID: freezed == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as SessionError?,
  ));
}

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionErrorCopyWith<$Res>? get error {
    if (_self.error == null) {
    return null;
  }

  return $SessionErrorCopyWith<$Res>(_self.error!, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SesoriSessionCompacted implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionCompacted({required this.sessionID, final  String? $type}): $type = $type ?? 'session.compacted';
  factory SesoriSessionCompacted.fromJson(Map<String, dynamic> json) => _$SesoriSessionCompactedFromJson(json);

 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionCompactedCopyWith<SesoriSessionCompacted> get copyWith => _$SesoriSessionCompactedCopyWithImpl<SesoriSessionCompacted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionCompactedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionCompacted&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID);

@override
String toString() {
  return 'SesoriSseEvent.sessionCompacted(sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionCompactedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionCompactedCopyWith(SesoriSessionCompacted value, $Res Function(SesoriSessionCompacted) _then) = _$SesoriSessionCompactedCopyWithImpl;
@useResult
$Res call({
 String sessionID
});




}
/// @nodoc
class _$SesoriSessionCompactedCopyWithImpl<$Res>
    implements $SesoriSessionCompactedCopyWith<$Res> {
  _$SesoriSessionCompactedCopyWithImpl(this._self, this._then);

  final SesoriSessionCompacted _self;
  final $Res Function(SesoriSessionCompacted) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,}) {
  return _then(SesoriSessionCompacted(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriSessionStatus implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionStatus({required this.sessionID, required this.status, final  String? $type}): $type = $type ?? 'session.status';
  factory SesoriSessionStatus.fromJson(Map<String, dynamic> json) => _$SesoriSessionStatusFromJson(json);

 final  String sessionID;
 final  SessionStatus status;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionStatusCopyWith<SesoriSessionStatus> get copyWith => _$SesoriSessionStatusCopyWithImpl<SesoriSessionStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionStatus&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,status);

@override
String toString() {
  return 'SesoriSseEvent.sessionStatus(sessionID: $sessionID, status: $status)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionStatusCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionStatusCopyWith(SesoriSessionStatus value, $Res Function(SesoriSessionStatus) _then) = _$SesoriSessionStatusCopyWithImpl;
@useResult
$Res call({
 String sessionID, SessionStatus status
});


$SessionStatusCopyWith<$Res> get status;

}
/// @nodoc
class _$SesoriSessionStatusCopyWithImpl<$Res>
    implements $SesoriSessionStatusCopyWith<$Res> {
  _$SesoriSessionStatusCopyWithImpl(this._self, this._then);

  final SesoriSessionStatus _self;
  final $Res Function(SesoriSessionStatus) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? status = null,}) {
  return _then(SesoriSessionStatus(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SessionStatus,
  ));
}

/// Create a copy of SesoriSseEvent
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
class SesoriSessionIdle implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionIdle({required this.sessionID, final  String? $type}): $type = $type ?? 'session.idle';
  factory SesoriSessionIdle.fromJson(Map<String, dynamic> json) => _$SesoriSessionIdleFromJson(json);

 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionIdleCopyWith<SesoriSessionIdle> get copyWith => _$SesoriSessionIdleCopyWithImpl<SesoriSessionIdle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionIdleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionIdle&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID);

@override
String toString() {
  return 'SesoriSseEvent.sessionIdle(sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionIdleCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionIdleCopyWith(SesoriSessionIdle value, $Res Function(SesoriSessionIdle) _then) = _$SesoriSessionIdleCopyWithImpl;
@useResult
$Res call({
 String sessionID
});




}
/// @nodoc
class _$SesoriSessionIdleCopyWithImpl<$Res>
    implements $SesoriSessionIdleCopyWith<$Res> {
  _$SesoriSessionIdleCopyWithImpl(this._self, this._then);

  final SesoriSessionIdle _self;
  final $Res Function(SesoriSessionIdle) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,}) {
  return _then(SesoriSessionIdle(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriCommandExecuted implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriCommandExecuted({required this.name, required this.sessionID, required this.arguments, required this.messageID, final  String? $type}): $type = $type ?? 'command.executed';
  factory SesoriCommandExecuted.fromJson(Map<String, dynamic> json) => _$SesoriCommandExecutedFromJson(json);

 final  String name;
 final  String sessionID;
 final  String arguments;
 final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriCommandExecutedCopyWith<SesoriCommandExecuted> get copyWith => _$SesoriCommandExecutedCopyWithImpl<SesoriCommandExecuted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriCommandExecutedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriCommandExecuted&&(identical(other.name, name) || other.name == name)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.arguments, arguments) || other.arguments == arguments)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,sessionID,arguments,messageID);

@override
String toString() {
  return 'SesoriSseEvent.commandExecuted(name: $name, sessionID: $sessionID, arguments: $arguments, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $SesoriCommandExecutedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriCommandExecutedCopyWith(SesoriCommandExecuted value, $Res Function(SesoriCommandExecuted) _then) = _$SesoriCommandExecutedCopyWithImpl;
@useResult
$Res call({
 String name, String sessionID, String arguments, String messageID
});




}
/// @nodoc
class _$SesoriCommandExecutedCopyWithImpl<$Res>
    implements $SesoriCommandExecutedCopyWith<$Res> {
  _$SesoriCommandExecutedCopyWithImpl(this._self, this._then);

  final SesoriCommandExecuted _self;
  final $Res Function(SesoriCommandExecuted) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? sessionID = null,Object? arguments = null,Object? messageID = null,}) {
  return _then(SesoriCommandExecuted(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,arguments: null == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriMessageUpdated implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriMessageUpdated({required this.info, final  String? $type}): $type = $type ?? 'message.updated';
  factory SesoriMessageUpdated.fromJson(Map<String, dynamic> json) => _$SesoriMessageUpdatedFromJson(json);

 final  Message info;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriMessageUpdatedCopyWith<SesoriMessageUpdated> get copyWith => _$SesoriMessageUpdatedCopyWithImpl<SesoriMessageUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriMessageUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriMessageUpdated&&(identical(other.info, info) || other.info == info));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info);

@override
String toString() {
  return 'SesoriSseEvent.messageUpdated(info: $info)';
}


}

/// @nodoc
abstract mixin class $SesoriMessageUpdatedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriMessageUpdatedCopyWith(SesoriMessageUpdated value, $Res Function(SesoriMessageUpdated) _then) = _$SesoriMessageUpdatedCopyWithImpl;
@useResult
$Res call({
 Message info
});


$MessageCopyWith<$Res> get info;

}
/// @nodoc
class _$SesoriMessageUpdatedCopyWithImpl<$Res>
    implements $SesoriMessageUpdatedCopyWith<$Res> {
  _$SesoriMessageUpdatedCopyWithImpl(this._self, this._then);

  final SesoriMessageUpdated _self;
  final $Res Function(SesoriMessageUpdated) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? info = null,}) {
  return _then(SesoriMessageUpdated(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Message,
  ));
}

/// Create a copy of SesoriSseEvent
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

class SesoriMessageRemoved implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriMessageRemoved({required this.sessionID, required this.messageID, final  String? $type}): $type = $type ?? 'message.removed';
  factory SesoriMessageRemoved.fromJson(Map<String, dynamic> json) => _$SesoriMessageRemovedFromJson(json);

 final  String sessionID;
 final  String messageID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriMessageRemovedCopyWith<SesoriMessageRemoved> get copyWith => _$SesoriMessageRemovedCopyWithImpl<SesoriMessageRemoved>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriMessageRemovedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriMessageRemoved&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,messageID);

@override
String toString() {
  return 'SesoriSseEvent.messageRemoved(sessionID: $sessionID, messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class $SesoriMessageRemovedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriMessageRemovedCopyWith(SesoriMessageRemoved value, $Res Function(SesoriMessageRemoved) _then) = _$SesoriMessageRemovedCopyWithImpl;
@useResult
$Res call({
 String sessionID, String messageID
});




}
/// @nodoc
class _$SesoriMessageRemovedCopyWithImpl<$Res>
    implements $SesoriMessageRemovedCopyWith<$Res> {
  _$SesoriMessageRemovedCopyWithImpl(this._self, this._then);

  final SesoriMessageRemoved _self;
  final $Res Function(SesoriMessageRemoved) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? messageID = null,}) {
  return _then(SesoriMessageRemoved(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriMessagePartUpdated implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriMessagePartUpdated({required this.part, final  String? $type}): $type = $type ?? 'message.part.updated';
  factory SesoriMessagePartUpdated.fromJson(Map<String, dynamic> json) => _$SesoriMessagePartUpdatedFromJson(json);

 final  MessagePart part;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriMessagePartUpdatedCopyWith<SesoriMessagePartUpdated> get copyWith => _$SesoriMessagePartUpdatedCopyWithImpl<SesoriMessagePartUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriMessagePartUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriMessagePartUpdated&&(identical(other.part, part) || other.part == part));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,part);

@override
String toString() {
  return 'SesoriSseEvent.messagePartUpdated(part: $part)';
}


}

/// @nodoc
abstract mixin class $SesoriMessagePartUpdatedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriMessagePartUpdatedCopyWith(SesoriMessagePartUpdated value, $Res Function(SesoriMessagePartUpdated) _then) = _$SesoriMessagePartUpdatedCopyWithImpl;
@useResult
$Res call({
 MessagePart part
});


$MessagePartCopyWith<$Res> get part;

}
/// @nodoc
class _$SesoriMessagePartUpdatedCopyWithImpl<$Res>
    implements $SesoriMessagePartUpdatedCopyWith<$Res> {
  _$SesoriMessagePartUpdatedCopyWithImpl(this._self, this._then);

  final SesoriMessagePartUpdated _self;
  final $Res Function(SesoriMessagePartUpdated) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? part = null,}) {
  return _then(SesoriMessagePartUpdated(
part: null == part ? _self.part : part // ignore: cast_nullable_to_non_nullable
as MessagePart,
  ));
}

/// Create a copy of SesoriSseEvent
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

class SesoriMessagePartDelta implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriMessagePartDelta({required this.sessionID, required this.messageID, required this.partID, required this.field, required this.delta, final  String? $type}): $type = $type ?? 'message.part.delta';
  factory SesoriMessagePartDelta.fromJson(Map<String, dynamic> json) => _$SesoriMessagePartDeltaFromJson(json);

 final  String sessionID;
 final  String messageID;
 final  String partID;
 final  String field;
 final  String delta;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriMessagePartDeltaCopyWith<SesoriMessagePartDelta> get copyWith => _$SesoriMessagePartDeltaCopyWithImpl<SesoriMessagePartDelta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriMessagePartDeltaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriMessagePartDelta&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.partID, partID) || other.partID == partID)&&(identical(other.field, field) || other.field == field)&&(identical(other.delta, delta) || other.delta == delta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,messageID,partID,field,delta);

@override
String toString() {
  return 'SesoriSseEvent.messagePartDelta(sessionID: $sessionID, messageID: $messageID, partID: $partID, field: $field, delta: $delta)';
}


}

/// @nodoc
abstract mixin class $SesoriMessagePartDeltaCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriMessagePartDeltaCopyWith(SesoriMessagePartDelta value, $Res Function(SesoriMessagePartDelta) _then) = _$SesoriMessagePartDeltaCopyWithImpl;
@useResult
$Res call({
 String sessionID, String messageID, String partID, String field, String delta
});




}
/// @nodoc
class _$SesoriMessagePartDeltaCopyWithImpl<$Res>
    implements $SesoriMessagePartDeltaCopyWith<$Res> {
  _$SesoriMessagePartDeltaCopyWithImpl(this._self, this._then);

  final SesoriMessagePartDelta _self;
  final $Res Function(SesoriMessagePartDelta) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? messageID = null,Object? partID = null,Object? field = null,Object? delta = null,}) {
  return _then(SesoriMessagePartDelta(
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

class SesoriMessagePartRemoved implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriMessagePartRemoved({required this.sessionID, required this.messageID, required this.partID, final  String? $type}): $type = $type ?? 'message.part.removed';
  factory SesoriMessagePartRemoved.fromJson(Map<String, dynamic> json) => _$SesoriMessagePartRemovedFromJson(json);

 final  String sessionID;
 final  String messageID;
 final  String partID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriMessagePartRemovedCopyWith<SesoriMessagePartRemoved> get copyWith => _$SesoriMessagePartRemovedCopyWithImpl<SesoriMessagePartRemoved>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriMessagePartRemovedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriMessagePartRemoved&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.messageID, messageID) || other.messageID == messageID)&&(identical(other.partID, partID) || other.partID == partID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,messageID,partID);

@override
String toString() {
  return 'SesoriSseEvent.messagePartRemoved(sessionID: $sessionID, messageID: $messageID, partID: $partID)';
}


}

/// @nodoc
abstract mixin class $SesoriMessagePartRemovedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriMessagePartRemovedCopyWith(SesoriMessagePartRemoved value, $Res Function(SesoriMessagePartRemoved) _then) = _$SesoriMessagePartRemovedCopyWithImpl;
@useResult
$Res call({
 String sessionID, String messageID, String partID
});




}
/// @nodoc
class _$SesoriMessagePartRemovedCopyWithImpl<$Res>
    implements $SesoriMessagePartRemovedCopyWith<$Res> {
  _$SesoriMessagePartRemovedCopyWithImpl(this._self, this._then);

  final SesoriMessagePartRemoved _self;
  final $Res Function(SesoriMessagePartRemoved) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? messageID = null,Object? partID = null,}) {
  return _then(SesoriMessagePartRemoved(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,partID: null == partID ? _self.partID : partID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriPtyCreated implements SesoriSseEvent {
  const SesoriPtyCreated({final  String? $type}): $type = $type ?? 'pty.created';
  factory SesoriPtyCreated.fromJson(Map<String, dynamic> json) => _$SesoriPtyCreatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriPtyCreatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPtyCreated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.ptyCreated()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriPtyUpdated implements SesoriSseEvent {
  const SesoriPtyUpdated({final  String? $type}): $type = $type ?? 'pty.updated';
  factory SesoriPtyUpdated.fromJson(Map<String, dynamic> json) => _$SesoriPtyUpdatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriPtyUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPtyUpdated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.ptyUpdated()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriPtyExited implements SesoriSseEvent {
  const SesoriPtyExited({required this.id, required this.exitCode, final  String? $type}): $type = $type ?? 'pty.exited';
  factory SesoriPtyExited.fromJson(Map<String, dynamic> json) => _$SesoriPtyExitedFromJson(json);

 final  String? id;
 final  int? exitCode;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriPtyExitedCopyWith<SesoriPtyExited> get copyWith => _$SesoriPtyExitedCopyWithImpl<SesoriPtyExited>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriPtyExitedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPtyExited&&(identical(other.id, id) || other.id == id)&&(identical(other.exitCode, exitCode) || other.exitCode == exitCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,exitCode);

@override
String toString() {
  return 'SesoriSseEvent.ptyExited(id: $id, exitCode: $exitCode)';
}


}

/// @nodoc
abstract mixin class $SesoriPtyExitedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriPtyExitedCopyWith(SesoriPtyExited value, $Res Function(SesoriPtyExited) _then) = _$SesoriPtyExitedCopyWithImpl;
@useResult
$Res call({
 String? id, int? exitCode
});




}
/// @nodoc
class _$SesoriPtyExitedCopyWithImpl<$Res>
    implements $SesoriPtyExitedCopyWith<$Res> {
  _$SesoriPtyExitedCopyWithImpl(this._self, this._then);

  final SesoriPtyExited _self;
  final $Res Function(SesoriPtyExited) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? exitCode = freezed,}) {
  return _then(SesoriPtyExited(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,exitCode: freezed == exitCode ? _self.exitCode : exitCode // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriPtyDeleted implements SesoriSseEvent {
  const SesoriPtyDeleted({this.id, final  String? $type}): $type = $type ?? 'pty.deleted';
  factory SesoriPtyDeleted.fromJson(Map<String, dynamic> json) => _$SesoriPtyDeletedFromJson(json);

 final  String? id;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriPtyDeletedCopyWith<SesoriPtyDeleted> get copyWith => _$SesoriPtyDeletedCopyWithImpl<SesoriPtyDeleted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriPtyDeletedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPtyDeleted&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'SesoriSseEvent.ptyDeleted(id: $id)';
}


}

/// @nodoc
abstract mixin class $SesoriPtyDeletedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriPtyDeletedCopyWith(SesoriPtyDeleted value, $Res Function(SesoriPtyDeleted) _then) = _$SesoriPtyDeletedCopyWithImpl;
@useResult
$Res call({
 String? id
});




}
/// @nodoc
class _$SesoriPtyDeletedCopyWithImpl<$Res>
    implements $SesoriPtyDeletedCopyWith<$Res> {
  _$SesoriPtyDeletedCopyWithImpl(this._self, this._then);

  final SesoriPtyDeleted _self;
  final $Res Function(SesoriPtyDeleted) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,}) {
  return _then(SesoriPtyDeleted(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriPermissionAsked implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriPermissionAsked({required this.requestID, required this.sessionID, required this.tool, required this.description, final  String? $type}): $type = $type ?? 'permission.asked';
  factory SesoriPermissionAsked.fromJson(Map<String, dynamic> json) => _$SesoriPermissionAskedFromJson(json);

 final  String requestID;
 final  String sessionID;
 final  String tool;
 final  String description;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriPermissionAskedCopyWith<SesoriPermissionAsked> get copyWith => _$SesoriPermissionAskedCopyWithImpl<SesoriPermissionAsked>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriPermissionAskedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPermissionAsked&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID,tool,description);

@override
String toString() {
  return 'SesoriSseEvent.permissionAsked(requestID: $requestID, sessionID: $sessionID, tool: $tool, description: $description)';
}


}

/// @nodoc
abstract mixin class $SesoriPermissionAskedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriPermissionAskedCopyWith(SesoriPermissionAsked value, $Res Function(SesoriPermissionAsked) _then) = _$SesoriPermissionAskedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID, String tool, String description
});




}
/// @nodoc
class _$SesoriPermissionAskedCopyWithImpl<$Res>
    implements $SesoriPermissionAskedCopyWith<$Res> {
  _$SesoriPermissionAskedCopyWithImpl(this._self, this._then);

  final SesoriPermissionAsked _self;
  final $Res Function(SesoriPermissionAsked) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,Object? tool = null,Object? description = null,}) {
  return _then(SesoriPermissionAsked(
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

class SesoriPermissionReplied implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriPermissionReplied({required this.requestID, required this.sessionID, required this.reply, final  String? $type}): $type = $type ?? 'permission.replied';
  factory SesoriPermissionReplied.fromJson(Map<String, dynamic> json) => _$SesoriPermissionRepliedFromJson(json);

 final  String requestID;
 final  String sessionID;
 final  String reply;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriPermissionRepliedCopyWith<SesoriPermissionReplied> get copyWith => _$SesoriPermissionRepliedCopyWithImpl<SesoriPermissionReplied>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriPermissionRepliedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPermissionReplied&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.reply, reply) || other.reply == reply));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID,reply);

@override
String toString() {
  return 'SesoriSseEvent.permissionReplied(requestID: $requestID, sessionID: $sessionID, reply: $reply)';
}


}

/// @nodoc
abstract mixin class $SesoriPermissionRepliedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriPermissionRepliedCopyWith(SesoriPermissionReplied value, $Res Function(SesoriPermissionReplied) _then) = _$SesoriPermissionRepliedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID, String reply
});




}
/// @nodoc
class _$SesoriPermissionRepliedCopyWithImpl<$Res>
    implements $SesoriPermissionRepliedCopyWith<$Res> {
  _$SesoriPermissionRepliedCopyWithImpl(this._self, this._then);

  final SesoriPermissionReplied _self;
  final $Res Function(SesoriPermissionReplied) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,Object? reply = null,}) {
  return _then(SesoriPermissionReplied(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,reply: null == reply ? _self.reply : reply // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriPermissionUpdated implements SesoriSseEvent {
  const SesoriPermissionUpdated({final  String? $type}): $type = $type ?? 'permission.updated';
  factory SesoriPermissionUpdated.fromJson(Map<String, dynamic> json) => _$SesoriPermissionUpdatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriPermissionUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPermissionUpdated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.permissionUpdated()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriQuestionAsked implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriQuestionAsked({required this.id, required this.sessionID, required final  List<QuestionInfo> questions, final  String? $type}): _questions = questions,$type = $type ?? 'question.asked';
  factory SesoriQuestionAsked.fromJson(Map<String, dynamic> json) => _$SesoriQuestionAskedFromJson(json);

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


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriQuestionAskedCopyWith<SesoriQuestionAsked> get copyWith => _$SesoriQuestionAskedCopyWithImpl<SesoriQuestionAsked>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriQuestionAskedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriQuestionAsked&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&const DeepCollectionEquality().equals(other._questions, _questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,const DeepCollectionEquality().hash(_questions));

@override
String toString() {
  return 'SesoriSseEvent.questionAsked(id: $id, sessionID: $sessionID, questions: $questions)';
}


}

/// @nodoc
abstract mixin class $SesoriQuestionAskedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriQuestionAskedCopyWith(SesoriQuestionAsked value, $Res Function(SesoriQuestionAsked) _then) = _$SesoriQuestionAskedCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, List<QuestionInfo> questions
});




}
/// @nodoc
class _$SesoriQuestionAskedCopyWithImpl<$Res>
    implements $SesoriQuestionAskedCopyWith<$Res> {
  _$SesoriQuestionAskedCopyWithImpl(this._self, this._then);

  final SesoriQuestionAsked _self;
  final $Res Function(SesoriQuestionAsked) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? questions = null,}) {
  return _then(SesoriQuestionAsked(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<QuestionInfo>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriQuestionReplied implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriQuestionReplied({required this.requestID, required this.sessionID, final  String? $type}): $type = $type ?? 'question.replied';
  factory SesoriQuestionReplied.fromJson(Map<String, dynamic> json) => _$SesoriQuestionRepliedFromJson(json);

 final  String requestID;
 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriQuestionRepliedCopyWith<SesoriQuestionReplied> get copyWith => _$SesoriQuestionRepliedCopyWithImpl<SesoriQuestionReplied>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriQuestionRepliedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriQuestionReplied&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID);

@override
String toString() {
  return 'SesoriSseEvent.questionReplied(requestID: $requestID, sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SesoriQuestionRepliedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriQuestionRepliedCopyWith(SesoriQuestionReplied value, $Res Function(SesoriQuestionReplied) _then) = _$SesoriQuestionRepliedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID
});




}
/// @nodoc
class _$SesoriQuestionRepliedCopyWithImpl<$Res>
    implements $SesoriQuestionRepliedCopyWith<$Res> {
  _$SesoriQuestionRepliedCopyWithImpl(this._self, this._then);

  final SesoriQuestionReplied _self;
  final $Res Function(SesoriQuestionReplied) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,}) {
  return _then(SesoriQuestionReplied(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriQuestionRejected implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriQuestionRejected({required this.requestID, required this.sessionID, final  String? $type}): $type = $type ?? 'question.rejected';
  factory SesoriQuestionRejected.fromJson(Map<String, dynamic> json) => _$SesoriQuestionRejectedFromJson(json);

 final  String requestID;
 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriQuestionRejectedCopyWith<SesoriQuestionRejected> get copyWith => _$SesoriQuestionRejectedCopyWithImpl<SesoriQuestionRejected>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriQuestionRejectedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriQuestionRejected&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID);

@override
String toString() {
  return 'SesoriSseEvent.questionRejected(requestID: $requestID, sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SesoriQuestionRejectedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriQuestionRejectedCopyWith(SesoriQuestionRejected value, $Res Function(SesoriQuestionRejected) _then) = _$SesoriQuestionRejectedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID
});




}
/// @nodoc
class _$SesoriQuestionRejectedCopyWithImpl<$Res>
    implements $SesoriQuestionRejectedCopyWith<$Res> {
  _$SesoriQuestionRejectedCopyWithImpl(this._self, this._then);

  final SesoriQuestionRejected _self;
  final $Res Function(SesoriQuestionRejected) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,}) {
  return _then(SesoriQuestionRejected(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriTodoUpdated implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriTodoUpdated({required this.sessionID, final  String? $type}): $type = $type ?? 'todo.updated';
  factory SesoriTodoUpdated.fromJson(Map<String, dynamic> json) => _$SesoriTodoUpdatedFromJson(json);

 final  String sessionID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriTodoUpdatedCopyWith<SesoriTodoUpdated> get copyWith => _$SesoriTodoUpdatedCopyWithImpl<SesoriTodoUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriTodoUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriTodoUpdated&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID);

@override
String toString() {
  return 'SesoriSseEvent.todoUpdated(sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SesoriTodoUpdatedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriTodoUpdatedCopyWith(SesoriTodoUpdated value, $Res Function(SesoriTodoUpdated) _then) = _$SesoriTodoUpdatedCopyWithImpl;
@useResult
$Res call({
 String sessionID
});




}
/// @nodoc
class _$SesoriTodoUpdatedCopyWithImpl<$Res>
    implements $SesoriTodoUpdatedCopyWith<$Res> {
  _$SesoriTodoUpdatedCopyWithImpl(this._self, this._then);

  final SesoriTodoUpdated _self;
  final $Res Function(SesoriTodoUpdated) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,}) {
  return _then(SesoriTodoUpdated(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriProjectsSummary implements SesoriSseEvent {
  const SesoriProjectsSummary({required final  List<ProjectActivitySummary> projects, final  String? $type}): _projects = projects,$type = $type ?? 'projects.summary';
  factory SesoriProjectsSummary.fromJson(Map<String, dynamic> json) => _$SesoriProjectsSummaryFromJson(json);

 final  List<ProjectActivitySummary> _projects;
 List<ProjectActivitySummary> get projects {
  if (_projects is EqualUnmodifiableListView) return _projects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_projects);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriProjectsSummaryCopyWith<SesoriProjectsSummary> get copyWith => _$SesoriProjectsSummaryCopyWithImpl<SesoriProjectsSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriProjectsSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriProjectsSummary&&const DeepCollectionEquality().equals(other._projects, _projects));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_projects));

@override
String toString() {
  return 'SesoriSseEvent.projectsSummary(projects: $projects)';
}


}

/// @nodoc
abstract mixin class $SesoriProjectsSummaryCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriProjectsSummaryCopyWith(SesoriProjectsSummary value, $Res Function(SesoriProjectsSummary) _then) = _$SesoriProjectsSummaryCopyWithImpl;
@useResult
$Res call({
 List<ProjectActivitySummary> projects
});




}
/// @nodoc
class _$SesoriProjectsSummaryCopyWithImpl<$Res>
    implements $SesoriProjectsSummaryCopyWith<$Res> {
  _$SesoriProjectsSummaryCopyWithImpl(this._self, this._then);

  final SesoriProjectsSummary _self;
  final $Res Function(SesoriProjectsSummary) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projects = null,}) {
  return _then(SesoriProjectsSummary(
projects: null == projects ? _self._projects : projects // ignore: cast_nullable_to_non_nullable
as List<ProjectActivitySummary>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriProjectUpdated implements SesoriSseEvent {
  const SesoriProjectUpdated({final  String? $type}): $type = $type ?? 'project.updated';
  factory SesoriProjectUpdated.fromJson(Map<String, dynamic> json) => _$SesoriProjectUpdatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriProjectUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriProjectUpdated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.projectUpdated()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriVcsBranchUpdated implements SesoriSseEvent {
  const SesoriVcsBranchUpdated({final  String? $type}): $type = $type ?? 'vcs.branch.updated';
  factory SesoriVcsBranchUpdated.fromJson(Map<String, dynamic> json) => _$SesoriVcsBranchUpdatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriVcsBranchUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriVcsBranchUpdated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.vcsBranchUpdated()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriSessionsUpdated implements SesoriSseEvent {
  const SesoriSessionsUpdated({required this.projectID, final  String? $type}): $type = $type ?? 'sessions.updated';
  factory SesoriSessionsUpdated.fromJson(Map<String, dynamic> json) => _$SesoriSessionsUpdatedFromJson(json);

 final  String projectID;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionsUpdatedCopyWith<SesoriSessionsUpdated> get copyWith => _$SesoriSessionsUpdatedCopyWithImpl<SesoriSessionsUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionsUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionsUpdated&&(identical(other.projectID, projectID) || other.projectID == projectID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectID);

@override
String toString() {
  return 'SesoriSseEvent.sessionsUpdated(projectID: $projectID)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionsUpdatedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionsUpdatedCopyWith(SesoriSessionsUpdated value, $Res Function(SesoriSessionsUpdated) _then) = _$SesoriSessionsUpdatedCopyWithImpl;
@useResult
$Res call({
 String projectID
});




}
/// @nodoc
class _$SesoriSessionsUpdatedCopyWithImpl<$Res>
    implements $SesoriSessionsUpdatedCopyWith<$Res> {
  _$SesoriSessionsUpdatedCopyWithImpl(this._self, this._then);

  final SesoriSessionsUpdated _self;
  final $Res Function(SesoriSessionsUpdated) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projectID = null,}) {
  return _then(SesoriSessionsUpdated(
projectID: null == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriFileEdited implements SesoriSseEvent {
  const SesoriFileEdited({this.file, final  String? $type}): $type = $type ?? 'file.edited';
  factory SesoriFileEdited.fromJson(Map<String, dynamic> json) => _$SesoriFileEditedFromJson(json);

 final  String? file;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriFileEditedCopyWith<SesoriFileEdited> get copyWith => _$SesoriFileEditedCopyWithImpl<SesoriFileEdited>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriFileEditedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriFileEdited&&(identical(other.file, file) || other.file == file));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file);

@override
String toString() {
  return 'SesoriSseEvent.fileEdited(file: $file)';
}


}

/// @nodoc
abstract mixin class $SesoriFileEditedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriFileEditedCopyWith(SesoriFileEdited value, $Res Function(SesoriFileEdited) _then) = _$SesoriFileEditedCopyWithImpl;
@useResult
$Res call({
 String? file
});




}
/// @nodoc
class _$SesoriFileEditedCopyWithImpl<$Res>
    implements $SesoriFileEditedCopyWith<$Res> {
  _$SesoriFileEditedCopyWithImpl(this._self, this._then);

  final SesoriFileEdited _self;
  final $Res Function(SesoriFileEdited) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? file = freezed,}) {
  return _then(SesoriFileEdited(
file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriFileWatcherUpdated implements SesoriSseEvent {
  const SesoriFileWatcherUpdated({required this.file, required this.event, final  String? $type}): $type = $type ?? 'file.watcher.updated';
  factory SesoriFileWatcherUpdated.fromJson(Map<String, dynamic> json) => _$SesoriFileWatcherUpdatedFromJson(json);

 final  String? file;
 final  String? event;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriFileWatcherUpdatedCopyWith<SesoriFileWatcherUpdated> get copyWith => _$SesoriFileWatcherUpdatedCopyWithImpl<SesoriFileWatcherUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriFileWatcherUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriFileWatcherUpdated&&(identical(other.file, file) || other.file == file)&&(identical(other.event, event) || other.event == event));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,event);

@override
String toString() {
  return 'SesoriSseEvent.fileWatcherUpdated(file: $file, event: $event)';
}


}

/// @nodoc
abstract mixin class $SesoriFileWatcherUpdatedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriFileWatcherUpdatedCopyWith(SesoriFileWatcherUpdated value, $Res Function(SesoriFileWatcherUpdated) _then) = _$SesoriFileWatcherUpdatedCopyWithImpl;
@useResult
$Res call({
 String? file, String? event
});




}
/// @nodoc
class _$SesoriFileWatcherUpdatedCopyWithImpl<$Res>
    implements $SesoriFileWatcherUpdatedCopyWith<$Res> {
  _$SesoriFileWatcherUpdatedCopyWithImpl(this._self, this._then);

  final SesoriFileWatcherUpdated _self;
  final $Res Function(SesoriFileWatcherUpdated) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? file = freezed,Object? event = freezed,}) {
  return _then(SesoriFileWatcherUpdated(
file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,event: freezed == event ? _self.event : event // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriLspUpdated implements SesoriSseEvent {
  const SesoriLspUpdated({final  String? $type}): $type = $type ?? 'lsp.updated';
  factory SesoriLspUpdated.fromJson(Map<String, dynamic> json) => _$SesoriLspUpdatedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriLspUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriLspUpdated);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.lspUpdated()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriLspClientDiagnostics implements SesoriSseEvent {
  const SesoriLspClientDiagnostics({required this.serverID, required this.path, final  String? $type}): $type = $type ?? 'lsp.client.diagnostics';
  factory SesoriLspClientDiagnostics.fromJson(Map<String, dynamic> json) => _$SesoriLspClientDiagnosticsFromJson(json);

 final  String? serverID;
 final  String? path;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriLspClientDiagnosticsCopyWith<SesoriLspClientDiagnostics> get copyWith => _$SesoriLspClientDiagnosticsCopyWithImpl<SesoriLspClientDiagnostics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriLspClientDiagnosticsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriLspClientDiagnostics&&(identical(other.serverID, serverID) || other.serverID == serverID)&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverID,path);

@override
String toString() {
  return 'SesoriSseEvent.lspClientDiagnostics(serverID: $serverID, path: $path)';
}


}

/// @nodoc
abstract mixin class $SesoriLspClientDiagnosticsCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriLspClientDiagnosticsCopyWith(SesoriLspClientDiagnostics value, $Res Function(SesoriLspClientDiagnostics) _then) = _$SesoriLspClientDiagnosticsCopyWithImpl;
@useResult
$Res call({
 String? serverID, String? path
});




}
/// @nodoc
class _$SesoriLspClientDiagnosticsCopyWithImpl<$Res>
    implements $SesoriLspClientDiagnosticsCopyWith<$Res> {
  _$SesoriLspClientDiagnosticsCopyWithImpl(this._self, this._then);

  final SesoriLspClientDiagnostics _self;
  final $Res Function(SesoriLspClientDiagnostics) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? serverID = freezed,Object? path = freezed,}) {
  return _then(SesoriLspClientDiagnostics(
serverID: freezed == serverID ? _self.serverID : serverID // ignore: cast_nullable_to_non_nullable
as String?,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriMcpToolsChanged implements SesoriSseEvent {
  const SesoriMcpToolsChanged({final  String? $type}): $type = $type ?? 'mcp.tools.changed';
  factory SesoriMcpToolsChanged.fromJson(Map<String, dynamic> json) => _$SesoriMcpToolsChangedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriMcpToolsChangedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriMcpToolsChanged);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.mcpToolsChanged()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriMcpBrowserOpenFailed implements SesoriSseEvent {
  const SesoriMcpBrowserOpenFailed({final  String? $type}): $type = $type ?? 'mcp.browser.open.failed';
  factory SesoriMcpBrowserOpenFailed.fromJson(Map<String, dynamic> json) => _$SesoriMcpBrowserOpenFailedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriMcpBrowserOpenFailedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriMcpBrowserOpenFailed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.mcpBrowserOpenFailed()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriInstallationUpdated implements SesoriSseEvent {
  const SesoriInstallationUpdated({this.version, final  String? $type}): $type = $type ?? 'installation.updated';
  factory SesoriInstallationUpdated.fromJson(Map<String, dynamic> json) => _$SesoriInstallationUpdatedFromJson(json);

 final  String? version;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriInstallationUpdatedCopyWith<SesoriInstallationUpdated> get copyWith => _$SesoriInstallationUpdatedCopyWithImpl<SesoriInstallationUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriInstallationUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriInstallationUpdated&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version);

@override
String toString() {
  return 'SesoriSseEvent.installationUpdated(version: $version)';
}


}

/// @nodoc
abstract mixin class $SesoriInstallationUpdatedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriInstallationUpdatedCopyWith(SesoriInstallationUpdated value, $Res Function(SesoriInstallationUpdated) _then) = _$SesoriInstallationUpdatedCopyWithImpl;
@useResult
$Res call({
 String? version
});




}
/// @nodoc
class _$SesoriInstallationUpdatedCopyWithImpl<$Res>
    implements $SesoriInstallationUpdatedCopyWith<$Res> {
  _$SesoriInstallationUpdatedCopyWithImpl(this._self, this._then);

  final SesoriInstallationUpdated _self;
  final $Res Function(SesoriInstallationUpdated) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? version = freezed,}) {
  return _then(SesoriInstallationUpdated(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriInstallationUpdateAvailable implements SesoriSseEvent {
  const SesoriInstallationUpdateAvailable({this.version, final  String? $type}): $type = $type ?? 'installation.update-available';
  factory SesoriInstallationUpdateAvailable.fromJson(Map<String, dynamic> json) => _$SesoriInstallationUpdateAvailableFromJson(json);

 final  String? version;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriInstallationUpdateAvailableCopyWith<SesoriInstallationUpdateAvailable> get copyWith => _$SesoriInstallationUpdateAvailableCopyWithImpl<SesoriInstallationUpdateAvailable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriInstallationUpdateAvailableToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriInstallationUpdateAvailable&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version);

@override
String toString() {
  return 'SesoriSseEvent.installationUpdateAvailable(version: $version)';
}


}

/// @nodoc
abstract mixin class $SesoriInstallationUpdateAvailableCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriInstallationUpdateAvailableCopyWith(SesoriInstallationUpdateAvailable value, $Res Function(SesoriInstallationUpdateAvailable) _then) = _$SesoriInstallationUpdateAvailableCopyWithImpl;
@useResult
$Res call({
 String? version
});




}
/// @nodoc
class _$SesoriInstallationUpdateAvailableCopyWithImpl<$Res>
    implements $SesoriInstallationUpdateAvailableCopyWith<$Res> {
  _$SesoriInstallationUpdateAvailableCopyWithImpl(this._self, this._then);

  final SesoriInstallationUpdateAvailable _self;
  final $Res Function(SesoriInstallationUpdateAvailable) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? version = freezed,}) {
  return _then(SesoriInstallationUpdateAvailable(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriWorkspaceReady implements SesoriSseEvent {
  const SesoriWorkspaceReady({this.name, final  String? $type}): $type = $type ?? 'workspace.ready';
  factory SesoriWorkspaceReady.fromJson(Map<String, dynamic> json) => _$SesoriWorkspaceReadyFromJson(json);

 final  String? name;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriWorkspaceReadyCopyWith<SesoriWorkspaceReady> get copyWith => _$SesoriWorkspaceReadyCopyWithImpl<SesoriWorkspaceReady>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriWorkspaceReadyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriWorkspaceReady&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'SesoriSseEvent.workspaceReady(name: $name)';
}


}

/// @nodoc
abstract mixin class $SesoriWorkspaceReadyCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriWorkspaceReadyCopyWith(SesoriWorkspaceReady value, $Res Function(SesoriWorkspaceReady) _then) = _$SesoriWorkspaceReadyCopyWithImpl;
@useResult
$Res call({
 String? name
});




}
/// @nodoc
class _$SesoriWorkspaceReadyCopyWithImpl<$Res>
    implements $SesoriWorkspaceReadyCopyWith<$Res> {
  _$SesoriWorkspaceReadyCopyWithImpl(this._self, this._then);

  final SesoriWorkspaceReady _self;
  final $Res Function(SesoriWorkspaceReady) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = freezed,}) {
  return _then(SesoriWorkspaceReady(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriWorkspaceFailed implements SesoriSseEvent {
  const SesoriWorkspaceFailed({this.message, final  String? $type}): $type = $type ?? 'workspace.failed';
  factory SesoriWorkspaceFailed.fromJson(Map<String, dynamic> json) => _$SesoriWorkspaceFailedFromJson(json);

 final  String? message;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriWorkspaceFailedCopyWith<SesoriWorkspaceFailed> get copyWith => _$SesoriWorkspaceFailedCopyWithImpl<SesoriWorkspaceFailed>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriWorkspaceFailedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriWorkspaceFailed&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'SesoriSseEvent.workspaceFailed(message: $message)';
}


}

/// @nodoc
abstract mixin class $SesoriWorkspaceFailedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriWorkspaceFailedCopyWith(SesoriWorkspaceFailed value, $Res Function(SesoriWorkspaceFailed) _then) = _$SesoriWorkspaceFailedCopyWithImpl;
@useResult
$Res call({
 String? message
});




}
/// @nodoc
class _$SesoriWorkspaceFailedCopyWithImpl<$Res>
    implements $SesoriWorkspaceFailedCopyWith<$Res> {
  _$SesoriWorkspaceFailedCopyWithImpl(this._self, this._then);

  final SesoriWorkspaceFailed _self;
  final $Res Function(SesoriWorkspaceFailed) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = freezed,}) {
  return _then(SesoriWorkspaceFailed(
message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriTuiToastShow implements SesoriSseEvent {
  const SesoriTuiToastShow({required this.title, required this.message, required this.variant, final  String? $type}): $type = $type ?? 'tui.toast.show';
  factory SesoriTuiToastShow.fromJson(Map<String, dynamic> json) => _$SesoriTuiToastShowFromJson(json);

 final  String? title;
 final  String? message;
 final  String? variant;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriTuiToastShowCopyWith<SesoriTuiToastShow> get copyWith => _$SesoriTuiToastShowCopyWithImpl<SesoriTuiToastShow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriTuiToastShowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriTuiToastShow&&(identical(other.title, title) || other.title == title)&&(identical(other.message, message) || other.message == message)&&(identical(other.variant, variant) || other.variant == variant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,message,variant);

@override
String toString() {
  return 'SesoriSseEvent.tuiToastShow(title: $title, message: $message, variant: $variant)';
}


}

/// @nodoc
abstract mixin class $SesoriTuiToastShowCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriTuiToastShowCopyWith(SesoriTuiToastShow value, $Res Function(SesoriTuiToastShow) _then) = _$SesoriTuiToastShowCopyWithImpl;
@useResult
$Res call({
 String? title, String? message, String? variant
});




}
/// @nodoc
class _$SesoriTuiToastShowCopyWithImpl<$Res>
    implements $SesoriTuiToastShowCopyWith<$Res> {
  _$SesoriTuiToastShowCopyWithImpl(this._self, this._then);

  final SesoriTuiToastShow _self;
  final $Res Function(SesoriTuiToastShow) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? title = freezed,Object? message = freezed,Object? variant = freezed,}) {
  return _then(SesoriTuiToastShow(
title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriWorktreeReady implements SesoriSseEvent {
  const SesoriWorktreeReady({final  String? $type}): $type = $type ?? 'worktree.ready';
  factory SesoriWorktreeReady.fromJson(Map<String, dynamic> json) => _$SesoriWorktreeReadyFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriWorktreeReadyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriWorktreeReady);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.worktreeReady()';
}


}




/// @nodoc
@JsonSerializable()

class SesoriWorktreeFailed implements SesoriSseEvent {
  const SesoriWorktreeFailed({final  String? $type}): $type = $type ?? 'worktree.failed';
  factory SesoriWorktreeFailed.fromJson(Map<String, dynamic> json) => _$SesoriWorktreeFailedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SesoriWorktreeFailedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriWorktreeFailed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SesoriSseEvent.worktreeFailed()';
}


}




// dart format on
