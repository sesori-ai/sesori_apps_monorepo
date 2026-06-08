// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.981275Z

import 'package:meta/meta.dart';
import 'permission_v2_source.dart';

@immutable
class PermissionV2Request {
  const PermissionV2Request({
    required this.id,
    required this.sessionID,
    required this.action,
    required this.resources,
    this.save,
    this.metadata,
    this.source,
  });

  factory PermissionV2Request.fromJson(Map<String, dynamic> json) {
    return PermissionV2Request(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      action: json["action"] as String,
      resources: (json["resources"] as List<dynamic>).cast<String>(),
      save: (json["save"] as List<dynamic>?)?.cast<String>(),
      metadata: json["metadata"] as Map<String, dynamic>?,
      source: json["source"] == null ? null : PermissionV2Source.fromJson(json["source"] as Map<String, dynamic>),
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
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionV2Request &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.action == action &&
          other.resources == resources &&
          other.save == save &&
          other.metadata == metadata &&
          other.source == source);

  @override
  int get hashCode => Object.hash(id, sessionID, action, resources, save, metadata, source);

  final String id;
  final String sessionID;
  final String action;
  final List<String> resources;
  final List<String>? save;
  final Map<String, dynamic>? metadata;
  final PermissionV2Source? source;
}
