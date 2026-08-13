import "package:freezed_annotation/freezed_annotation.dart";

part "notification_data.freezed.dart";

part "notification_data.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class NotificationData with _$NotificationData {
  const factory({
    @JsonKey(unknownEnumValue: NotificationCategory.unknown) required NotificationCategory category,
    @JsonKey(unknownEnumValue: NotificationEventType.unknown) required NotificationEventType? eventType,
    required String? sessionId,
    required String? projectId,
  }) = _NotificationData;

  factory fromJson(Map<String, dynamic> json) => _$NotificationDataFromJson(json);
}

enum NotificationCategory({
    required final String id,
    required final String displayName,
    required final String description,
    required final NotificationImportance importance,
  }) {
  @JsonValue("ai_interaction")
  aiInteraction(
    id: "ai_interaction",
    displayName: "AI Interactions",
    description: "Questions and permissions from AI",
    importance: .max,
  ),
  @JsonValue("session_message")
  sessionMessage(
    id: "session_message",
    displayName: "Session Messages",
    description: "New messages from AI sessions",
    importance: .max,
  ),
  @JsonValue("connection_status")
  connectionStatus(
    id: "connection_status",
    displayName: "Connection Status",
    description: "Bridge connection status changes",
    importance: .max,
  ),
  @JsonValue("system_update")
  systemUpdate(
    id: "system_update",
    displayName: "System Updates",
    description: "App and bridge updates",
    importance: .defaultImportance,
  ),
  // Permanent forward-compatible fallback for categories added by newer peers.
  @JsonValue("unknown")
  unknown(
    id: "unknown",
    displayName: "Sesori Notifications",
    description: "Notifications from the Sesori app",
    importance: .defaultImportance,
  ),
  ;

}

enum NotificationEventType() {
  @JsonValue("question_asked")
  questionAsked,
  @JsonValue("permission_asked")
  permissionAsked,
  @JsonValue("installation_update_available")
  installationUpdateAvailable,
  @JsonValue("agent_turn_completed")
  agentTurnCompleted,
  // Permanent forward-compatible fallback for event types added by newer peers.
  @JsonValue("unknown")
  unknown,
}

enum NotificationImportance() {
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
