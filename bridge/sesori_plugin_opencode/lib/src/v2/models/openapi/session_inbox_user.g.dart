// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'session_inbox_delivery.g.dart';
import 'session_inbox_info.g.dart';
import 'session_inbox_user_payload.g.dart';

@immutable
class SessionInboxUser implements SessionInboxInfo {
  const SessionInboxUser({
    required this.id,
    required this.sessionID,
    required this.time,
    required this.payload,
    required this.delivery,
  });

  factory SessionInboxUser.fromJson(Map<String, dynamic> json) {
    return SessionInboxUser(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      time: SessionInboxUserTime.fromJson(json["time"] as Map<String, dynamic>),
      payload: SessionInboxUserPayload.fromJson(json["payload"] as Map<String, dynamic>),
      delivery: SessionInboxDelivery.fromJson(json["delivery"] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "time": time.toJson(),
      "type": "user",
      "payload": payload.toJson(),
      "delivery": delivery.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionInboxUser copyWith({
    String? id,
    String? sessionID,
    SessionInboxUserTime? time,
    SessionInboxUserPayload? payload,
    SessionInboxDelivery? delivery,
  }) {
    return SessionInboxUser(
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
      (other is SessionInboxUser &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.time == time &&
          other.payload == payload &&
          other.delivery == delivery);

  @override
  int get hashCode => Object.hash(id, sessionID, time, payload, delivery);

  final String id;
  final String sessionID;
  final SessionInboxUserTime time;
  final SessionInboxUserPayload payload;
  final SessionInboxDelivery delivery;
}

@immutable
class SessionInboxUserTime {
  const SessionInboxUserTime({
    required this.created,
  });

  factory SessionInboxUserTime.fromJson(Map<String, dynamic> json) {
    return SessionInboxUserTime(
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
  SessionInboxUserTime copyWith({
    double? created,
  }) {
    return SessionInboxUserTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInboxUserTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
