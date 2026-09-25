// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_info.g.dart';

@immutable
class SessionMessagesResponse {
  const SessionMessagesResponse({
    required this.data,
    required this.cursor,
  });

  factory SessionMessagesResponse.fromJson(Map<String, dynamic> json) {
    return SessionMessagesResponse(
      data: (json["data"] as List<dynamic>).map((e) => SessionMessageInfo.fromJson(e as Map<String, dynamic>)).toList(),
      cursor: SessionMessagesResponseCursor.fromJson(json["cursor"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "data": data.map((e) => e.toJson()).toList(),
      "cursor": cursor.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessagesResponse copyWith({
    List<SessionMessageInfo>? data,
    SessionMessagesResponseCursor? cursor,
  }) {
    return SessionMessagesResponse(
      data: data ?? this.data,
      cursor: cursor ?? this.cursor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessagesResponse &&
          const DeepCollectionEquality().equals(other.data, data) &&
          other.cursor == cursor);

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(data), cursor);

  final List<SessionMessageInfo> data;
  final SessionMessagesResponseCursor cursor;
}

@immutable
class SessionMessagesResponseCursor {
  const SessionMessagesResponseCursor({
    required this.previous,
    required this.next,
  });

  factory SessionMessagesResponseCursor.fromJson(Map<String, dynamic> json) {
    return SessionMessagesResponseCursor(
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessagesResponseCursor copyWith({
    String? previous,
    String? next,
  }) {
    return SessionMessagesResponseCursor(
      previous: previous ?? this.previous,
      next: next ?? this.next,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessagesResponseCursor &&
          other.previous == previous &&
          other.next == next);

  @override
  int get hashCode => Object.hash(previous, next);

  final String? previous;
  final String? next;
}
