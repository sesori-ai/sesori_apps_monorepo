// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sesori_sse_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
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
                case 'catalog.import.progress':
          return SesoriCatalogImportProgress.fromJson(
            json
          );
                case 'plugin.management.changed':
          return SesoriPluginManagementChanged.fromJson(
            json
          );
                case 'plugin.install.progress':
          return SesoriPluginInstallProgress.fromJson(
            json
          );
                case 'plugin.authentication.progress':
          return SesoriPluginAuthenticationProgress.fromJson(
            json
          );
                case 'session.options_updated':
          return SesoriSessionOptionsUpdated.fromJson(
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
                case 'session.prompt_defaults_changed':
          return SesoriSessionPromptDefaultsChanged.fromJson(
            json
          );
                case 'session.status':
          return SesoriSessionStatus.fromJson(
            json
          );
                case 'command.executed':
          return SesoriCommandExecuted.fromJson(
            json
          );
                case 'session.queued-prompts':
          return SesoriSessionQueuedPrompts.fromJson(
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
                case 'session.unseen_changed':
          return SesoriSessionUnseenChanged.fromJson(
            json
          );
                case 'file.edited':
          return SesoriFileEdited.fromJson(
            json
          );
                case 'installation.update-available':
          return SesoriInstallationUpdateAvailable.fromJson(
            json
          );
                case 'tui.toast.show':
          return SesoriTuiToastShow.fromJson(
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
  const SesoriServerConnected({ String? $type}): $type = $type ?? 'server.connected';
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
  const SesoriServerHeartbeat({ String? $type}): $type = $type ?? 'server.heartbeat';
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
  const SesoriServerInstanceDisposed({this.directory,  String? $type}): $type = $type ?? 'server.instance.disposed';
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
  const SesoriGlobalDisposed({ String? $type}): $type = $type ?? 'global.disposed';
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

class SesoriCatalogImportProgress implements SesoriSseEvent {
  const SesoriCatalogImportProgress({required this.progress,  String? $type}): $type = $type ?? 'catalog.import.progress';
  factory SesoriCatalogImportProgress.fromJson(Map<String, dynamic> json) => _$SesoriCatalogImportProgressFromJson(json);

 final  CatalogImportProgress progress;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriCatalogImportProgressCopyWith<SesoriCatalogImportProgress> get copyWith => _$SesoriCatalogImportProgressCopyWithImpl<SesoriCatalogImportProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriCatalogImportProgressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriCatalogImportProgress&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,progress);

@override
String toString() {
  return 'SesoriSseEvent.catalogImportProgress(progress: $progress)';
}


}

/// @nodoc
abstract mixin class $SesoriCatalogImportProgressCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriCatalogImportProgressCopyWith(SesoriCatalogImportProgress value, $Res Function(SesoriCatalogImportProgress) _then) = _$SesoriCatalogImportProgressCopyWithImpl;
@useResult
$Res call({
 CatalogImportProgress progress
});




}
/// @nodoc
class _$SesoriCatalogImportProgressCopyWithImpl<$Res>
    implements $SesoriCatalogImportProgressCopyWith<$Res> {
  _$SesoriCatalogImportProgressCopyWithImpl(this._self, this._then);

  final SesoriCatalogImportProgress _self;
  final $Res Function(SesoriCatalogImportProgress) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? progress = null,}) {
  return _then(SesoriCatalogImportProgress(
progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as CatalogImportProgress,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriPluginManagementChanged implements SesoriSseEvent {
  const SesoriPluginManagementChanged({required this.snapshotToken,  String? $type}): $type = $type ?? 'plugin.management.changed';
  factory SesoriPluginManagementChanged.fromJson(Map<String, dynamic> json) => _$SesoriPluginManagementChangedFromJson(json);

 final  String snapshotToken;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriPluginManagementChangedCopyWith<SesoriPluginManagementChanged> get copyWith => _$SesoriPluginManagementChangedCopyWithImpl<SesoriPluginManagementChanged>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriPluginManagementChangedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPluginManagementChanged&&(identical(other.snapshotToken, snapshotToken) || other.snapshotToken == snapshotToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,snapshotToken);

@override
String toString() {
  return 'SesoriSseEvent.pluginManagementChanged(snapshotToken: $snapshotToken)';
}


}

/// @nodoc
abstract mixin class $SesoriPluginManagementChangedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriPluginManagementChangedCopyWith(SesoriPluginManagementChanged value, $Res Function(SesoriPluginManagementChanged) _then) = _$SesoriPluginManagementChangedCopyWithImpl;
@useResult
$Res call({
 String snapshotToken
});




}
/// @nodoc
class _$SesoriPluginManagementChangedCopyWithImpl<$Res>
    implements $SesoriPluginManagementChangedCopyWith<$Res> {
  _$SesoriPluginManagementChangedCopyWithImpl(this._self, this._then);

  final SesoriPluginManagementChanged _self;
  final $Res Function(SesoriPluginManagementChanged) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? snapshotToken = null,}) {
  return _then(SesoriPluginManagementChanged(
snapshotToken: null == snapshotToken ? _self.snapshotToken : snapshotToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriPluginInstallProgress implements SesoriSseEvent {
  const SesoriPluginInstallProgress({required this.pluginId, @JsonKey(unknownEnumValue: PluginInstallPhase.unknown) required this.phase, required this.percent, required this.message,  String? $type}): $type = $type ?? 'plugin.install.progress';
  factory SesoriPluginInstallProgress.fromJson(Map<String, dynamic> json) => _$SesoriPluginInstallProgressFromJson(json);

 final  String pluginId;
@JsonKey(unknownEnumValue: PluginInstallPhase.unknown) final  PluginInstallPhase phase;
 final  int? percent;
 final  String? message;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriPluginInstallProgressCopyWith<SesoriPluginInstallProgress> get copyWith => _$SesoriPluginInstallProgressCopyWithImpl<SesoriPluginInstallProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriPluginInstallProgressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPluginInstallProgress&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.percent, percent) || other.percent == percent)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,phase,percent,message);

@override
String toString() {
  return 'SesoriSseEvent.pluginInstallProgress(pluginId: $pluginId, phase: $phase, percent: $percent, message: $message)';
}


}

/// @nodoc
abstract mixin class $SesoriPluginInstallProgressCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriPluginInstallProgressCopyWith(SesoriPluginInstallProgress value, $Res Function(SesoriPluginInstallProgress) _then) = _$SesoriPluginInstallProgressCopyWithImpl;
@useResult
$Res call({
 String pluginId,@JsonKey(unknownEnumValue: PluginInstallPhase.unknown) PluginInstallPhase phase, int? percent, String? message
});




}
/// @nodoc
class _$SesoriPluginInstallProgressCopyWithImpl<$Res>
    implements $SesoriPluginInstallProgressCopyWith<$Res> {
  _$SesoriPluginInstallProgressCopyWithImpl(this._self, this._then);

  final SesoriPluginInstallProgress _self;
  final $Res Function(SesoriPluginInstallProgress) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? phase = null,Object? percent = freezed,Object? message = freezed,}) {
  return _then(SesoriPluginInstallProgress(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as PluginInstallPhase,percent: freezed == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as int?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriPluginAuthenticationProgress implements SesoriSseEvent {
  const SesoriPluginAuthenticationProgress({required this.pluginId, required this.progress,  String? $type}): $type = $type ?? 'plugin.authentication.progress';
  factory SesoriPluginAuthenticationProgress.fromJson(Map<String, dynamic> json) => _$SesoriPluginAuthenticationProgressFromJson(json);

 final  String pluginId;
 final  PluginAuthenticationProgress progress;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriPluginAuthenticationProgressCopyWith<SesoriPluginAuthenticationProgress> get copyWith => _$SesoriPluginAuthenticationProgressCopyWithImpl<SesoriPluginAuthenticationProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriPluginAuthenticationProgressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPluginAuthenticationProgress&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,progress);

@override
String toString() {
  return 'SesoriSseEvent.pluginAuthenticationProgress(pluginId: $pluginId, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $SesoriPluginAuthenticationProgressCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriPluginAuthenticationProgressCopyWith(SesoriPluginAuthenticationProgress value, $Res Function(SesoriPluginAuthenticationProgress) _then) = _$SesoriPluginAuthenticationProgressCopyWithImpl;
@useResult
$Res call({
 String pluginId, PluginAuthenticationProgress progress
});




}
/// @nodoc
class _$SesoriPluginAuthenticationProgressCopyWithImpl<$Res>
    implements $SesoriPluginAuthenticationProgressCopyWith<$Res> {
  _$SesoriPluginAuthenticationProgressCopyWithImpl(this._self, this._then);

  final SesoriPluginAuthenticationProgress _self;
  final $Res Function(SesoriPluginAuthenticationProgress) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? progress = null,}) {
  return _then(SesoriPluginAuthenticationProgress(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as PluginAuthenticationProgress,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriSessionOptionsUpdated implements SesoriSseEvent {
  const SesoriSessionOptionsUpdated({required this.pluginId, required this.projectId,  String? $type}): $type = $type ?? 'session.options_updated';
  factory SesoriSessionOptionsUpdated.fromJson(Map<String, dynamic> json) => _$SesoriSessionOptionsUpdatedFromJson(json);

 final  String pluginId;
 final  String? projectId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionOptionsUpdatedCopyWith<SesoriSessionOptionsUpdated> get copyWith => _$SesoriSessionOptionsUpdatedCopyWithImpl<SesoriSessionOptionsUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionOptionsUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionOptionsUpdated&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.projectId, projectId) || other.projectId == projectId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,projectId);

@override
String toString() {
  return 'SesoriSseEvent.sessionOptionsUpdated(pluginId: $pluginId, projectId: $projectId)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionOptionsUpdatedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionOptionsUpdatedCopyWith(SesoriSessionOptionsUpdated value, $Res Function(SesoriSessionOptionsUpdated) _then) = _$SesoriSessionOptionsUpdatedCopyWithImpl;
@useResult
$Res call({
 String pluginId, String? projectId
});




}
/// @nodoc
class _$SesoriSessionOptionsUpdatedCopyWithImpl<$Res>
    implements $SesoriSessionOptionsUpdatedCopyWith<$Res> {
  _$SesoriSessionOptionsUpdatedCopyWithImpl(this._self, this._then);

  final SesoriSessionOptionsUpdated _self;
  final $Res Function(SesoriSessionOptionsUpdated) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? projectId = freezed,}) {
  return _then(SesoriSessionOptionsUpdated(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,projectId: freezed == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriSessionCreated implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionCreated({required this.info,  String? $type}): $type = $type ?? 'session.created';
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
  const SesoriSessionUpdated({required this.info,  String? $type}): $type = $type ?? 'session.updated';
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
  const SesoriSessionDeleted({required this.info,  String? $type}): $type = $type ?? 'session.deleted';
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
  const SesoriSessionDiff({required this.sessionID,  String? $type}): $type = $type ?? 'session.diff';
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
  const SesoriSessionError({required this.sessionID,  String? $type}): $type = $type ?? 'session.error';
  factory SesoriSessionError.fromJson(Map<String, dynamic> json) => _$SesoriSessionErrorFromJson(json);

 final  String? sessionID;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionError&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID);

@override
String toString() {
  return 'SesoriSseEvent.sessionError(sessionID: $sessionID)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionErrorCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionErrorCopyWith(SesoriSessionError value, $Res Function(SesoriSessionError) _then) = _$SesoriSessionErrorCopyWithImpl;
@useResult
$Res call({
 String? sessionID
});




}
/// @nodoc
class _$SesoriSessionErrorCopyWithImpl<$Res>
    implements $SesoriSessionErrorCopyWith<$Res> {
  _$SesoriSessionErrorCopyWithImpl(this._self, this._then);

  final SesoriSessionError _self;
  final $Res Function(SesoriSessionError) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = freezed,}) {
  return _then(SesoriSessionError(
sessionID: freezed == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriSessionCompacted implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionCompacted({required this.sessionID,  String? $type}): $type = $type ?? 'session.compacted';
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

class SesoriSessionPromptDefaultsChanged implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionPromptDefaultsChanged({required this.sessionID, required this.promptDefaults,  String? $type}): $type = $type ?? 'session.prompt_defaults_changed';
  factory SesoriSessionPromptDefaultsChanged.fromJson(Map<String, dynamic> json) => _$SesoriSessionPromptDefaultsChangedFromJson(json);

 final  String sessionID;
 final  SessionPromptDefaults promptDefaults;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionPromptDefaultsChangedCopyWith<SesoriSessionPromptDefaultsChanged> get copyWith => _$SesoriSessionPromptDefaultsChangedCopyWithImpl<SesoriSessionPromptDefaultsChanged>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionPromptDefaultsChangedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionPromptDefaultsChanged&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.promptDefaults, promptDefaults) || other.promptDefaults == promptDefaults));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,promptDefaults);

@override
String toString() {
  return 'SesoriSseEvent.sessionPromptDefaultsChanged(sessionID: $sessionID, promptDefaults: $promptDefaults)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionPromptDefaultsChangedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionPromptDefaultsChangedCopyWith(SesoriSessionPromptDefaultsChanged value, $Res Function(SesoriSessionPromptDefaultsChanged) _then) = _$SesoriSessionPromptDefaultsChangedCopyWithImpl;
@useResult
$Res call({
 String sessionID, SessionPromptDefaults promptDefaults
});


$SessionPromptDefaultsCopyWith<$Res> get promptDefaults;

}
/// @nodoc
class _$SesoriSessionPromptDefaultsChangedCopyWithImpl<$Res>
    implements $SesoriSessionPromptDefaultsChangedCopyWith<$Res> {
  _$SesoriSessionPromptDefaultsChangedCopyWithImpl(this._self, this._then);

  final SesoriSessionPromptDefaultsChanged _self;
  final $Res Function(SesoriSessionPromptDefaultsChanged) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? promptDefaults = null,}) {
  return _then(SesoriSessionPromptDefaultsChanged(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,promptDefaults: null == promptDefaults ? _self.promptDefaults : promptDefaults // ignore: cast_nullable_to_non_nullable
as SessionPromptDefaults,
  ));
}

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionPromptDefaultsCopyWith<$Res> get promptDefaults {
  
  return $SessionPromptDefaultsCopyWith<$Res>(_self.promptDefaults, (value) {
    return _then(_self.copyWith(promptDefaults: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SesoriSessionStatus implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionStatus({required this.sessionID, required this.status,  String? $type}): $type = $type ?? 'session.status';
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

class SesoriCommandExecuted implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriCommandExecuted({required this.name, required this.sessionID, required this.arguments, required this.messageID,  String? $type}): $type = $type ?? 'command.executed';
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

class SesoriSessionQueuedPrompts implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriSessionQueuedPrompts({required this.sessionID, required  List<QueuedSessionPrompt> prompts,  String? $type}): _prompts = prompts,$type = $type ?? 'session.queued-prompts';
  factory SesoriSessionQueuedPrompts.fromJson(Map<String, dynamic> json) => _$SesoriSessionQueuedPromptsFromJson(json);

 final  String sessionID;
 final  List<QueuedSessionPrompt> _prompts;
 List<QueuedSessionPrompt> get prompts {
  if (_prompts is EqualUnmodifiableListView) return _prompts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_prompts);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionQueuedPromptsCopyWith<SesoriSessionQueuedPrompts> get copyWith => _$SesoriSessionQueuedPromptsCopyWithImpl<SesoriSessionQueuedPrompts>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionQueuedPromptsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionQueuedPrompts&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&const DeepCollectionEquality().equals(other._prompts, _prompts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,const DeepCollectionEquality().hash(_prompts));

@override
String toString() {
  return 'SesoriSseEvent.sessionQueuedPrompts(sessionID: $sessionID, prompts: $prompts)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionQueuedPromptsCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionQueuedPromptsCopyWith(SesoriSessionQueuedPrompts value, $Res Function(SesoriSessionQueuedPrompts) _then) = _$SesoriSessionQueuedPromptsCopyWithImpl;
@useResult
$Res call({
 String sessionID, List<QueuedSessionPrompt> prompts
});




}
/// @nodoc
class _$SesoriSessionQueuedPromptsCopyWithImpl<$Res>
    implements $SesoriSessionQueuedPromptsCopyWith<$Res> {
  _$SesoriSessionQueuedPromptsCopyWithImpl(this._self, this._then);

  final SesoriSessionQueuedPrompts _self;
  final $Res Function(SesoriSessionQueuedPrompts) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionID = null,Object? prompts = null,}) {
  return _then(SesoriSessionQueuedPrompts(
sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,prompts: null == prompts ? _self._prompts : prompts // ignore: cast_nullable_to_non_nullable
as List<QueuedSessionPrompt>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriMessageUpdated implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriMessageUpdated({required this.info,  String? $type}): $type = $type ?? 'message.updated';
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
  const SesoriMessageRemoved({required this.sessionID, required this.messageID,  String? $type}): $type = $type ?? 'message.removed';
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
  const SesoriMessagePartUpdated({required this.part,  String? $type}): $type = $type ?? 'message.part.updated';
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
  const SesoriMessagePartDelta({required this.sessionID, required this.messageID, required this.partID, required this.field, required this.delta,  String? $type}): $type = $type ?? 'message.part.delta';
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
  const SesoriMessagePartRemoved({required this.sessionID, required this.messageID, required this.partID,  String? $type}): $type = $type ?? 'message.part.removed';
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

class SesoriPermissionAsked implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriPermissionAsked({required this.requestID, required this.sessionID, required this.displaySessionId, required this.tool, required this.description, this.allowAlways = true,  String? $type}): $type = $type ?? 'permission.asked';
  factory SesoriPermissionAsked.fromJson(Map<String, dynamic> json) => _$SesoriPermissionAskedFromJson(json);

 final  String requestID;
 final  String sessionID;
/// Top-most root session this request should be surfaced under (for a
/// child/sub-agent session's request). Null when unknown; consumers fall
/// back to [sessionID].
 final  String? displaySessionId;
 final  String tool;
 final  String description;
@JsonKey() final  bool allowAlways;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPermissionAsked&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.displaySessionId, displaySessionId) || other.displaySessionId == displaySessionId)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.description, description) || other.description == description)&&(identical(other.allowAlways, allowAlways) || other.allowAlways == allowAlways));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID,displaySessionId,tool,description,allowAlways);

@override
String toString() {
  return 'SesoriSseEvent.permissionAsked(requestID: $requestID, sessionID: $sessionID, displaySessionId: $displaySessionId, tool: $tool, description: $description, allowAlways: $allowAlways)';
}


}

/// @nodoc
abstract mixin class $SesoriPermissionAskedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriPermissionAskedCopyWith(SesoriPermissionAsked value, $Res Function(SesoriPermissionAsked) _then) = _$SesoriPermissionAskedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID, String? displaySessionId, String tool, String description, bool allowAlways
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
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,Object? displaySessionId = freezed,Object? tool = null,Object? description = null,Object? allowAlways = null,}) {
  return _then(SesoriPermissionAsked(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,displaySessionId: freezed == displaySessionId ? _self.displaySessionId : displaySessionId // ignore: cast_nullable_to_non_nullable
as String?,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,allowAlways: null == allowAlways ? _self.allowAlways : allowAlways // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriPermissionReplied implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriPermissionReplied({required this.requestID, required this.sessionID, required this.displaySessionId, required this.reply,  String? $type}): $type = $type ?? 'permission.replied';
  factory SesoriPermissionReplied.fromJson(Map<String, dynamic> json) => _$SesoriPermissionRepliedFromJson(json);

 final  String requestID;
 final  String sessionID;
/// Root session this request is surfaced under; null ⇒ fall back to
/// [sessionID].
 final  String? displaySessionId;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriPermissionReplied&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.displaySessionId, displaySessionId) || other.displaySessionId == displaySessionId)&&(identical(other.reply, reply) || other.reply == reply));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID,displaySessionId,reply);

