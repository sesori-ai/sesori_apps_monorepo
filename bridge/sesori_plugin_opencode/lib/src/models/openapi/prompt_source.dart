// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.983585Z

import 'package:meta/meta.dart';

@immutable
class PromptSource {
  const PromptSource({
    required this.start,
    required this.end,
    required this.text,
  });

  factory PromptSource.fromJson(Map<String, dynamic> json) {
    return PromptSource(
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptSource &&
          other.start == start &&
          other.end == end &&
          other.text == text);

  @override
  int get hashCode => Object.hash(start, end, text);

  final double start;
  final double end;
  final String text;
}
