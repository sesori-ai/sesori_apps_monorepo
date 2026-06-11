// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
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
      time: ReasoningPartTime.fromJson(json["time"] as Map<String, dynamic>),
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
      "time": time.toJson(),
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
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, text, const DeepCollectionEquality().hash(metadata), time);

  final String id;
  final String sessionID;
  final String messageID;
  final String text;
  final Map<String, dynamic>? metadata;
  final ReasoningPartTime time;
}

@immutable
class ReasoningPartTime {
  const ReasoningPartTime({
    required this.start,
    this.end,
  });

  factory ReasoningPartTime.fromJson(Map<String, dynamic> json) {
    return ReasoningPartTime(
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
      (other is ReasoningPartTime &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(start, end);

  final int start;
  final int? end;
}
