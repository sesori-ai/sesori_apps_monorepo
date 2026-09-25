// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';
import 'session_structured_error.g.dart';

@immutable
class SessionMessageAssistantRetry {
  const SessionMessageAssistantRetry({
    required this.attempt,
    required this.at,
    required this.error,
  });

  factory SessionMessageAssistantRetry.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantRetry(
      attempt: (json["attempt"] as num).toInt(),
      at: (json["at"] as num).toDouble(),
      error: SessionStructuredError.fromJson(json["error"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "attempt": attempt,
      "at": at,
      "error": error.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistantRetry copyWith({
    int? attempt,
    double? at,
    SessionStructuredError? error,
  }) {
    return SessionMessageAssistantRetry(
      attempt: attempt ?? this.attempt,
      at: at ?? this.at,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantRetry &&
          other.attempt == attempt &&
          other.at == at &&
          other.error == error);

  @override
  int get hashCode => Object.hash(attempt, at, error);

  final int attempt;
  final double at;
  final SessionStructuredError error;
}
