// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:meta/meta.dart';
import 'session_message_assistant_content.g.dart';
import 'session_message_native_2.g.dart';
import 'session_message_tool_state.g.dart';

@immutable
class SessionMessageAssistantTool implements SessionMessageAssistantContent {
  const SessionMessageAssistantTool({
    required this.id,
    required this.name,
    required this.executed,
    required this.native,
    required this.state,
    required this.time,
  });

  factory SessionMessageAssistantTool.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantTool(
      id: json["id"] as String,
      name: json["name"] as String,
      executed: json["executed"] as bool?,
      native: json["native"] == null ? null : SessionMessageNative2.fromJson(json["native"] as Map<String, dynamic>),
      state: SessionMessageToolState.fromJson(json["state"] as Object),
      time: SessionMessageAssistantToolTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "tool",
      "id": id,
      "name": name,
      "executed": ?executed,
      "native": ?native?.toJson(),
      "state": state.toJson(),
      "time": time.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistantTool copyWith({
    String? id,
    String? name,
    bool? executed,
    SessionMessageNative2? native,
    SessionMessageToolState? state,
    SessionMessageAssistantToolTime? time,
  }) {
    return SessionMessageAssistantTool(
      id: id ?? this.id,
      name: name ?? this.name,
      executed: executed ?? this.executed,
      native: native ?? this.native,
      state: state ?? this.state,
      time: time ?? this.time,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantTool &&
          other.id == id &&
          other.name == name &&
          other.executed == executed &&
          other.native == native &&
          other.state == state &&
          other.time == time);

  @override
  int get hashCode => Object.hash(id, name, executed, native, state, time);

  final String id;
  final String name;
  final bool? executed;
  final SessionMessageNative2? native;
  final SessionMessageToolState state;
  final SessionMessageAssistantToolTime time;
}

@immutable
class SessionMessageAssistantToolTime {
  const SessionMessageAssistantToolTime({
    required this.created,
    required this.ran,
    required this.completed,
  });

  factory SessionMessageAssistantToolTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantToolTime(
      created: (json["created"] as num).toDouble(),
      ran: (json["ran"] as num?)?.toDouble(),
      completed: (json["completed"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "ran": ?ran,
      "completed": ?completed,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistantToolTime copyWith({
    double? created,
    double? ran,
    double? completed,
  }) {
    return SessionMessageAssistantToolTime(
      created: created ?? this.created,
      ran: ran ?? this.ran,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantToolTime &&
          other.created == created &&
          other.ran == ran &&
          other.completed == completed);

  @override
  int get hashCode => Object.hash(created, ran, completed);

  final double created;
  final double? ran;
  final double? completed;
}