@override
String toString() {
  return 'SesoriSseEvent.permissionReplied(requestID: $requestID, sessionID: $sessionID, displaySessionId: $displaySessionId, reply: $reply)';
}


}

/// @nodoc
abstract mixin class $SesoriPermissionRepliedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriPermissionRepliedCopyWith(SesoriPermissionReplied value, $Res Function(SesoriPermissionReplied) _then) = _$SesoriPermissionRepliedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID, String? displaySessionId, String reply
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
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,Object? displaySessionId = freezed,Object? reply = null,}) {
  return _then(SesoriPermissionReplied(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,displaySessionId: freezed == displaySessionId ? _self.displaySessionId : displaySessionId // ignore: cast_nullable_to_non_nullable
as String?,reply: null == reply ? _self.reply : reply // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriPermissionUpdated implements SesoriSseEvent {
  const SesoriPermissionUpdated({ String? $type}): $type = $type ?? 'permission.updated';
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
  const SesoriQuestionAsked({required this.id, required this.sessionID, required this.displaySessionId, required  List<QuestionInfo> questions,  String? $type}): _questions = questions,$type = $type ?? 'question.asked';
  factory SesoriQuestionAsked.fromJson(Map<String, dynamic> json) => _$SesoriQuestionAskedFromJson(json);

 final  String id;
 final  String sessionID;
/// Top-most root session this request should be surfaced under (for a
/// child/sub-agent session's request). Null when unknown; consumers fall
/// back to [sessionID].
 final  String? displaySessionId;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriQuestionAsked&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.displaySessionId, displaySessionId) || other.displaySessionId == displaySessionId)&&const DeepCollectionEquality().equals(other._questions, _questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionID,displaySessionId,const DeepCollectionEquality().hash(_questions));

@override
String toString() {
  return 'SesoriSseEvent.questionAsked(id: $id, sessionID: $sessionID, displaySessionId: $displaySessionId, questions: $questions)';
}


}

