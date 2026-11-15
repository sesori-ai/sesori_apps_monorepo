import "package:freezed_annotation/freezed_annotation.dart";

part "set_session_pinned_request.freezed.dart";
part "set_session_pinned_request.g.dart";

/// Request body for `PATCH /session/pinned`.
///
/// Pinning applies only to an unarchived root session; unpinning applies to
/// any session.
@Freezed(fromJson: true, toJson: true)
sealed class SetSessionPinnedRequest with _$SetSessionPinnedRequest {
  const factory({
    required String sessionId,
    required bool pinned,
  }) = _SetSessionPinnedRequest;

  factory fromJson(Map<String, dynamic> json) => _$SetSessionPinnedRequestFromJson(json);
}
