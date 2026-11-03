import "package:meta/meta.dart";

@immutable
class const PushNotificationMessage({
  required final Map<String, dynamic> data,
  required final String? title,
  required final String? body,
});
