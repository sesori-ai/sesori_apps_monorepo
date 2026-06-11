// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextToolSuccess implements Event {
  const EventSessionNextToolSuccess({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolSuccess.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolSuccess(
      id: json["id"] as String,
      properties: EventSessionNextToolSuccessProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.success",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolSuccess &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextToolSuccessProperties properties;
}

@immutable
class EventSessionNextToolSuccessProperties {
  const EventSessionNextToolSuccessProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.structured,
    required this.content,
    this.result,
    required this.provider,
  });

  factory EventSessionNextToolSuccessProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolSuccessProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      structured: json["structured"] as Map<String, dynamic>,
      content: (json["content"] as List<dynamic>).cast<Object>(),
      result: json["result"] as Object?,
      provider: EventSessionNextToolSuccessPropertiesProvider.fromJson(json["provider"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "structured": structured,
      "content": content,
      "result": ?result,
      "provider": provider.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolSuccessProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          const DeepCollectionEquality().equals(other.structured, structured) &&
          const DeepCollectionEquality().equals(other.content, content) &&
          const DeepCollectionEquality().equals(other.result, result) &&
          other.provider == provider);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, const DeepCollectionEquality().hash(structured), const DeepCollectionEquality().hash(content), const DeepCollectionEquality().hash(result), provider);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final Map<String, dynamic> structured;
  final List<Object> content;
  final Object? result;
  final EventSessionNextToolSuccessPropertiesProvider provider;
}

@immutable
class EventSessionNextToolSuccessPropertiesProvider {
  const EventSessionNextToolSuccessPropertiesProvider({
    required this.executed,
    this.metadata,
  });

  factory EventSessionNextToolSuccessPropertiesProvider.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolSuccessPropertiesProvider(
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
      (other is EventSessionNextToolSuccessPropertiesProvider &&
          other.executed == executed &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(executed, const DeepCollectionEquality().hash(metadata));

  final bool executed;
  final Map<String, Map<String, dynamic>>? metadata;
}
