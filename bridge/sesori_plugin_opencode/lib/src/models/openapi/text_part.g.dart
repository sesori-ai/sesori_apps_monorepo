// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'part.g.dart';

@immutable
class TextPart implements Part {
  const TextPart({
    this.id = '',
    this.sessionID = '',
    this.messageID = '',
    this.text = '',
    this.synthetic,
    this.ignored,
    this.time,
    this.metadata,
  });

  factory TextPart.fromJson(Map<String, dynamic> json) {
    return TextPart(
      id: (json["id"] ?? '') as String,
      sessionID: (json["sessionID"] ?? '') as String,
      messageID: (json["messageID"] ?? '') as String,
      text: (json["text"] ?? '') as String,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  TextPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    String? text,
    bool? synthetic,
    bool? ignored,
    TextPartTime? time,
    Map<String, dynamic>? metadata,
  }) {
    return TextPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      text: text ?? this.text,
      synthetic: synthetic ?? this.synthetic,
      ignored: ignored ?? this.ignored,
      time: time ?? this.time,
      metadata: metadata ?? this.metadata,
    );
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
    this.start = 0,
    this.end,
  });

  factory TextPartTime.fromJson(Map<String, dynamic> json) {
    return TextPartTime(
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
  TextPartTime copyWith({
    int? start,
    int? end,
  }) {
    return TextPartTime(
      start: start ?? this.start,
      end: end ?? this.end,
    );
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
