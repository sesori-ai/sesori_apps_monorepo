// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.353788Z

import 'session_message.dart';

class SessionMessageSynthetic implements SessionMessage {
  const SessionMessageSynthetic({
    required this.id,
    this.metadata,
    required this.time,
    required this.sessionID,
    required this.text,
  });

  factory SessionMessageSynthetic.fromJson(Map<String, dynamic> json) {
    return SessionMessageSynthetic(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      sessionID: json["sessionID"] as String,
      text: json["text"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time,
      "sessionID": sessionID,
      "text": text,
      "type": "synthetic",
    };
  }

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final String sessionID;
  final String text;
}
