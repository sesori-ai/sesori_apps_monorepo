// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.911313Z


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

  final String type;
  final String messageID;
  final String callID;
}
