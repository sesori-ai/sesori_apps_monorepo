import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_permission_details.freezed.dart";
part "plugin_permission_details.g.dart";

/// Authoritative request details normalized by the owning backend plugin.
/// Generic requests retain their existing tool and Markdown description.
@freezed
sealed class PluginPermissionDetails with _$PluginPermissionDetails {
  const factory generic() = PluginGenericPermissionDetails;
  const factory command({required String command}) = PluginCommandPermissionDetails;
  const factory fileChanges({required List<PluginPermissionFile> files}) = PluginFileChangesPermissionDetails;
  const factory network({required List<String> targets, required String? command}) = PluginNetworkPermissionDetails;
}

enum PluginPermissionFileOperation() {
  create,
  write,
  delete,
}

@freezed
sealed class PluginPermissionFile with _$PluginPermissionFile {
  const factory({
    required String path,
    required PluginPermissionFileOperation? operation,
  }) = _PluginPermissionFile;
}
