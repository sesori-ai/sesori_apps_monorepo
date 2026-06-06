// GENERATED FILE - DO NOT EDIT BY HAND

import 'permission_v2_source.dart';

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
      "save": save,
      "metadata": metadata,
      "source": source?.toJson(),
    };
  }

  final String id;
  final String sessionID;
  final String action;
  final List<String> resources;
  final List<String>? save;
  final Map<String, dynamic>? metadata;
  final PermissionV2Source? source;
}
