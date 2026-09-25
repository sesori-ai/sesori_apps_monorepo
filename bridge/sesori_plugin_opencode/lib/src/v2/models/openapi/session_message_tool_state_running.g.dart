// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_tool_state.g.dart';

@immutable
class SessionMessageToolStateRunning implements SessionMessageToolState {
  const SessionMessageToolStateRunning({
    required this.input,
    required this.metadata,
  });

  factory SessionMessageToolStateRunning.fromJson(Map<String, dynamic> json) {
    return SessionMessageToolStateRunning(
      input: json["input"] as Map<String, dynamic>,
      metadata: json["metadata"] as Map<String, dynamic>,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "running",
      "input": input,
      "metadata": metadata,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageToolStateRunning copyWith({
    Map<String, dynamic>? input,
    Map<String, dynamic>? metadata,
  }) {
    return SessionMessageToolStateRunning(
      input: input ?? this.input,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageToolStateRunning &&
          const DeepCollectionEquality().equals(other.input, input) &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(input), const DeepCollectionEquality().hash(metadata));

  final Map<String, dynamic> input;
  final Map<String, dynamic> metadata;
}
