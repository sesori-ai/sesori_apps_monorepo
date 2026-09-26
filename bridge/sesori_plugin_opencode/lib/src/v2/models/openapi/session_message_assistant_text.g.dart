// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'session_message_assistant_content.g.dart';
import 'session_message_provider_state.g.dart';

@immutable
class SessionMessageAssistantText implements SessionMessageAssistantContent {
  const SessionMessageAssistantText({
    required this.text,
    required this.state,
  });

  factory SessionMessageAssistantText.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantText(
      text: json["text"] as String,
      state: json["state"] == null ? null : SessionMessageProviderState.fromJson(json["state"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "text",
      "text": text,
      "state": ?state?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistantText copyWith({
    String? text,
    SessionMessageProviderState? state,
  }) {
    return SessionMessageAssistantText(
      text: text ?? this.text,
      state: state ?? this.state,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantText &&
          other.text == text &&
          other.state == state);

  @override
  int get hashCode => Object.hash(text, state);

  final String text;
  final SessionMessageProviderState? state;
}
