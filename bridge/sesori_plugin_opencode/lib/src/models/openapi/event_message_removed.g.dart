// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventMessageRemoved implements Event {
  const EventMessageRemoved({
    this.id = '',
    required this.properties,
  });

  factory EventMessageRemoved.fromJson(Map<String, dynamic> json) {
    return EventMessageRemoved(
      id: (json["id"] ?? '') as String,
      properties: EventMessageRemovedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.removed",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMessageRemoved copyWith({
    String? id,
    EventMessageRemovedProperties? properties,
  }) {
    return EventMessageRemoved(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessageRemoved &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventMessageRemovedProperties properties;
}

@immutable
class EventMessageRemovedProperties {
  const EventMessageRemovedProperties({
    this.sessionID = '',
    this.messageID = '',
  });

  factory EventMessageRemovedProperties.fromJson(Map<String, dynamic> json) {
    return EventMessageRemovedProperties(
      sessionID: (json["sessionID"] ?? '') as String,
      messageID: (json["messageID"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "messageID": messageID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMessageRemovedProperties copyWith({
    String? sessionID,
    String? messageID,
  }) {
    return EventMessageRemovedProperties(
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessageRemovedProperties &&
          other.sessionID == sessionID &&
          other.messageID == messageID);

  @override
  int get hashCode => Object.hash(sessionID, messageID);

  final String sessionID;
  final String messageID;
}
