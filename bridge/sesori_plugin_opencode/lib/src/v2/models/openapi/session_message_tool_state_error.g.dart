// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_tool_state.g.dart';
import 'session_structured_error.g.dart';
import 'tool_content.g.dart';

@immutable
class SessionMessageToolStateError implements SessionMessageToolState {
  const SessionMessageToolStateError({
    required this.input,
    required this.error,
    required this.content,
    required this.metadata,
  });

  factory SessionMessageToolStateError.fromJson(Map<String, dynamic> json) {
    return SessionMessageToolStateError(
      input: json["input"] as Map<String, dynamic>,
      error: SessionStructuredError.fromJson(json["error"] as Map<String, dynamic>),
      content: (json["content"] as List<dynamic>?)?.map((e) => ToolContent.fromJson(e as Map<String, dynamic>)).toList(),
      metadata: json["metadata"] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "error",
      "input": input,
      "error": error.toJson(),
      "content": ?content?.map((e) => e.toJson()).toList(),
      "metadata": ?metadata,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageToolStateError copyWith({
    Map<String, dynamic>? input,
    SessionStructuredError? error,
    List<ToolContent>? content,
    Map<String, dynamic>? metadata,
  }) {
    return SessionMessageToolStateError(
      input: input ?? this.input,
      error: error ?? this.error,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageToolStateError &&
          const DeepCollectionEquality().equals(other.input, input) &&
          other.error == error &&
          const DeepCollectionEquality().equals(other.content, content) &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(input), error, const DeepCollectionEquality().hash(content), const DeepCollectionEquality().hash(metadata));

  final Map<String, dynamic> input;
  final SessionStructuredError error;
  final List<ToolContent>? content;
  final Map<String, dynamic>? metadata;
}
