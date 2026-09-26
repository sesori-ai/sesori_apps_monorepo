// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'session_message_info.g.dart';

@immutable
class SessionMessageShell implements SessionMessageInfo {
  const SessionMessageShell({
    required this.id,
    required this.metadata,
    required this.time,
    required this.shellID,
    required this.command,
    required this.status,
    required this.exit,
    required this.output,
  });

  factory SessionMessageShell.fromJson(Map<String, dynamic> json) {
    return SessionMessageShell(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageShellTime.fromJson(json["time"] as Map<String, dynamic>),
      shellID: json["shellID"] as String,
      command: json["command"] as String,
      status: SessionMessageShellStatus.fromJson(json["status"] as String),
      exit: json["exit"] as Object?,
      output: json["output"] == null ? null : SessionMessageShellOutput.fromJson(json["output"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "type": "shell",
      "shellID": shellID,
      "command": command,
      "status": status.toJson(),
      "exit": ?exit,
      "output": ?output?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageShell copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageShellTime? time,
    String? shellID,
    String? command,
    SessionMessageShellStatus? status,
    Object? exit,
    SessionMessageShellOutput? output,
  }) {
    return SessionMessageShell(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      shellID: shellID ?? this.shellID,
      command: command ?? this.command,
      status: status ?? this.status,
      exit: exit ?? this.exit,
      output: output ?? this.output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageShell &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.shellID == shellID &&
          other.command == command &&
          other.status == status &&
          const DeepCollectionEquality().equals(other.exit, exit) &&
          other.output == output);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, shellID, command, status, const DeepCollectionEquality().hash(exit), output);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageShellTime time;
  final String shellID;
  final String command;
  final SessionMessageShellStatus status;
  final Object? exit;
  final SessionMessageShellOutput? output;
}

@immutable
class SessionMessageShellTime {
  const SessionMessageShellTime({
    required this.created,
    required this.completed,
  });

  factory SessionMessageShellTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageShellTime(
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
  SessionMessageShellTime copyWith({
    double? created,
    double? completed,
  }) {
    return SessionMessageShellTime(
      created: created ?? this.created,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageShellTime &&
          other.created == created &&
          other.completed == completed);

  @override
  int get hashCode => Object.hash(created, completed);

  final double created;
  final double? completed;
}

@immutable
class SessionMessageShellOutput {
  const SessionMessageShellOutput({
    required this.output,
    required this.cursor,
    required this.size,
    required this.truncated,
  });

  factory SessionMessageShellOutput.fromJson(Map<String, dynamic> json) {
    return SessionMessageShellOutput(
      output: json["output"] as String,
      cursor: (json["cursor"] as num).toInt(),
      size: (json["size"] as num).toInt(),
      truncated: json["truncated"] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "output": output,
      "cursor": cursor,
      "size": size,
      "truncated": truncated,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageShellOutput copyWith({
    String? output,
    int? cursor,
    int? size,
    bool? truncated,
  }) {
    return SessionMessageShellOutput(
      output: output ?? this.output,
      cursor: cursor ?? this.cursor,
      size: size ?? this.size,
      truncated: truncated ?? this.truncated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageShellOutput &&
          other.output == output &&
          other.cursor == cursor &&
          other.size == size &&
          other.truncated == truncated);

  @override
  int get hashCode => Object.hash(output, cursor, size, truncated);

  final String output;
  final int cursor;
  final int size;
  final bool truncated;
}

enum SessionMessageShellStatus {
  @JsonValue("running")
  running,
  @JsonValue("exited")
  exited,
  @JsonValue("timeout")
  timeout,
  @JsonValue("killed")
  killed,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static SessionMessageShellStatus fromJson(String value) {
    switch (value) {
      case "running":
        return SessionMessageShellStatus.running;
      case "exited":
        return SessionMessageShellStatus.exited;
      case "timeout":
        return SessionMessageShellStatus.timeout;
      case "killed":
        return SessionMessageShellStatus.killed;
      default:
        return SessionMessageShellStatus.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case SessionMessageShellStatus.running:
        return "running";
      case SessionMessageShellStatus.exited:
        return "exited";
      case SessionMessageShellStatus.timeout:
        return "timeout";
      case SessionMessageShellStatus.killed:
        return "killed";
      case SessionMessageShellStatus.unknown:
        return 'unknown';
    }
  }
}
