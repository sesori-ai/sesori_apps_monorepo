// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'apierror.g.dart';
import 'part.g.dart';

@immutable
class RetryPart implements Part {
  const RetryPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.attempt,
    required this.error,
    required this.time,
  });

  factory RetryPart.fromJson(Map<String, dynamic> json) {
    return RetryPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      attempt: (json["attempt"] as num).toInt(),
      error: APIError.fromJson(json["error"] as Map<String, dynamic>),
      time: RetryPartTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "retry",
      "attempt": attempt,
      "error": error.toJson(),
      "time": time.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  RetryPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    int? attempt,
    APIError? error,
    RetryPartTime? time,
  }) {
    return RetryPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      attempt: attempt ?? this.attempt,
      error: error ?? this.error,
      time: time ?? this.time,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RetryPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.attempt == attempt &&
          other.error == error &&
          other.time == time);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, attempt, error, time);

  final String id;
  final String sessionID;
  final String messageID;
  final int attempt;
  final APIError error;
  final RetryPartTime time;
}

@immutable
class RetryPartTime {
  const RetryPartTime({
    required this.created,
  });

  factory RetryPartTime.fromJson(Map<String, dynamic> json) {
    return RetryPartTime(
      created: (json["created"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  RetryPartTime copyWith({
    int? created,
  }) {
    return RetryPartTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RetryPartTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final int created;
}
