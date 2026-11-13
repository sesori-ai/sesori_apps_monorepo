// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:meta/meta.dart';
import 'session_message_assistant_content.g.dart';
import 'session_message_native.g.dart';

@immutable
class SessionMessageAssistantReasoning implements SessionMessageAssistantContent {
  const SessionMessageAssistantReasoning({
    required this.text,
    required this.native,
    required this.time,
  });

  factory SessionMessageAssistantReasoning.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantReasoning(
      text: json["text"] as String,
      native: json["native"] == null ? null : SessionMessageNative.fromJson(json["native"] as Map<String, dynamic>),
      time: json["time"] == null ? null : SessionMessageAssistantReasoningTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "reasoning",
      "text": text,
      "native": ?native?.toJson(),
      "time": ?time?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistantReasoning copyWith({
    String? text,
    SessionMessageNative? native,
    SessionMessageAssistantReasoningTime? time,
  }) {
    return SessionMessageAssistantReasoning(
      text: text ?? this.text,
      native: native ?? this.native,
      time: time ?? this.time,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantReasoning &&
          other.text == text &&
          other.native == native &&
          other.time == time);

  @override
  int get hashCode => Object.hash(text, native, time);

  final String text;
  final SessionMessageNative? native;
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
