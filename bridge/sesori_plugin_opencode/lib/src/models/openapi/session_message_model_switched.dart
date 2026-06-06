// GENERATED FILE - DO NOT EDIT BY HAND

import 'session_message.dart';

class SessionMessageModelSwitched implements SessionMessage {
  const SessionMessageModelSwitched({
    required this.id,
    this.metadata,
    required this.time,
    required this.model,
  });

  factory SessionMessageModelSwitched.fromJson(Map<String, dynamic> json) {
    return SessionMessageModelSwitched(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      model: json["model"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": metadata,
      "time": time,
      "type": "model-switched",
      "model": model,
    };
  }

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final Map<String, dynamic> model;
}
