// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SessionMessageAssistantTool {
  const SessionMessageAssistantTool({
    required this.type,
    required this.id,
    required this.name,
    this.provider,
    required this.state,
    required this.time,
  });

  factory SessionMessageAssistantTool.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantTool(
      type: json["type"] as String,
      id: json["id"] as String,
      name: json["name"] as String,
      provider: json["provider"] == null ? null : SessionMessageAssistantToolProvider.fromJson(json["provider"] as Map<String, dynamic>),
      state: json["state"] as Object,
      time: SessionMessageAssistantToolTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "id": id,
      "name": name,
      "provider": ?provider?.toJson(),
      "state": state,
      "time": time.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantTool &&
          other.type == type &&
          other.id == id &&
          other.name == name &&
          other.provider == provider &&
          const DeepCollectionEquality().equals(other.state, state) &&
          other.time == time);

  @override
  int get hashCode => Object.hash(type, id, name, provider, const DeepCollectionEquality().hash(state), time);

  final String type;
  final String id;
  final String name;
  final SessionMessageAssistantToolProvider? provider;
  final Object state;
  final SessionMessageAssistantToolTime time;
}

@immutable
class SessionMessageAssistantToolProvider {
  const SessionMessageAssistantToolProvider({
    required this.executed,
    this.metadata,
    this.resultMetadata,
  });

  factory SessionMessageAssistantToolProvider.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantToolProvider(
      executed: json["executed"] as bool,
      metadata: (json["metadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
      resultMetadata: (json["resultMetadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "executed": executed,
      "metadata": ?metadata,
      "resultMetadata": ?resultMetadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantToolProvider &&
          other.executed == executed &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          const DeepCollectionEquality().equals(other.resultMetadata, resultMetadata));

  @override
  int get hashCode => Object.hash(executed, const DeepCollectionEquality().hash(metadata), const DeepCollectionEquality().hash(resultMetadata));

  final bool executed;
  final Map<String, Map<String, dynamic>>? metadata;
  final Map<String, Map<String, dynamic>>? resultMetadata;
}

@immutable
class SessionMessageAssistantToolTime {
  const SessionMessageAssistantToolTime({
    required this.created,
    this.ran,
    this.completed,
    this.pruned,
  });

  factory SessionMessageAssistantToolTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantToolTime(
      created: (json["created"] as num).toDouble(),
      ran: (json["ran"] as num?)?.toDouble(),
      completed: (json["completed"] as num?)?.toDouble(),
      pruned: (json["pruned"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "ran": ?ran,
      "completed": ?completed,
      "pruned": ?pruned,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantToolTime &&
          other.created == created &&
          other.ran == ran &&
          other.completed == completed &&
          other.pruned == pruned);

  @override
  int get hashCode => Object.hash(created, ran, completed, pruned);

  final double created;
  final double? ran;
  final double? completed;
  final double? pruned;
}
