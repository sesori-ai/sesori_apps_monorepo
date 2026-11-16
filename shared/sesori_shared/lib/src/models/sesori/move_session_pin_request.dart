import "package:freezed_annotation/freezed_annotation.dart";

import "session.dart";

part "move_session_pin_request.freezed.dart";
part "move_session_pin_request.g.dart";

/// Request body for `PATCH /session/pin-position`: places the pinned session
/// [sessionId] directly below the pinned session [afterSessionId] in the
/// pinned group, or at its top when [afterSessionId] is null.
@Freezed(fromJson: true, toJson: true)
sealed class MoveSessionPinRequest with _$MoveSessionPinRequest {
  const factory({
    required String sessionId,
    required String? afterSessionId,
  }) = _MoveSessionPinRequest;

  factory fromJson(Map<String, dynamic> json) => _$MoveSessionPinRequestFromJson(json);
}

/// Response from `PATCH /session/pin-position`: every session whose
/// [Session.pinOrder] the move rewrote, top of the group first. Empty when the
/// session already stood there.
@Freezed(fromJson: true, toJson: true)
sealed class MoveSessionPinResponse with _$MoveSessionPinResponse {
  const factory({
    required List<Session> sessions,
  }) = _MoveSessionPinResponse;

  factory fromJson(Map<String, dynamic> json) => _$MoveSessionPinResponseFromJson(json);
}
