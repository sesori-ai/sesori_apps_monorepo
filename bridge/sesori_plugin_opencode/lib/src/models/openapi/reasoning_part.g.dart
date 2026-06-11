// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'part.g.dart';

@immutable
class ReasoningPart implements Part {
  const ReasoningPart({
    this.id = '',
    this.sessionID = '',
    this.messageID = '',
    this.text = '',
    this.metadata,
    required this.time,
  });

  factory ReasoningPart.fromJson(Map<String, dynamic> json) {
    return ReasoningPart(
      id: (json["id"] ?? '') as String,
      sessionID: (json["sessionID"] ?? '') as String,
      messageID: (json["messageID"] ?? '') as String,
      text: (json["text"] ?? '') as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: ReasoningPartTime.fromJson((json["time"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ReasoningPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    String? text,
    Map<String, dynamic>? metadata,
    ReasoningPartTime? time,
  }) {
    return ReasoningPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      text: text ?? this.text,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
    );
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
    this.start = 0,
    this.end,
  });

  factory ReasoningPartTime.fromJson(Map<String, dynamic> json) {
    return ReasoningPartTime(
      start: ((json["start"] ?? 0) as num).toInt(),
      end: (json["end"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start,
      "end": ?end,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ReasoningPartTime copyWith({
    int? start,
    int? end,
  }) {
    return ReasoningPartTime(
      start: start ?? this.start,
      end: end ?? this.end,
    );
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
