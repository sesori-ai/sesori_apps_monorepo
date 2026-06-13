// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';
import 'message.g.dart';

@immutable
class EventMessageUpdated implements Event {
  const EventMessageUpdated({
    this.id = '',
    required this.properties,
  });

  factory EventMessageUpdated.fromJson(Map<String, dynamic> json) {
    return EventMessageUpdated(
      id: (json["id"] ?? '') as String,
      properties: EventMessageUpdatedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMessageUpdated copyWith({
    String? id,
    EventMessageUpdatedProperties? properties,
  }) {
    return EventMessageUpdated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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
    this.sessionID = '',
    required this.info,
  });

  factory EventMessageUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventMessageUpdatedProperties(
      sessionID: (json["sessionID"] ?? '') as String,
      info: Message.fromJson((json["info"] ?? const <String, dynamic>{}) as Object),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "info": info.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMessageUpdatedProperties copyWith({
    String? sessionID,
    Message? info,
  }) {
    return EventMessageUpdatedProperties(
      sessionID: sessionID ?? this.sessionID,
      info: info ?? this.info,
    );
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
