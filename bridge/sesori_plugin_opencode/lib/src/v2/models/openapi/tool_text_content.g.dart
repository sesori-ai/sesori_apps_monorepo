// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'tool_content.g.dart';

@immutable
class ToolTextContent implements ToolContent {
  const ToolTextContent({
    required this.text,
  });

  factory ToolTextContent.fromJson(Map<String, dynamic> json) {
    return ToolTextContent(
      text: json["text"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "text",
      "text": text,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ToolTextContent copyWith({
    String? text,
  }) {
    return ToolTextContent(
      text: text ?? this.text,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolTextContent &&
          other.text == text);

  @override
  int get hashCode => text.hashCode;

  final String text;
}
