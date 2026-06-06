// GENERATED FILE - DO NOT EDIT BY HAND

import 'part.dart';

class TextPart implements Part {
  const TextPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.type,
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
      type: json["type"] as String,
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
      "type": type,
      "text": text,
      "synthetic": synthetic,
      "ignored": ignored,
      "time": time,
      "metadata": metadata,
    };
  }

  final String id;
  final String sessionID;
  final String messageID;
  final String type;
  final String text;
  final bool? synthetic;
  final bool? ignored;
  final Map<String, dynamic>? time;
  final Map<String, dynamic>? metadata;
}
