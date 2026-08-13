import "package:meta/meta.dart";

@immutable
class const PushNotificationMessage({
  // ignore: no_slop_linter/prefer_specific_type, notification payload values are heterogeneous
  required final Map<String, dynamic> data,
  required final String? title,
  required final String? body,
});
