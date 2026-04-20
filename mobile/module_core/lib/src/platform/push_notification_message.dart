import "package:meta/meta.dart";

@immutable
class PushNotificationMessage {
  final Map<String, dynamic> data;
  final String? title;
  final String? body;

  const PushNotificationMessage({
    required this.data,
    required this.title,
    required this.body,
  });
}
