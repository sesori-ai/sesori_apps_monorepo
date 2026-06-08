// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.992543Z

import 'package:meta/meta.dart';
import 'session_message.dart';

@immutable
class SessionMessageShell implements SessionMessage {
  const SessionMessageShell({
    required this.id,
    this.metadata,
    required this.time,
    required this.callID,
    required this.command,
    required this.output,
  });

  factory SessionMessageShell.fromJson(Map<String, dynamic> json) {
    return SessionMessageShell(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      callID: json["callID"] as String,
      command: json["command"] as String,
      output: json["output"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time,
      "type": "shell",
      "callID": callID,
      "command": command,
      "output": output,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageShell &&
          other.id == id &&
          other.metadata == metadata &&
          other.time == time &&
          other.callID == callID &&
          other.command == command &&
          other.output == output);

  @override
  int get hashCode => Object.hash(id, metadata, time, callID, command, output);

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final String callID;
  final String command;
  final String output;
}
