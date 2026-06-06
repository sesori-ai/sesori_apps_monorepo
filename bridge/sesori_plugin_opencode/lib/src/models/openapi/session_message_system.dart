// GENERATED FILE - DO NOT EDIT BY HAND

import 'session_message.dart';

class SessionMessageSystem implements SessionMessage {
  const SessionMessageSystem({
    required this.id,
    this.metadata,
    required this.time,
    required this.type,
    required this.text,
  });

  factory SessionMessageSystem.fromJson(Map<String, dynamic> json) {
    return SessionMessageSystem(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      type: json["type"] as String,
      text: json["text"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": metadata,
      "time": time,
      "type": type,
      "text": text,
    };
  }

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final String type;
  final String text;
}
