import "package:freezed_annotation/freezed_annotation.dart";

part "mark_session_seen_request.freezed.dart";

part "mark_session_seen_request.g.dart";

/// Request body for `POST /session/seen`.
///
/// Explicit user-driven "Mark as Read" ([read] == true) / "Mark as Unread"
/// ([read] == false) action on a session.
///
/// [projectId] lets the bridge emit an authoritative clearing event when the
/// target session no longer has a row (deleted / missed refresh), so clients
/// can settle the project aggregate instead of being left with a stale bold.
/// Nullable for backwards compatibility with older clients that omit it.
@Freezed(fromJson: true, toJson: true)
sealed class MarkSessionSeenRequest with _$MarkSessionSeenRequest {
  const factory MarkSessionSeenRequest({
    required String sessionId,
    required bool read,
    required String? projectId,
  }) = _MarkSessionSeenRequest;

  factory MarkSessionSeenRequest.fromJson(Map<String, dynamic> json) => _$MarkSessionSeenRequestFromJson(json);
}
