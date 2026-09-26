// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';

@immutable
class PromptMention {
  const PromptMention({
    required this.start,
    required this.end,
    required this.text,
  });

  factory PromptMention.fromJson(Map<String, dynamic> json) {
    return PromptMention(
      start: (json["start"] as num).toDouble(),
      end: (json["end"] as num).toDouble(),
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start,
      "end": end,
      "text": text,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PromptMention copyWith({
    double? start,
    double? end,
    String? text,
  }) {
    return PromptMention(
      start: start ?? this.start,
      end: end ?? this.end,
      text: text ?? this.text,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptMention &&
          other.start == start &&
          other.end == end &&
          other.text == text);

  @override
  int get hashCode => Object.hash(start, end, text);

  final double start;
  final double end;
  final String text;
}
