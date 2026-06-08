// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.949832Z

import 'package:meta/meta.dart';

@immutable
class PermissionV2Source {
  const PermissionV2Source({
    required this.type,
    required this.messageID,
    required this.callID,
  });

  factory PermissionV2Source.fromJson(Map<String, dynamic> json) {
    return PermissionV2Source(
      type: json["type"] as String,
      messageID: json["messageID"] as String,
      callID: json["callID"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "messageID": messageID,
      "callID": callID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionV2Source &&
          other.type == type &&
          other.messageID == messageID &&
          other.callID == callID);

  @override
  int get hashCode => Object.hash(type, messageID, callID);

  final String type;
  final String messageID;
  final String callID;
}
