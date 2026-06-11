// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
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
      cursor: V2SessionsResponseCursor.fromJson(json["cursor"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "data": data.map((e) => e.toJson()).toList(),
      "cursor": cursor.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is V2SessionsResponse &&
          const DeepCollectionEquality().equals(other.data, data) &&
          other.cursor == cursor);

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(data), cursor);

  final List<SessionV2Info> data;
  final V2SessionsResponseCursor cursor;
}

@immutable
class V2SessionsResponseCursor {
  const V2SessionsResponseCursor({
    this.previous,
    this.next,
  });

  factory V2SessionsResponseCursor.fromJson(Map<String, dynamic> json) {
    return V2SessionsResponseCursor(
      previous: json["previous"] as String?,
      next: json["next"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "previous": ?previous,
      "next": ?next,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is V2SessionsResponseCursor &&
          other.previous == previous &&
          other.next == next);

  @override
  int get hashCode => Object.hash(previous, next);

  final String? previous;
  final String? next;
}
