// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.953885Z

import 'package:meta/meta.dart';

@immutable
class PtyForbiddenError {
  const PtyForbiddenError({
    required this.tag,
    required this.message,
  });

  factory PtyForbiddenError.fromJson(Map<String, dynamic> json) {
    return PtyForbiddenError(
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
      (other is PtyForbiddenError &&
          other.tag == tag &&
          other.message == message);

  @override
  int get hashCode => Object.hash(tag, message);

  final String tag;
  final String message;
}
