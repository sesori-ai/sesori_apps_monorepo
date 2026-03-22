import "package:json_annotation/json_annotation.dart";

enum NotificationCategory {
  @JsonValue("ai_interaction")
  aiInteraction,
  @JsonValue("session_message")
  sessionMessage,
  @JsonValue("connection_status")
  connectionStatus,
  @JsonValue("system_update")
  systemUpdate,
}
