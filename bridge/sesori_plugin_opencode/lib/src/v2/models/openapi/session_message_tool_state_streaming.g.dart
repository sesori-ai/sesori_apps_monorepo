// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'session_message_tool_state.g.dart';

@immutable
class SessionMessageToolStateStreaming implements SessionMessageToolState {
  const SessionMessageToolStateStreaming({
    required this.input,
  });

  factory SessionMessageToolStateStreaming.fromJson(Map<String, dynamic> json) {
    return SessionMessageToolStateStreaming(
      input: json["input"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "streaming",
      "input": input,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageToolStateStreaming copyWith({
    String? input,
  }) {
    return SessionMessageToolStateStreaming(
      input: input ?? this.input,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageToolStateStreaming &&
          other.input == input);

  @override
  int get hashCode => input.hashCode;

  final String input;
}
