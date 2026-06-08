// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.075250Z

import 'session_v2_info.dart';

class V2SessionsResponse {
  const V2SessionsResponse({
    required this.data,
    required this.cursor,
  });

  factory V2SessionsResponse.fromJson(Map<String, dynamic> json) {
    return V2SessionsResponse(
      data: (json["data"] as List<dynamic>).map((e) => SessionV2Info.fromJson(e as Map<String, dynamic>)).toList(),
      cursor: json["cursor"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "data": data.map((e) => e.toJson()).toList(),
      "cursor": cursor,
    };
  }

  final List<SessionV2Info> data;
  final Map<String, dynamic> cursor;
}
