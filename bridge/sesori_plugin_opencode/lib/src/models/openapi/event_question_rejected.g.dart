// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventQuestionRejected implements Event {
  const EventQuestionRejected({
    this.id = '',
    required this.properties,
  });

  factory EventQuestionRejected.fromJson(Map<String, dynamic> json) {
    return EventQuestionRejected(
      id: (json["id"] ?? '') as String,
      properties: EventQuestionRejectedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "question.rejected",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventQuestionRejected copyWith({
    String? id,
    EventQuestionRejectedProperties? properties,
  }) {
    return EventQuestionRejected(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventQuestionRejected &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventQuestionRejectedProperties properties;
}

@immutable
class EventQuestionRejectedProperties {
  const EventQuestionRejectedProperties({
    this.sessionID = '',
    this.requestID = '',
  });

  factory EventQuestionRejectedProperties.fromJson(Map<String, dynamic> json) {
    return EventQuestionRejectedProperties(
      sessionID: (json["sessionID"] ?? '') as String,
      requestID: (json["requestID"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "requestID": requestID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventQuestionRejectedProperties copyWith({
    String? sessionID,
    String? requestID,
  }) {
    return EventQuestionRejectedProperties(
      sessionID: sessionID ?? this.sessionID,
      requestID: requestID ?? this.requestID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventQuestionRejectedProperties &&
          other.sessionID == sessionID &&
          other.requestID == requestID);

  @override
  int get hashCode => Object.hash(sessionID, requestID);

  final String sessionID;
  final String requestID;
}
