// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'catalog_import_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CatalogImportNewItems {

 int get projects; int get sessions;
/// Create a copy of CatalogImportNewItems
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CatalogImportNewItemsCopyWith<CatalogImportNewItems> get copyWith => _$CatalogImportNewItemsCopyWithImpl<CatalogImportNewItems>(this as CatalogImportNewItems, _$identity);

  /// Serializes this CatalogImportNewItems to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogImportNewItems&&(identical(other.projects, projects) || other.projects == projects)&&(identical(other.sessions, sessions) || other.sessions == sessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projects,sessions);

@override
String toString() {
  return 'CatalogImportNewItems(projects: $projects, sessions: $sessions)';
}


}

/// @nodoc
abstract mixin class $CatalogImportNewItemsCopyWith<$Res>  {
  factory $CatalogImportNewItemsCopyWith(CatalogImportNewItems value, $Res Function(CatalogImportNewItems) _then) = _$CatalogImportNewItemsCopyWithImpl;
@useResult
$Res call({
 int projects, int sessions
});




}
/// @nodoc
class _$CatalogImportNewItemsCopyWithImpl<$Res>
    implements $CatalogImportNewItemsCopyWith<$Res> {
  _$CatalogImportNewItemsCopyWithImpl(this._self, this._then);

  final CatalogImportNewItems _self;
  final $Res Function(CatalogImportNewItems) _then;

/// Create a copy of CatalogImportNewItems
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projects = null,Object? sessions = null,}) {
  return _then(CatalogImportNewItems(
projects: null == projects ? _self.projects : projects // ignore: cast_nullable_to_non_nullable
as int,sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CatalogImportNewItems implements CatalogImportNewItems {
  const _CatalogImportNewItems({required this.projects, required this.sessions});
  factory _CatalogImportNewItems.fromJson(Map<String, dynamic> json) => _$CatalogImportNewItemsFromJson(json);

@override final  int projects;
@override final  int sessions;

/// Create a copy of CatalogImportNewItems
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CatalogImportNewItemsCopyWith<_CatalogImportNewItems> get copyWith => __$CatalogImportNewItemsCopyWithImpl<_CatalogImportNewItems>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CatalogImportNewItemsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CatalogImportNewItems&&(identical(other.projects, projects) || other.projects == projects)&&(identical(other.sessions, sessions) || other.sessions == sessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projects,sessions);

@override
String toString() {
  return 'CatalogImportNewItems(projects: $projects, sessions: $sessions)';
}


}

/// @nodoc
abstract mixin class _$CatalogImportNewItemsCopyWith<$Res> implements $CatalogImportNewItemsCopyWith<$Res> {
  factory _$CatalogImportNewItemsCopyWith(_CatalogImportNewItems value, $Res Function(_CatalogImportNewItems) _then) = __$CatalogImportNewItemsCopyWithImpl;
@override @useResult
$Res call({
 int projects, int sessions
});




}
/// @nodoc
class __$CatalogImportNewItemsCopyWithImpl<$Res>
    implements _$CatalogImportNewItemsCopyWith<$Res> {
  __$CatalogImportNewItemsCopyWithImpl(this._self, this._then);

  final _CatalogImportNewItems _self;
  final $Res Function(_CatalogImportNewItems) _then;

/// Create a copy of CatalogImportNewItems
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projects = null,Object? sessions = null,}) {
  return _then(_CatalogImportNewItems(
projects: null == projects ? _self.projects : projects // ignore: cast_nullable_to_non_nullable
as int,sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

CatalogImportProgress _$CatalogImportProgressFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'enumerating':
          return CatalogImportEnumerating.fromJson(
            json
          );
                case 'committing':
          return CatalogImportCommitting.fromJson(
            json
          );
                case 'completed':
          return CatalogImportCompleted.fromJson(
            json
          );
                case 'cancelled':
          return CatalogImportCancelled.fromJson(
            json
          );
                case 'failed':
          return CatalogImportFailed.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'CatalogImportProgress',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$CatalogImportProgress {

 String get pluginId;

  /// Serializes this CatalogImportProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogImportProgress&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId);

@override
String toString() {
  return 'CatalogImportProgress(pluginId: $pluginId)';
}


}





/// @nodoc
@JsonSerializable()

class CatalogImportEnumerating implements CatalogImportProgress {
  const CatalogImportEnumerating({required this.pluginId, required this.projectsSeen, required this.sessionsSeen,  String? $type}): $type = $type ?? 'enumerating';
  factory CatalogImportEnumerating.fromJson(Map<String, dynamic> json) => _$CatalogImportEnumeratingFromJson(json);

@override final  String pluginId;
 final  int projectsSeen;
 final  int sessionsSeen;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$CatalogImportEnumeratingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogImportEnumerating&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.projectsSeen, projectsSeen) || other.projectsSeen == projectsSeen)&&(identical(other.sessionsSeen, sessionsSeen) || other.sessionsSeen == sessionsSeen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,projectsSeen,sessionsSeen);

@override
String toString() {
  return 'CatalogImportProgress.enumerating(pluginId: $pluginId, projectsSeen: $projectsSeen, sessionsSeen: $sessionsSeen)';
}


}




/// @nodoc
@JsonSerializable()

class CatalogImportCommitting implements CatalogImportProgress {
  const CatalogImportCommitting({required this.pluginId, required this.projectsSeen, required this.sessionsSeen,  String? $type}): $type = $type ?? 'committing';
  factory CatalogImportCommitting.fromJson(Map<String, dynamic> json) => _$CatalogImportCommittingFromJson(json);

@override final  String pluginId;
 final  int projectsSeen;
 final  int sessionsSeen;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$CatalogImportCommittingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogImportCommitting&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.projectsSeen, projectsSeen) || other.projectsSeen == projectsSeen)&&(identical(other.sessionsSeen, sessionsSeen) || other.sessionsSeen == sessionsSeen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,projectsSeen,sessionsSeen);

@override
String toString() {
  return 'CatalogImportProgress.committing(pluginId: $pluginId, projectsSeen: $projectsSeen, sessionsSeen: $sessionsSeen)';
}


}




/// @nodoc
@JsonSerializable()

class CatalogImportCompleted implements CatalogImportProgress {
  const CatalogImportCompleted({required this.pluginId, required this.projectsImported, required this.sessionsImported, required this.completedAt, required this.newItems,  String? $type}): $type = $type ?? 'completed';
  factory CatalogImportCompleted.fromJson(Map<String, dynamic> json) => _$CatalogImportCompletedFromJson(json);

@override final  String pluginId;
 final  int projectsImported;
 final  int sessionsImported;
 final  int completedAt;
 final  CatalogImportNewItems? newItems;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$CatalogImportCompletedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogImportCompleted&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.projectsImported, projectsImported) || other.projectsImported == projectsImported)&&(identical(other.sessionsImported, sessionsImported) || other.sessionsImported == sessionsImported)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.newItems, newItems) || other.newItems == newItems));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,projectsImported,sessionsImported,completedAt,newItems);

