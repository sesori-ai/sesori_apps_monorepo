// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class PermissionNotFoundError {
  const PermissionNotFoundError({
    required this.tag,
    required this.requestID,
    required this.message,
  });

  factory PermissionNotFoundError.fromJson(Map<String, dynamic> json) {
    return PermissionNotFoundError(
      tag: json["_tag"] as String,
      requestID: json["requestID"] as String,
      message: json["message"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "requestID": requestID,
      "message": message,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionNotFoundError &&
          other.tag == tag &&
          other.requestID == requestID &&
          other.message == message);

  @override
  int get hashCode => Object.hash(tag, requestID, message);

  final String tag;
  final String requestID;
  final String message;
}
