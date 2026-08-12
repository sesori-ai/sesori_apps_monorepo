import "package:meta/meta.dart";

@immutable
class const NotificationOpenRequest({
    required this.projectId,
    required this.sessionId,
    required this.sessionTitle,
  }) {
  final String projectId;
  final String sessionId;
  final String? sessionTitle;
}
