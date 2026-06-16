// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventMessagePartDelta implements Event {
  const EventMessagePartDelta({
    required this.id,
    required this.properties,
  });

  factory EventMessagePartDelta.fromJson(Map<String, dynamic> json) {
    return EventMessagePartDelta(
      id: json["id"] as String,
      properties: EventMessagePartDeltaProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.part.delta",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMessagePartDelta copyWith({
    String? id,
    EventMessagePartDeltaProperties? properties,
  }) {
    return EventMessagePartDelta(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessagePartDelta &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventMessagePartDeltaProperties properties;
}

@immutable
class EventMessagePartDeltaProperties {
  const EventMessagePartDeltaProperties({
    required this.sessionID,
    required this.messageID,
    required this.partID,
    required this.field,
    required this.delta,
  });

  factory EventMessagePartDeltaProperties.fromJson(Map<String, dynamic> json) {
    return EventMessagePartDeltaProperties(
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      partID: json["partID"] as String,
      field: json["field"] as String,
      delta: json["delta"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "messageID": messageID,
      "partID": partID,
      "field": field,
      "delta": delta,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMessagePartDeltaProperties copyWith({
    String? sessionID,
    String? messageID,
    String? partID,
    String? field,
    String? delta,
  }) {
    return EventMessagePartDeltaProperties(
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      partID: partID ?? this.partID,
      field: field ?? this.field,
      delta: delta ?? this.delta,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessagePartDeltaProperties &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.partID == partID &&
          other.field == field &&
          other.delta == delta);

  @override
  int get hashCode => Object.hash(sessionID, messageID, partID, field, delta);

  final String sessionID;
  final String messageID;
  final String partID;
  final String field;
  final String delta;
}