/// @nodoc
abstract mixin class $SesoriQuestionAskedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriQuestionAskedCopyWith(SesoriQuestionAsked value, $Res Function(SesoriQuestionAsked) _then) = _$SesoriQuestionAskedCopyWithImpl;
@useResult
$Res call({
 String id, String sessionID, String? displaySessionId, List<QuestionInfo> questions
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
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionID = null,Object? displaySessionId = freezed,Object? questions = null,}) {
  return _then(SesoriQuestionAsked(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,displaySessionId: freezed == displaySessionId ? _self.displaySessionId : displaySessionId // ignore: cast_nullable_to_non_nullable
as String?,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<QuestionInfo>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriQuestionReplied implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriQuestionReplied({required this.requestID, required this.sessionID, required this.displaySessionId,  String? $type}): $type = $type ?? 'question.replied';
  factory SesoriQuestionReplied.fromJson(Map<String, dynamic> json) => _$SesoriQuestionRepliedFromJson(json);

 final  String requestID;
 final  String sessionID;
/// Root session this request is surfaced under; null ⇒ fall back to
/// [sessionID].
 final  String? displaySessionId;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriQuestionReplied&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.displaySessionId, displaySessionId) || other.displaySessionId == displaySessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID,displaySessionId);

@override
String toString() {
  return 'SesoriSseEvent.questionReplied(requestID: $requestID, sessionID: $sessionID, displaySessionId: $displaySessionId)';
}


}

