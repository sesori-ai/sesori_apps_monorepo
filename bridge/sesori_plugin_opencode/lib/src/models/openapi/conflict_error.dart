// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.917499Z

import 'package:meta/meta.dart';

@immutable
class ConflictError {
  const ConflictError({
    required this.tag,
    required this.message,
    this.resource,
  });

  factory ConflictError.fromJson(Map<String, dynamic> json) {
    return ConflictError(
      tag: json["_tag"] as String,
      message: json["message"] as String,
      resource: json["resource"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
      "resource": ?resource,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConflictError &&
          other.tag == tag &&
          other.message == message &&
          other.resource == resource);

  @override
  int get hashCode => Object.hash(tag, message, resource);

  final String tag;
  final String message;
  final String? resource;
}
