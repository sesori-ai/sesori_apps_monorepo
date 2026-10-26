// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:meta/meta.dart';
import 'session_message_assistant_content.g.dart';
import 'session_message_native.g.dart';

@immutable
class SessionMessageAssistantText implements SessionMessageAssistantContent {
  const SessionMessageAssistantText({
    required this.text,
    required this.native,
  });

  factory SessionMessageAssistantText.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantText(
      text: json["text"] as String,
      native: json["native"] == null ? null : SessionMessageNative.fromJson(json["native"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "text",
      "text": text,
      "native": ?native?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistantText copyWith({
    String? text,
    SessionMessageNative? native,
  }) {
    return SessionMessageAssistantText(
      text: text ?? this.text,
      native: native ?? this.native,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantText &&
          other.text == text &&
          other.native == native);

  @override
  int get hashCode => Object.hash(text, native);

  final String text;
  final SessionMessageNative? native;
}