/// @nodoc
abstract mixin class $SesoriQuestionRepliedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriQuestionRepliedCopyWith(SesoriQuestionReplied value, $Res Function(SesoriQuestionReplied) _then) = _$SesoriQuestionRepliedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID, String? displaySessionId
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
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,Object? displaySessionId = freezed,}) {
  return _then(SesoriQuestionReplied(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,displaySessionId: freezed == displaySessionId ? _self.displaySessionId : displaySessionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriQuestionRejected implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriQuestionRejected({required this.requestID, required this.sessionID, required this.displaySessionId,  String? $type}): $type = $type ?? 'question.rejected';
  factory SesoriQuestionRejected.fromJson(Map<String, dynamic> json) => _$SesoriQuestionRejectedFromJson(json);

 final  String requestID;
 final  String sessionID;
/// Root session this request is surfaced under; null ⇒ fall back to
/// [sessionID].
 final  String? displaySessionId;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriQuestionRejected&&(identical(other.requestID, requestID) || other.requestID == requestID)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.displaySessionId, displaySessionId) || other.displaySessionId == displaySessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestID,sessionID,displaySessionId);

@override
String toString() {
  return 'SesoriSseEvent.questionRejected(requestID: $requestID, sessionID: $sessionID, displaySessionId: $displaySessionId)';
}


}

