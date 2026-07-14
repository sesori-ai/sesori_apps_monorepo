import "package:freezed_annotation/freezed_annotation.dart";

import "plugin_identity.dart";

part "plugin_project_id_request.freezed.dart";

part "plugin_project_id_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class PluginProjectIdRequest with _$PluginProjectIdRequest {
  const factory PluginProjectIdRequest({
    required String projectId,
    // COMPATIBILITY 2026-07-13 (v1.5.0): Old project requests omit pluginId and mean OpenCode. Remove default; require it.
    @Default(legacyMissingPluginId) String pluginId,
  }) = _PluginProjectIdRequest;

  factory PluginProjectIdRequest.fromJson(Map<String, dynamic> json) => _$PluginProjectIdRequestFromJson(json);
}
