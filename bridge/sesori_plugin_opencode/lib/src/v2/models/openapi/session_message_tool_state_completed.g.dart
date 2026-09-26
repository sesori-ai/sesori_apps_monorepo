// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_tool_state.g.dart';
import 'tool_content.g.dart';

@immutable
class SessionMessageToolStateCompleted implements SessionMessageToolState {
  const SessionMessageToolStateCompleted({
    required this.input,
    required this.content,
    required this.metadata,
  });

  factory SessionMessageToolStateCompleted.fromJson(Map<String, dynamic> json) {
    return SessionMessageToolStateCompleted(
      input: json["input"] as Map<String, dynamic>,
      content: (json["content"] as List<dynamic>).map((e) => ToolContent.fromJson(e as Map<String, dynamic>)).toList(),
      metadata: json["metadata"] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "completed",
      "input": input,
      "content": content.map((e) => e.toJson()).toList(),
      "metadata": ?metadata,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageToolStateCompleted copyWith({
    Map<String, dynamic>? input,
    List<ToolContent>? content,
    Map<String, dynamic>? metadata,
  }) {
    return SessionMessageToolStateCompleted(
      input: input ?? this.input,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageToolStateCompleted &&
          const DeepCollectionEquality().equals(other.input, input) &&
          const DeepCollectionEquality().equals(other.content, content) &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(input), const DeepCollectionEquality().hash(content), const DeepCollectionEquality().hash(metadata));

  final Map<String, dynamic> input;
  final List<ToolContent> content;
  final Map<String, dynamic>? metadata;
}
