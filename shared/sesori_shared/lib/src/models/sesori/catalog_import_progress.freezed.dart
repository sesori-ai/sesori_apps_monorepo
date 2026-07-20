// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'catalog_import_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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
  const CatalogImportEnumerating({required this.pluginId, required this.projectsSeen, required this.sessionsSeen, final  String? $type}): $type = $type ?? 'enumerating';
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
  const CatalogImportCommitting({required this.pluginId, required this.projectsSeen, required this.sessionsSeen, final  String? $type}): $type = $type ?? 'committing';
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
  const CatalogImportCompleted({required this.pluginId, required this.projectsImported, required this.sessionsImported, required this.completedAt, final  String? $type}): $type = $type ?? 'completed';
  factory CatalogImportCompleted.fromJson(Map<String, dynamic> json) => _$CatalogImportCompletedFromJson(json);

@override final  String pluginId;
 final  int projectsImported;
 final  int sessionsImported;
 final  int completedAt;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$CatalogImportCompletedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogImportCompleted&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.projectsImported, projectsImported) || other.projectsImported == projectsImported)&&(identical(other.sessionsImported, sessionsImported) || other.sessionsImported == sessionsImported)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,projectsImported,sessionsImported,completedAt);

@override
String toString() {
  return 'CatalogImportProgress.completed(pluginId: $pluginId, projectsImported: $projectsImported, sessionsImported: $sessionsImported, completedAt: $completedAt)';
}


}




/// @nodoc
@JsonSerializable()

class CatalogImportCancelled implements CatalogImportProgress {
  const CatalogImportCancelled({required this.pluginId, final  String? $type}): $type = $type ?? 'cancelled';
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
  const CatalogImportFailed({required this.pluginId, required this.message, final  String? $type}): $type = $type ?? 'failed';
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
