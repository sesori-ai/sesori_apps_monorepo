// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';
import 'session_error_unknown.dart';

@immutable
class EventSessionNextToolFailed implements Event {
  const EventSessionNextToolFailed({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolFailed.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolFailed(
      id: json["id"] as String,
      properties: EventSessionNextToolFailedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.failed",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolFailed &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextToolFailedProperties properties;
}

@immutable
class EventSessionNextToolFailedProperties {
  const EventSessionNextToolFailedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.error,
    this.result,
    required this.provider,
  });

  factory EventSessionNextToolFailedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolFailedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      error: SessionErrorUnknown.fromJson(json["error"] as Map<String, dynamic>),
      result: json["result"] as Object?,
      provider: EventSessionNextToolFailedPropertiesProvider.fromJson(json["provider"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "error": error.toJson(),
      "result": ?result,
      "provider": provider.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolFailedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          other.error == error &&
          const DeepCollectionEquality().equals(other.result, result) &&
          other.provider == provider);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, error, const DeepCollectionEquality().hash(result), provider);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final SessionErrorUnknown error;
  final Object? result;
  final EventSessionNextToolFailedPropertiesProvider provider;
}

@immutable
class EventSessionNextToolFailedPropertiesProvider {
  const EventSessionNextToolFailedPropertiesProvider({
    required this.executed,
    this.metadata,
  });

  factory EventSessionNextToolFailedPropertiesProvider.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolFailedPropertiesProvider(
      executed: json["executed"] as bool,
      metadata: (json["metadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "executed": executed,
      "metadata": ?metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolFailedPropertiesProvider &&
          other.executed == executed &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(executed, const DeepCollectionEquality().hash(metadata));

  final bool executed;
  final Map<String, Map<String, dynamic>>? metadata;
}
