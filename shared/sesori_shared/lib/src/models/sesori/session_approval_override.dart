import "package:freezed_annotation/freezed_annotation.dart";

part "session_approval_override.freezed.dart";
part "session_approval_override.g.dart";

/// How the bridge answers a session's permission requests.
enum SessionApprovalMode() {
  /// Every permission request waits for the user.
  ask,

  /// The bridge approves every permission request once (YOLO).
  yolo,
}

/// Request body for `PATCH /session/approval-override`.
///
/// A null [approvalOverride] clears the session's override, so the session
/// follows the bridge-wide YOLO setting again.
@Freezed(fromJson: true, toJson: true)
sealed class SetSessionApprovalOverrideRequest with _$SetSessionApprovalOverrideRequest {
  const factory({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) = _SetSessionApprovalOverrideRequest;

  factory fromJson(Map<String, dynamic> json) => _$SetSessionApprovalOverrideRequestFromJson(json);
}

enum SessionApprovalOverrideErrorCode() {
  sessionNotFound,
  unknown,
}

/// The body of a failed `/session/approval-override` request. Its presence
/// tells a missing session apart from the bare 404 an older bridge returns for
/// the unknown route.
@Freezed(fromJson: true, toJson: true)
sealed class SessionApprovalOverrideErrorResponse with _$SessionApprovalOverrideErrorResponse {
  const factory({
    @JsonKey(unknownEnumValue: SessionApprovalOverrideErrorCode.unknown) required SessionApprovalOverrideErrorCode code,
  }) = _SessionApprovalOverrideErrorResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionApprovalOverrideErrorResponseFromJson(json);
}
