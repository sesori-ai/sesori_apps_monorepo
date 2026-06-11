// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
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
      time: json["time"] == null ? null : TextPartTime.fromJson(json["time"] as Map<String, dynamic>),
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
      "time": ?time?.toJson(),
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
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, text, synthetic, ignored, time, const DeepCollectionEquality().hash(metadata));

  final String id;
  final String sessionID;
  final String messageID;
  final String text;
  final bool? synthetic;
  final bool? ignored;
  final TextPartTime? time;
  final Map<String, dynamic>? metadata;
}

@immutable
class TextPartTime {
  const TextPartTime({
    required this.start,
    this.end,
  });

  factory TextPartTime.fromJson(Map<String, dynamic> json) {
    return TextPartTime(
      start: (json["start"] as num).toInt(),
      end: (json["end"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start,
      "end": ?end,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextPartTime &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(start, end);

  final int start;
  final int? end;
}
