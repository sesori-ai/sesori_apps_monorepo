// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextToolProgress implements Event {
  const EventSessionNextToolProgress({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolProgress.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolProgress(
      id: json["id"] as String,
      properties: EventSessionNextToolProgressProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.progress",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolProgress &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextToolProgressProperties properties;
}

@immutable
class EventSessionNextToolProgressProperties {
  const EventSessionNextToolProgressProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.structured,
    required this.content,
  });

  factory EventSessionNextToolProgressProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolProgressProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      structured: json["structured"] as Map<String, dynamic>,
      content: (json["content"] as List<dynamic>).cast<Object>(),
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
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolProgressProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          const DeepCollectionEquality().equals(other.structured, structured) &&
          const DeepCollectionEquality().equals(other.content, content));

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, const DeepCollectionEquality().hash(structured), const DeepCollectionEquality().hash(content));

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final Map<String, dynamic> structured;
  final List<Object> content;
}
