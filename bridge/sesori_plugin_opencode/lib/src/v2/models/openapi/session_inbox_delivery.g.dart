// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

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
