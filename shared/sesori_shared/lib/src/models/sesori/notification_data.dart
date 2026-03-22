import "package:freezed_annotation/freezed_annotation.dart";

part "notification_data.freezed.dart";

part "notification_data.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class NotificationData with _$NotificationData {
  const factory NotificationData({
    @JsonKey(unknownEnumValue: NotificationCategory.unknown) required NotificationCategory category,
    @JsonKey(unknownEnumValue: NotificationEventType.unknown) required NotificationEventType? eventType,
    required String? sessionId,
  }) = _NotificationData;

  factory NotificationData.fromJson(Map<String, dynamic> json) => _$NotificationDataFromJson(json);
}

enum NotificationCategory {
  @JsonValue("ai_interaction")
  aiInteraction(
    id: "ai_interaction",
    displayName: "AI Interactions",
    description: "Questions and permissions from AI",
    importance: .high,
  ),
  @JsonValue("session_message")
  sessionMessage(
    id: "session_message",
    displayName: "Session Messages",
    description: "New messages from AI sessions",
    importance: .defaultImportance,
  ),
  @JsonValue("connection_status")
  connectionStatus(
    id: "connection_status",
    displayName: "Connection Status",
    description: "Bridge connection status changes",
    importance: .high,
  ),
  @JsonValue("system_update")
  systemUpdate(
    id: "system_update",
    displayName: "System Updates",
    description: "App and bridge updates",
    importance: .low,
  ),
  // fallback for unknown categories (for backwards compatibility)
  @JsonValue("unknown")
  unknown(
    id: "unknown",
    displayName: "Sesori Notifications",
    description: "Notifications from the Sesori app",
    importance: .unspecified,
  ),
  ;

  final String id;
  final String displayName;
  final String description;
  final NotificationImportance importance;

  const NotificationCategory({
    required this.id,
    required this.displayName,
    required this.description,
    required this.importance,
  });
}

enum NotificationEventType {
  @JsonValue("question_asked")
  questionAsked,
  @JsonValue("permission_asked")
  permissionAsked,
  @JsonValue("message_updated")
  messageUpdated,
  @JsonValue("installation_update_available")
  installationUpdateAvailable,
  // fallback for unknown event types (for backwards compatibility)
  @JsonValue("unknown")
  unknown,
}

enum NotificationImportance {
  @JsonValue("unspecified")
  unspecified(),
  @JsonValue("none")
  none(),
  @JsonValue("min")
  min(),
  @JsonValue("low")
  low(),
  @JsonValue("default")
  defaultImportance(),
  @JsonValue("high")
  high(),
  @JsonValue("max")
  max(),
}
