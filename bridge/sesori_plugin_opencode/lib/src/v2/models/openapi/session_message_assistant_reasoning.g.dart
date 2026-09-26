// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'session_message_assistant_content.g.dart';
import 'session_message_provider_state_1.g.dart';

@immutable
class SessionMessageAssistantReasoning implements SessionMessageAssistantContent {
  const SessionMessageAssistantReasoning({
    required this.text,
    required this.state,
    required this.time,
  });

  factory SessionMessageAssistantReasoning.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantReasoning(
      text: json["text"] as String,
      state: json["state"] == null ? null : SessionMessageProviderState1.fromJson(json["state"] as Map<String, dynamic>),
      time: json["time"] == null ? null : SessionMessageAssistantReasoningTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "reasoning",
      "text": text,
      "state": ?state?.toJson(),
      "time": ?time?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistantReasoning copyWith({
    String? text,
    SessionMessageProviderState1? state,
    SessionMessageAssistantReasoningTime? time,
  }) {
    return SessionMessageAssistantReasoning(
      text: text ?? this.text,
      state: state ?? this.state,
      time: time ?? this.time,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantReasoning &&
          other.text == text &&
          other.state == state &&
          other.time == time);

  @override
  int get hashCode => Object.hash(text, state, time);

  final String text;
  final SessionMessageProviderState1? state;
  final SessionMessageAssistantReasoningTime? time;
}

@immutable
class SessionMessageAssistantReasoningTime {
  const SessionMessageAssistantReasoningTime({
    required this.created,
    required this.completed,
  });

  factory SessionMessageAssistantReasoningTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantReasoningTime(
      created: (json["created"] as num).toDouble(),
      completed: (json["completed"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "completed": ?completed,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistantReasoningTime copyWith({
    double? created,
    double? completed,
  }) {
    return SessionMessageAssistantReasoningTime(
      created: created ?? this.created,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantReasoningTime &&
          other.created == created &&
          other.completed == completed);

  @override
  int get hashCode => Object.hash(created, completed);

  final double created;
  final double? completed;
}
