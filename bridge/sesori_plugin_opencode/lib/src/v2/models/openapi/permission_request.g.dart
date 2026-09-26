// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'permission_source.g.dart';

@immutable
class PermissionRequest {
  const PermissionRequest({
    required this.id,
    required this.sessionID,
    required this.action,
    required this.resources,
    required this.save,
    required this.metadata,
    required this.source,
    required this.message,
  });

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      action: json["action"] as String,
      resources: (json["resources"] as List<dynamic>).cast<String>(),
      save: (json["save"] as List<dynamic>?)?.cast<String>(),
      metadata: json["metadata"] as Map<String, dynamic>?,
      source: json["source"] == null ? null : PermissionSource.fromJson(json["source"] as Map<String, dynamic>),
      message: json["message"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "action": action,
      "resources": resources,
      "save": ?save,
      "metadata": ?metadata,
      "source": ?source?.toJson(),
      "message": ?message,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PermissionRequest copyWith({
    String? id,
    String? sessionID,
    String? action,
    List<String>? resources,
    List<String>? save,
    Map<String, dynamic>? metadata,
    PermissionSource? source,
    String? message,
  }) {
    return PermissionRequest(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      action: action ?? this.action,
      resources: resources ?? this.resources,
      save: save ?? this.save,
      metadata: metadata ?? this.metadata,
      source: source ?? this.source,
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionRequest &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.action == action &&
          const DeepCollectionEquality().equals(other.resources, resources) &&
          const DeepCollectionEquality().equals(other.save, save) &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.source == source &&
          other.message == message);

  @override
  int get hashCode => Object.hash(id, sessionID, action, const DeepCollectionEquality().hash(resources), const DeepCollectionEquality().hash(save), const DeepCollectionEquality().hash(metadata), source, message);

  final String id;
  final String sessionID;
  final String action;
  final List<String> resources;
  final List<String>? save;
  final Map<String, dynamic>? metadata;
  final PermissionSource? source;
  final String? message;
}
