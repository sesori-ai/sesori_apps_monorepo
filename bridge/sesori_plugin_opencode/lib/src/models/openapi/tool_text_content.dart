// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.260623Z

import 'package:meta/meta.dart';

@immutable
class ToolTextContent {
  const ToolTextContent({
    required this.type,
    required this.text,
  });

  factory ToolTextContent.fromJson(Map<String, dynamic> json) {
    return ToolTextContent(
      type: json["type"] as String,
      text: json["text"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolTextContent &&
          other.type == type &&
          other.text == text);

  @override
  int get hashCode => Object.hash(type, text);

  final String type;
  final String text;
}
