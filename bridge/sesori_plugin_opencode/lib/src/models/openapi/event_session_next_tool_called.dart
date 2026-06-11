// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextToolCalled implements Event {
  const EventSessionNextToolCalled({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolCalled.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolCalled(
      id: json["id"] as String,
      properties: EventSessionNextToolCalledProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.called",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolCalled &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextToolCalledProperties properties;
}

@immutable
class EventSessionNextToolCalledProperties {
  const EventSessionNextToolCalledProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.tool,
    required this.input,
    required this.provider,
  });

  factory EventSessionNextToolCalledProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolCalledProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      tool: json["tool"] as String,
      input: json["input"] as Map<String, dynamic>,
      provider: EventSessionNextToolCalledPropertiesProvider.fromJson(json["provider"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "tool": tool,
      "input": input,
      "provider": provider.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolCalledProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          other.tool == tool &&
          const DeepCollectionEquality().equals(other.input, input) &&
          other.provider == provider);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, tool, const DeepCollectionEquality().hash(input), provider);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final String tool;
  final Map<String, dynamic> input;
  final EventSessionNextToolCalledPropertiesProvider provider;
}

@immutable
class EventSessionNextToolCalledPropertiesProvider {
  const EventSessionNextToolCalledPropertiesProvider({
    required this.executed,
    this.metadata,
  });

  factory EventSessionNextToolCalledPropertiesProvider.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolCalledPropertiesProvider(
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
      (other is EventSessionNextToolCalledPropertiesProvider &&
          other.executed == executed &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(executed, const DeepCollectionEquality().hash(metadata));

  final bool executed;
  final Map<String, Map<String, dynamic>>? metadata;
}
