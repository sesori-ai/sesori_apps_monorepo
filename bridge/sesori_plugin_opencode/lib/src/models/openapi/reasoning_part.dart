// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.987460Z

import 'package:meta/meta.dart';
import 'part.dart';

@immutable
class ReasoningPart implements Part {
  const ReasoningPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.text,
    this.metadata,
    required this.time,
  });

  factory ReasoningPart.fromJson(Map<String, dynamic> json) {
    return ReasoningPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      text: json["text"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "reasoning",
      "text": text,
      "metadata": ?metadata,
      "time": time,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReasoningPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.text == text &&
          other.metadata == metadata &&
          other.time == time);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, text, metadata, time);

  final String id;
  final String sessionID;
  final String messageID;
  final String text;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
}
