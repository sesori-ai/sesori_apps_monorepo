import "package:meta/meta.dart";

@immutable
class const PushNotificationMessage({
    required this.data,
    required this.title,
    required this.body,
  }) {
  // ignore: no_slop_linter/prefer_specific_type
  final Map<String, dynamic> data;
  final String? title;
  final String? body;
}
