// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.940911Z

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
      source: json["source"] as Map<String, dynamic>?,
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
      "source": ?source,
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
  final Map<String, dynamic>? source;
}
