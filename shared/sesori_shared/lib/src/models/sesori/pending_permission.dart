import "package:freezed_annotation/freezed_annotation.dart";

part "pending_permission.freezed.dart";

part "pending_permission.g.dart";

/// Response body for `GET /permission`.
@Freezed(fromJson: true, toJson: true)
sealed class PendingPermissionResponse with _$PendingPermissionResponse {
  const factory PendingPermissionResponse({
    required List<PendingPermission> data,
  }) = _PendingPermissionResponse;

  factory PendingPermissionResponse.fromJson(Map<String, dynamic> json) =>
      _$PendingPermissionResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PendingPermission with _$PendingPermission {
  const factory PendingPermission({
    required String id,
    required String sessionID,
    /// Top-most root session this request should be surfaced under (for a
    /// child/sub-agent session's request). Null when unknown; consumers fall
    /// back to [sessionID].
    @JsonKey(includeIfNull: false)
    required String? displaySessionId,
    required String tool,
    required String description,
  }) = _PendingPermission;

  factory PendingPermission.fromJson(Map<String, dynamic> json) => _$PendingPermissionFromJson(json);
}
