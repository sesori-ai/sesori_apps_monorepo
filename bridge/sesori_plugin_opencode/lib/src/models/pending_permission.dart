import "package:freezed_annotation/freezed_annotation.dart";

part "pending_permission.freezed.dart";
part "pending_permission.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class PendingPermission with _$PendingPermission {
  const factory PendingPermission({
    required String id,
    required String sessionID,
    required String permission,
  }) = _PendingPermission;
  factory PendingPermission.fromJson(Map<String, dynamic> json) => _$PendingPermissionFromJson(json);
}
