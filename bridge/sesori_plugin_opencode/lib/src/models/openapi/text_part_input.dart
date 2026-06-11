// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class TextPartInput {
  const TextPartInput({
    this.id,
    required this.type,
    required this.text,
    this.synthetic,
    this.ignored,
    this.time,
    this.metadata,
  });

  factory TextPartInput.fromJson(Map<String, dynamic> json) {
    return TextPartInput(
      id: json["id"] as String?,
      type: json["type"] as String,
      text: json["text"] as String,
      synthetic: json["synthetic"] as bool?,
      ignored: json["ignored"] as bool?,
      time: json["time"] == null ? null : TextPartInputTime.fromJson(json["time"] as Map<String, dynamic>),
      metadata: json["metadata"] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": ?id,
      "type": type,
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
      (other is TextPartInput &&
          other.id == id &&
          other.type == type &&
          other.text == text &&
          other.synthetic == synthetic &&
          other.ignored == ignored &&
          other.time == time &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(id, type, text, synthetic, ignored, time, const DeepCollectionEquality().hash(metadata));

  final String? id;
  final String type;
  final String text;
  final bool? synthetic;
  final bool? ignored;
  final TextPartInputTime? time;
  final Map<String, dynamic>? metadata;
}

@immutable
class TextPartInputTime {
  const TextPartInputTime({
    required this.start,
    this.end,
  });

  factory TextPartInputTime.fromJson(Map<String, dynamic> json) {
    return TextPartInputTime(
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
      (other is TextPartInputTime &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(start, end);

  final int start;
  final int? end;
}
