// GENERATED FILE - DO NOT EDIT BY HAND

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
      "data": data,
      "cursor": cursor,
    };
  }

  final List<SessionMessage> data;
  final Map<String, dynamic> cursor;
}
