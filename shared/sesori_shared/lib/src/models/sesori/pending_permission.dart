import "package:freezed_annotation/freezed_annotation.dart";

part "pending_permission.freezed.dart";

part "pending_permission.g.dart";

/// Response body for `GET /permission`.
@Freezed(fromJson: true, toJson: true)
sealed class PendingPermissionResponse with _$PendingPermissionResponse {
  const factory({
    required List<PendingPermission> data,
  }) = _PendingPermissionResponse;

  factory fromJson(Map<String, dynamic> json) => _$PendingPermissionResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PendingPermission with _$PendingPermission {
  const factory({
    required String id,
    required String sessionID,

    /// Top-most root session this request should be surfaced under (for a
    /// child/sub-agent session's request). Null when unknown; consumers fall
    /// back to [sessionID].
    required String? displaySessionId,
    required String tool,
    required String description,
    // COMPATIBILITY 2026-08-10 (v1.8.0): Older bridges omit this capability;
    // remove the default after the minimum supported bridge sends it.
    @Default(true) bool allowAlways,
  }) = _PendingPermission;

  factory fromJson(Map<String, dynamic> json) => _$PendingPermissionFromJson(json);
}
