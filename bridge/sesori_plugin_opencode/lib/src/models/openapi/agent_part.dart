// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:27.997854Z

import 'part.dart';

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

  final String id;
  final String sessionID;
  final String messageID;
  final String name;
  final Map<String, dynamic>? source;
}
