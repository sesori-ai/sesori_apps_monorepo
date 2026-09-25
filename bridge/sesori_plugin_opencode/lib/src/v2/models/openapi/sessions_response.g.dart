// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_info.g.dart';

@immutable
class SessionsResponse {
  const SessionsResponse({
    required this.data,
    required this.cursor,
  });

  factory SessionsResponse.fromJson(Map<String, dynamic> json) {
    return SessionsResponse(
      data: (json["data"] as List<dynamic>).map((e) => SessionInfo.fromJson(e as Map<String, dynamic>)).toList(),
      cursor: SessionsResponseCursor.fromJson(json["cursor"] as Map<String, dynamic>),
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
  SessionsResponse copyWith({
    List<SessionInfo>? data,
    SessionsResponseCursor? cursor,
  }) {
    return SessionsResponse(
      data: data ?? this.data,
      cursor: cursor ?? this.cursor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionsResponse &&
          const DeepCollectionEquality().equals(other.data, data) &&
          other.cursor == cursor);

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(data), cursor);

  final List<SessionInfo> data;
  final SessionsResponseCursor cursor;
}

@immutable
class SessionsResponseCursor {
  const SessionsResponseCursor({
    required this.previous,
    required this.next,
  });

  factory SessionsResponseCursor.fromJson(Map<String, dynamic> json) {
    return SessionsResponseCursor(
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
  SessionsResponseCursor copyWith({
    String? previous,
    String? next,
  }) {
    return SessionsResponseCursor(
      previous: previous ?? this.previous,
      next: next ?? this.next,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionsResponseCursor &&
          other.previous == previous &&
          other.next == next);

  @override
  int get hashCode => Object.hash(previous, next);

  final String? previous;
  final String? next;
}
