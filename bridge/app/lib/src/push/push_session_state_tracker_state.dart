import "package:sesori_shared/sesori_shared.dart";

final class PushTrackedSessionState {
  String? parentId;
  String? projectId;
  String? title;
  SessionStatus? status;
  bool previouslyBusy = false;
  final Set<String> childIds = <String>{};
  final Set<String> messageIds = <String>{};
  String? latestAssistantText;
  bool hasPendingQuestion = false;
  bool hasPendingPermission = false;
  DateTime? lastTouchedAt;
}

final class PushTrackedMessageRole {
  final String role;
  final String sessionId;
  final DateTime updatedAt;

  const PushTrackedMessageRole({
    required this.role,
    required this.sessionId,
    required this.updatedAt,
  });
}
