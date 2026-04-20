import "package:meta/meta.dart";

@immutable
class NotificationOpenRequest {
  final String projectId;
  final String sessionId;
  final String? sessionTitle;

  const NotificationOpenRequest({
    required this.projectId,
    required this.sessionId,
    required this.sessionTitle,
  });
}
