// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';
import 'session_inbox_compaction_payload.g.dart';
import 'session_inbox_delivery.g.dart';
import 'session_inbox_info.g.dart';

@immutable
class SessionInboxCompaction implements SessionInboxInfo {
  const SessionInboxCompaction({
    required this.id,
    required this.sessionID,
    required this.time,
    required this.payload,
    required this.delivery,
  });

  factory SessionInboxCompaction.fromJson(Map<String, dynamic> json) {
    return SessionInboxCompaction(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      time: SessionInboxCompactionTime.fromJson(json["time"] as Map<String, dynamic>),
      payload: SessionInboxCompactionPayload.fromJson(json["payload"] as Object),
      delivery: SessionInboxDelivery.fromJson(json["delivery"] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "time": time.toJson(),
      "type": "compaction",
      "payload": payload.toJson(),
      "delivery": delivery.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionInboxCompaction copyWith({
    String? id,
    String? sessionID,
    SessionInboxCompactionTime? time,
    SessionInboxCompactionPayload? payload,
    SessionInboxDelivery? delivery,
  }) {
    return SessionInboxCompaction(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      time: time ?? this.time,
      payload: payload ?? this.payload,
      delivery: delivery ?? this.delivery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInboxCompaction &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.time == time &&
          other.payload == payload &&
          other.delivery == delivery);

  @override
  int get hashCode => Object.hash(id, sessionID, time, payload, delivery);

  final String id;
  final String sessionID;
  final SessionInboxCompactionTime time;
  final SessionInboxCompactionPayload payload;
  final SessionInboxDelivery delivery;
}

@immutable
class SessionInboxCompactionTime {
  const SessionInboxCompactionTime({
    required this.created,
  });

  factory SessionInboxCompactionTime.fromJson(Map<String, dynamic> json) {
    return SessionInboxCompactionTime(
      created: (json["created"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionInboxCompactionTime copyWith({
    double? created,
  }) {
    return SessionInboxCompactionTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInboxCompactionTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
