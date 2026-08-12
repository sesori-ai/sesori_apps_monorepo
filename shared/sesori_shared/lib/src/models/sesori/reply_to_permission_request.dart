import "package:freezed_annotation/freezed_annotation.dart";

import "permission_reply.dart";

part "reply_to_permission_request.freezed.dart";

part "reply_to_permission_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class ReplyToPermissionRequest with _$ReplyToPermissionRequest {
  const factory({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) = _ReplyToPermissionRequest;

  factory fromJson(Map<String, dynamic> json) => _$ReplyToPermissionRequestFromJson(json);
}
