// GENERATED FILE - DO NOT EDIT BY HAND

import 'session_message.dart';

class SessionMessageSynthetic implements SessionMessage {
  const SessionMessageSynthetic({
    required this.id,
    this.metadata,
    required this.time,
    required this.sessionID,
    required this.text,
    required this.type,
  });

  factory SessionMessageSynthetic.fromJson(Map<String, dynamic> json) {
    return SessionMessageSynthetic(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      sessionID: json["sessionID"] as String,
      text: json["text"] as String,
      type: json["type"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": metadata,
      "time": time,
      "sessionID": sessionID,
      "text": text,
      "type": type,
    };
  }

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final String sessionID;
  final String text;
  final String type;
}
