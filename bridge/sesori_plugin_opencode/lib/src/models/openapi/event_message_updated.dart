// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'message.dart';

@immutable
class EventMessageUpdated implements Event {
  const EventMessageUpdated({
    required this.id,
    required this.properties,
  });

  factory EventMessageUpdated.fromJson(Map<String, dynamic> json) {
    return EventMessageUpdated(
      id: json["id"] as String,
      properties: EventMessageUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.updated",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessageUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventMessageUpdatedProperties properties;
}

@immutable
class EventMessageUpdatedProperties {
  const EventMessageUpdatedProperties({
    required this.sessionID,
    required this.info,
  });

  factory EventMessageUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventMessageUpdatedProperties(
      sessionID: json["sessionID"] as String,
      info: Message.fromJson(json["info"] as Object),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "info": info.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessageUpdatedProperties &&
          other.sessionID == sessionID &&
          other.info == info);

  @override
  int get hashCode => Object.hash(sessionID, info);

  final String sessionID;
  final Message info;
}
