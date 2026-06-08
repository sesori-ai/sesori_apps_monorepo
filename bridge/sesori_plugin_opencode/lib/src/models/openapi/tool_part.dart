// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.974823Z

import 'package:meta/meta.dart';
import 'part.dart';
import 'tool_state.dart';

@immutable
class ToolPart implements Part {
  const ToolPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.callID,
    required this.tool,
    required this.state,
    this.metadata,
  });

  factory ToolPart.fromJson(Map<String, dynamic> json) {
    return ToolPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      callID: json["callID"] as String,
      tool: json["tool"] as String,
      state: ToolState.fromJson(json["state"] as Object),
      metadata: json["metadata"] as Map<String, dynamic>?,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "tool",
      "callID": callID,
      "tool": tool,
      "state": state.toJson(),
      "metadata": ?metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.callID == callID &&
          other.tool == tool &&
          other.state == state &&
          other.metadata == metadata);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, callID, tool, state, metadata);

  final String id;
  final String sessionID;
  final String messageID;
  final String callID;
  final String tool;
  final ToolState state;
  final Map<String, dynamic>? metadata;
}
