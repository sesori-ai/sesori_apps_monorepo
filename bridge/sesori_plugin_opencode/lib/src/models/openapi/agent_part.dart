// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'part.dart';

@immutable
class AgentPart implements Part {
  const AgentPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.name,
    this.source,
  });

  factory AgentPart.fromJson(Map<String, dynamic> json) {
    return AgentPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      name: json["name"] as String,
      source: json["source"] == null ? null : AgentPartSource.fromJson(json["source"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "agent",
      "name": name,
      "source": ?source?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.name == name &&
          other.source == source);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, name, source);

  final String id;
  final String sessionID;
  final String messageID;
  final String name;
  final AgentPartSource? source;
}

@immutable
class AgentPartSource {
  const AgentPartSource({
    required this.value,
    required this.start,
    required this.end,
  });

  factory AgentPartSource.fromJson(Map<String, dynamic> json) {
    return AgentPartSource(
      value: json["value"] as String,
      start: (json["start"] as num).toInt(),
      end: (json["end"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "value": value,
      "start": start,
      "end": end,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentPartSource &&
          other.value == value &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(value, start, end);

  final String value;
  final int start;
  final int end;
}
