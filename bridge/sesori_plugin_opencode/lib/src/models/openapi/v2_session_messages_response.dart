// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.931116Z

import 'session_message.dart';

class V2SessionMessagesResponse {
  const V2SessionMessagesResponse({
    required this.data,
    required this.cursor,
  });

  factory V2SessionMessagesResponse.fromJson(Map<String, dynamic> json) {
    return V2SessionMessagesResponse(
      data: (json["data"] as List<dynamic>).map((e) => SessionMessage.fromJson(e as Map<String, dynamic>)).toList(),
      cursor: json["cursor"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "data": data.map((e) => e.toJson()).toList(),
      "cursor": cursor,
    };
  }

  final List<SessionMessage> data;
  final Map<String, dynamic> cursor;
}
