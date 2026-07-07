import "package:freezed_annotation/freezed_annotation.dart";

part "mark_session_seen_request.freezed.dart";

part "mark_session_seen_request.g.dart";

/// Request body for `POST /session/seen`.
///
/// Explicit user-driven "Mark as Read" ([read] == true) / "Mark as Unread"
/// ([read] == false) action on a session.
@Freezed(fromJson: true, toJson: true)
sealed class MarkSessionSeenRequest with _$MarkSessionSeenRequest {
  const factory MarkSessionSeenRequest({
    required String sessionId,
    required bool read,
  }) = _MarkSessionSeenRequest;

  factory MarkSessionSeenRequest.fromJson(Map<String, dynamic> json) => _$MarkSessionSeenRequestFromJson(json);
}