/// @nodoc
abstract mixin class $SesoriQuestionRejectedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriQuestionRejectedCopyWith(SesoriQuestionRejected value, $Res Function(SesoriQuestionRejected) _then) = _$SesoriQuestionRejectedCopyWithImpl;
@useResult
$Res call({
 String requestID, String sessionID, String? displaySessionId
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
@pragma('vm:prefer-inline') $Res call({Object? requestID = null,Object? sessionID = null,Object? displaySessionId = freezed,}) {
  return _then(SesoriQuestionRejected(
requestID: null == requestID ? _self.requestID : requestID // ignore: cast_nullable_to_non_nullable
as String,sessionID: null == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String,displaySessionId: freezed == displaySessionId ? _self.displaySessionId : displaySessionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriTodoUpdated implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriTodoUpdated({required this.sessionID,  String? $type}): $type = $type ?? 'todo.updated';
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
  const SesoriProjectsSummary({required  List<ProjectActivitySummary> projects,  String? $type}): _projects = projects,$type = $type ?? 'projects.summary';
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
  const SesoriProjectUpdated({required this.projectID, required this.updatedAt,  String? $type}): $type = $type ?? 'project.updated';
  factory SesoriProjectUpdated.fromJson(Map<String, dynamic> json) => _$SesoriProjectUpdatedFromJson(json);

 final  String? projectID;
 final  int? updatedAt;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriProjectUpdatedCopyWith<SesoriProjectUpdated> get copyWith => _$SesoriProjectUpdatedCopyWithImpl<SesoriProjectUpdated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriProjectUpdatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriProjectUpdated&&(identical(other.projectID, projectID) || other.projectID == projectID)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectID,updatedAt);

@override
String toString() {
  return 'SesoriSseEvent.projectUpdated(projectID: $projectID, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SesoriProjectUpdatedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriProjectUpdatedCopyWith(SesoriProjectUpdated value, $Res Function(SesoriProjectUpdated) _then) = _$SesoriProjectUpdatedCopyWithImpl;
@useResult
$Res call({
 String? projectID, int? updatedAt
});




}
/// @nodoc
class _$SesoriProjectUpdatedCopyWithImpl<$Res>
    implements $SesoriProjectUpdatedCopyWith<$Res> {
  _$SesoriProjectUpdatedCopyWithImpl(this._self, this._then);

  final SesoriProjectUpdated _self;
  final $Res Function(SesoriProjectUpdated) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projectID = freezed,Object? updatedAt = freezed,}) {
  return _then(SesoriProjectUpdated(
projectID: freezed == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriVcsBranchUpdated implements SesoriSseEvent {
  const SesoriVcsBranchUpdated({ String? $type}): $type = $type ?? 'vcs.branch.updated';
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
  const SesoriSessionsUpdated({required this.projectID,  String? $type}): $type = $type ?? 'sessions.updated';
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

class SesoriSessionUnseenChanged implements SesoriSseEvent {
  const SesoriSessionUnseenChanged({required this.projectID, required this.sessionId, required this.unseen, required this.projectHasUnseenChanges, required this.lastUserActivityAt,  String? $type}): $type = $type ?? 'session.unseen_changed';
  factory SesoriSessionUnseenChanged.fromJson(Map<String, dynamic> json) => _$SesoriSessionUnseenChangedFromJson(json);

 final  String projectID;
 final  String sessionId;
 final  bool unseen;
 final  bool projectHasUnseenChanges;
 final  int? lastUserActivityAt;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesoriSessionUnseenChangedCopyWith<SesoriSessionUnseenChanged> get copyWith => _$SesoriSessionUnseenChangedCopyWithImpl<SesoriSessionUnseenChanged>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesoriSessionUnseenChangedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriSessionUnseenChanged&&(identical(other.projectID, projectID) || other.projectID == projectID)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.unseen, unseen) || other.unseen == unseen)&&(identical(other.projectHasUnseenChanges, projectHasUnseenChanges) || other.projectHasUnseenChanges == projectHasUnseenChanges)&&(identical(other.lastUserActivityAt, lastUserActivityAt) || other.lastUserActivityAt == lastUserActivityAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectID,sessionId,unseen,projectHasUnseenChanges,lastUserActivityAt);

@override
String toString() {
  return 'SesoriSseEvent.sessionUnseenChanged(projectID: $projectID, sessionId: $sessionId, unseen: $unseen, projectHasUnseenChanges: $projectHasUnseenChanges, lastUserActivityAt: $lastUserActivityAt)';
}


}

/// @nodoc
abstract mixin class $SesoriSessionUnseenChangedCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriSessionUnseenChangedCopyWith(SesoriSessionUnseenChanged value, $Res Function(SesoriSessionUnseenChanged) _then) = _$SesoriSessionUnseenChangedCopyWithImpl;
@useResult
$Res call({
 String projectID, String sessionId, bool unseen, bool projectHasUnseenChanges, int? lastUserActivityAt
});




}
/// @nodoc
class _$SesoriSessionUnseenChangedCopyWithImpl<$Res>
    implements $SesoriSessionUnseenChangedCopyWith<$Res> {
  _$SesoriSessionUnseenChangedCopyWithImpl(this._self, this._then);

  final SesoriSessionUnseenChanged _self;
  final $Res Function(SesoriSessionUnseenChanged) _then;

/// Create a copy of SesoriSseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projectID = null,Object? sessionId = null,Object? unseen = null,Object? projectHasUnseenChanges = null,Object? lastUserActivityAt = freezed,}) {
  return _then(SesoriSessionUnseenChanged(
projectID: null == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,unseen: null == unseen ? _self.unseen : unseen // ignore: cast_nullable_to_non_nullable
as bool,projectHasUnseenChanges: null == projectHasUnseenChanges ? _self.projectHasUnseenChanges : projectHasUnseenChanges // ignore: cast_nullable_to_non_nullable
as bool,lastUserActivityAt: freezed == lastUserActivityAt ? _self.lastUserActivityAt : lastUserActivityAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SesoriFileEdited implements SesoriSseEvent {
  const SesoriFileEdited({this.file,  String? $type}): $type = $type ?? 'file.edited';
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

class SesoriInstallationUpdateAvailable implements SesoriSseEvent {
  const SesoriInstallationUpdateAvailable({this.version,  String? $type}): $type = $type ?? 'installation.update-available';
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

class SesoriTuiToastShow implements SesoriSseEvent, SesoriSessionEvent {
  const SesoriTuiToastShow({required this.sessionID, required this.title, required this.message, required this.variant,  String? $type}): $type = $type ?? 'tui.toast.show';
  factory SesoriTuiToastShow.fromJson(Map<String, dynamic> json) => _$SesoriTuiToastShowFromJson(json);

 final  String? sessionID;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesoriTuiToastShow&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.title, title) || other.title == title)&&(identical(other.message, message) || other.message == message)&&(identical(other.variant, variant) || other.variant == variant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionID,title,message,variant);

@override
String toString() {
  return 'SesoriSseEvent.tuiToastShow(sessionID: $sessionID, title: $title, message: $message, variant: $variant)';
}


}

/// @nodoc
abstract mixin class $SesoriTuiToastShowCopyWith<$Res> implements $SesoriSseEventCopyWith<$Res> {
  factory $SesoriTuiToastShowCopyWith(SesoriTuiToastShow value, $Res Function(SesoriTuiToastShow) _then) = _$SesoriTuiToastShowCopyWithImpl;
@useResult
$Res call({
 String? sessionID, String? title, String? message, String? variant
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
@pragma('vm:prefer-inline') $Res call({Object? sessionID = freezed,Object? title = freezed,Object? message = freezed,Object? variant = freezed,}) {
  return _then(SesoriTuiToastShow(
sessionID: freezed == sessionID ? _self.sessionID : sessionID // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