@override
String toString() {
  return 'CatalogImportProgress.completed(pluginId: $pluginId, projectsImported: $projectsImported, sessionsImported: $sessionsImported, completedAt: $completedAt, newItems: $newItems)';
}


}




/// @nodoc
@JsonSerializable()

class CatalogImportCancelled implements CatalogImportProgress {
  const CatalogImportCancelled({required this.pluginId,  String? $type}): $type = $type ?? 'cancelled';
  factory CatalogImportCancelled.fromJson(Map<String, dynamic> json) => _$CatalogImportCancelledFromJson(json);

@override final  String pluginId;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$CatalogImportCancelledToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogImportCancelled&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId);

@override
String toString() {
  return 'CatalogImportProgress.cancelled(pluginId: $pluginId)';
}


}




/// @nodoc
@JsonSerializable()

class CatalogImportFailed implements CatalogImportProgress {
  const CatalogImportFailed({required this.pluginId, required this.message,  String? $type}): $type = $type ?? 'failed';
  factory CatalogImportFailed.fromJson(Map<String, dynamic> json) => _$CatalogImportFailedFromJson(json);

@override final  String pluginId;
 final  String message;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$CatalogImportFailedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogImportFailed&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,message);

@override
String toString() {
  return 'CatalogImportProgress.failed(pluginId: $pluginId, message: $message)';
}


}




// dart format on
