// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.938169Z

import 'package:meta/meta.dart';

@immutable
class InvalidCursorError {
  const InvalidCursorError({
    required this.tag,
    required this.message,
  });

  factory InvalidCursorError.fromJson(Map<String, dynamic> json) {
    return InvalidCursorError(
      tag: json["_tag"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvalidCursorError &&
          other.tag == tag &&
          other.message == message);

  @override
  int get hashCode => Object.hash(tag, message);

  final String tag;
  final String message;
}
