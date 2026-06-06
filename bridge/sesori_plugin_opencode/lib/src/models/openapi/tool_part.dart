// GENERATED FILE - DO NOT EDIT BY HAND

import 'part.dart';
import 'tool_state.dart';

class ToolPart implements Part {
  const ToolPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.type,
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
      type: json["type"] as String,
      callID: json["callID"] as String,
      tool: json["tool"] as String,
      state: ToolState.fromJson(json["state"]),
      metadata: json["metadata"] as Map<String, dynamic>?,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": type,
      "callID": callID,
      "tool": tool,
      "state": state.toJson(),
      "metadata": metadata,
    };
  }

  final String id;
  final String sessionID;
  final String messageID;
  final String type;
  final String callID;
  final String tool;
  final ToolState state;
  final Map<String, dynamic>? metadata;
}
