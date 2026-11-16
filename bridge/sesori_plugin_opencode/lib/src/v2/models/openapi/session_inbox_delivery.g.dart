// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.0 (a6b15d33daf6ab7d35569f6d711fdb630b9f04e7)

import 'package:json_annotation/json_annotation.dart';

enum SessionInboxDelivery {
  @JsonValue("steer")
  steer,
  @JsonValue("queue")
  queue,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static SessionInboxDelivery fromJson(String value) {
    switch (value) {
      case "steer":
        return SessionInboxDelivery.steer;
      case "queue":
        return SessionInboxDelivery.queue;
      default:
        return SessionInboxDelivery.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case SessionInboxDelivery.steer:
        return "steer";
      case SessionInboxDelivery.queue:
        return "queue";
      case SessionInboxDelivery.unknown:
        return 'unknown';
    }
  }
}
