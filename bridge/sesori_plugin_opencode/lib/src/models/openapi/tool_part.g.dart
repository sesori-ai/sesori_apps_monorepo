// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'part.g.dart';
import 'tool_state.g.dart';

@immutable
class ToolPart implements Part {
  const ToolPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.callID,
    required this.tool,
    required this.state,
    required this.metadata,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ToolPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    String? callID,
    String? tool,
    ToolState? state,
    Map<String, dynamic>? metadata,
  }) {
    return ToolPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      callID: callID ?? this.callID,
      tool: tool ?? this.tool,
      state: state ?? this.state,
      metadata: metadata ?? this.metadata,
    );
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
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, callID, tool, state, const DeepCollectionEquality().hash(metadata));

  final String id;
  final String sessionID;
  final String messageID;
  final String callID;
  final String tool;
  final ToolState state;
  final Map<String, dynamic>? metadata;
}
