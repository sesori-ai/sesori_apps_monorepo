import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_pending_permission.freezed.dart";

part "plugin_pending_permission.g.dart";

@freezed
sealed class PluginPendingPermission with _$PluginPendingPermission {
  const factory PluginPendingPermission({
    required String id,
    required String sessionID,
    /// Top-most root session this request should be surfaced under (for a
    /// child/sub-agent session's request). Null when unknown.
    required String? displaySessionId,
    required String tool,
    required String description,
  }) = _PluginPendingPermission;
}
