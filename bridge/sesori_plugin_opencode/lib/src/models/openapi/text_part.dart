// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.258442Z

import 'package:meta/meta.dart';
import 'part.dart';

@immutable
class TextPart implements Part {
  const TextPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.text,
    this.synthetic,
    this.ignored,
    this.time,
    this.metadata,
  });

  factory TextPart.fromJson(Map<String, dynamic> json) {
    return TextPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      text: json["text"] as String,
      synthetic: json["synthetic"] as bool?,
      ignored: json["ignored"] as bool?,
      time: json["time"] as Map<String, dynamic>?,
      metadata: json["metadata"] as Map<String, dynamic>?,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "text",
      "text": text,
      "synthetic": ?synthetic,
      "ignored": ?ignored,
      "time": ?time,
      "metadata": ?metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.text == text &&
          other.synthetic == synthetic &&
          other.ignored == ignored &&
          other.time == time &&
          other.metadata == metadata);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, text, synthetic, ignored, time, metadata);

  final String id;
  final String sessionID;
  final String messageID;
  final String text;
  final bool? synthetic;
  final bool? ignored;
  final Map<String, dynamic>? time;
  final Map<String, dynamic>? metadata;
}
