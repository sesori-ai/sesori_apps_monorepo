import "package:meta/meta.dart";

@immutable
class const NotificationOpenRequest({
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
});
