// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';
import 'permission_v2_source.dart';

@immutable
class EventPermissionV2Asked implements Event {
  const EventPermissionV2Asked({
    required this.id,
    required this.properties,
  });

  factory EventPermissionV2Asked.fromJson(Map<String, dynamic> json) {
    return EventPermissionV2Asked(
      id: json["id"] as String,
      properties: EventPermissionV2AskedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "permission.v2.asked",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPermissionV2Asked &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventPermissionV2AskedProperties properties;
}

@immutable
class EventPermissionV2AskedProperties {
  const EventPermissionV2AskedProperties({
    required this.id,
    required this.sessionID,
    required this.action,
    required this.resources,
    this.save,
    this.metadata,
    this.source,
  });

  factory EventPermissionV2AskedProperties.fromJson(Map<String, dynamic> json) {
    return EventPermissionV2AskedProperties(
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
      (other is EventPermissionV2AskedProperties &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.action == action &&
          const DeepCollectionEquality().equals(other.resources, resources) &&
          const DeepCollectionEquality().equals(other.save, save) &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.source == source);

  @override
  int get hashCode => Object.hash(id, sessionID, action, const DeepCollectionEquality().hash(resources), const DeepCollectionEquality().hash(save), const DeepCollectionEquality().hash(metadata), source);

  final String id;
  final String sessionID;
  final String action;
  final List<String> resources;
  final List<String>? save;
  final Map<String, dynamic>? metadata;
  final PermissionV2Source? source;
}
