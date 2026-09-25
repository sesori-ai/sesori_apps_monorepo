// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';
import 'session_message_assistant_content.g.dart';
import 'session_message_provider_state_2.g.dart';
import 'session_message_provider_state_3.g.dart';
import 'session_message_tool_state.g.dart';

@immutable
class SessionMessageAssistantTool implements SessionMessageAssistantContent {
  const SessionMessageAssistantTool({
    required this.id,
    required this.name,
    required this.executed,
    required this.providerState,
    required this.providerResultState,
    required this.state,
    required this.time,
  });

  factory SessionMessageAssistantTool.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantTool(
      id: json["id"] as String,
      name: json["name"] as String,
      executed: json["executed"] as bool?,
      providerState: json["providerState"] == null ? null : SessionMessageProviderState2.fromJson(json["providerState"] as Map<String, dynamic>),
      providerResultState: json["providerResultState"] == null ? null : SessionMessageProviderState3.fromJson(json["providerResultState"] as Map<String, dynamic>),
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
      "providerState": ?providerState?.toJson(),
      "providerResultState": ?providerResultState?.toJson(),
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
    SessionMessageProviderState2? providerState,
    SessionMessageProviderState3? providerResultState,
    SessionMessageToolState? state,
    SessionMessageAssistantToolTime? time,
  }) {
    return SessionMessageAssistantTool(
      id: id ?? this.id,
      name: name ?? this.name,
      executed: executed ?? this.executed,
      providerState: providerState ?? this.providerState,
      providerResultState: providerResultState ?? this.providerResultState,
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
          other.providerState == providerState &&
          other.providerResultState == providerResultState &&
          other.state == state &&
          other.time == time);

  @override
  int get hashCode => Object.hash(id, name, executed, providerState, providerResultState, state, time);

  final String id;
  final String name;
  final bool? executed;
  final SessionMessageProviderState2? providerState;
  final SessionMessageProviderState3? providerResultState;
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
