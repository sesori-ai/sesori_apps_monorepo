// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.973902Z

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
      time: json["time"] as Map<String, dynamic>?,
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
      "time": ?time,
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
          other.metadata == metadata);

  @override
  int get hashCode => Object.hash(id, type, text, synthetic, ignored, time, metadata);

  final String? id;
  final String type;
  final String text;
  final bool? synthetic;
  final bool? ignored;
  final Map<String, dynamic>? time;
  final Map<String, dynamic>? metadata;
}
