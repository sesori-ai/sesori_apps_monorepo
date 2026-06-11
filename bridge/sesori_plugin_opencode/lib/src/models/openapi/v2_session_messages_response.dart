// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message.dart';

@immutable
class V2SessionMessagesResponse {
  const V2SessionMessagesResponse({
    required this.data,
    required this.cursor,
  });

  factory V2SessionMessagesResponse.fromJson(Map<String, dynamic> json) {
    return V2SessionMessagesResponse(
      data: (json["data"] as List<dynamic>).map((e) => SessionMessage.fromJson(e as Map<String, dynamic>)).toList(),
      cursor: V2SessionMessagesResponseCursor.fromJson(json["cursor"] as Map<String, dynamic>),
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
      (other is V2SessionMessagesResponse &&
          const DeepCollectionEquality().equals(other.data, data) &&
          other.cursor == cursor);

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(data), cursor);

  final List<SessionMessage> data;
  final V2SessionMessagesResponseCursor cursor;
}

@immutable
class V2SessionMessagesResponseCursor {
  const V2SessionMessagesResponseCursor({
    this.previous,
    this.next,
  });

  factory V2SessionMessagesResponseCursor.fromJson(Map<String, dynamic> json) {
    return V2SessionMessagesResponseCursor(
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
      (other is V2SessionMessagesResponseCursor &&
          other.previous == previous &&
          other.next == next);

  @override
  int get hashCode => Object.hash(previous, next);

  final String? previous;
  final String? next;
}
