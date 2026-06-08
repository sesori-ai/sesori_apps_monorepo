// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:08.007589Z

import 'package:meta/meta.dart';
import 'session_v2_info.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is V2SessionsResponse &&
          other.data == data &&
          other.cursor == cursor);

  @override
  int get hashCode => Object.hash(data, cursor);

  final List<SessionV2Info> data;
  final Map<String, dynamic> cursor;
}
