import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_list_response.freezed.dart";
part "plugin_list_response.g.dart";

enum PluginLifecycleState() {
  unavailable,
  ready,
  degraded,
  failed,
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginMetadata with _$PluginMetadata {
  const factory({
    required String id,
    required String displayName,
    required bool isDefault,
    @JsonKey(unknownEnumValue: PluginLifecycleState.unavailable) required PluginLifecycleState state,
    required String? actionHint,
    // COMPATIBILITY 2026-08-04 (v1.8.0): Older bridges omit this
    // per-plugin capability. Unknown plugins stay disabled; the client
    // repository narrowly restores released legacy OpenCode support from the
    // enclosing response's legacy capability signal. Remove @Default and that
    // mapping once those bridges are unsupported.
    @Default(false) bool supportsPromptAttachments,
  }) = _PluginMetadata;

  factory fromJson(Map<String, dynamic> json) => _$PluginMetadataFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginListResponse with _$PluginListResponse {
  const factory({
    required List<PluginMetadata> plugins,
    // COMPATIBILITY 2026-07-26 (v1.7.0): Bridges predating per-bridge harness
    // preferences omit the ID; null disables preference recall. Remove the
    // nullable path once those bridges are unsupported.
    required String? bridgeId,
    // COMPATIBILITY 2026-07-30 (v1.8.0): Old bridges omit this capability,
    // which means session options are unsupported. Remove @Default and require
    // supportsSessionOptions once those bridges are unsupported.
    @Default(false) bool supportsSessionOptions,

    /// Whether the bridge saves prompt files that it doesn't pass to the
    /// plugin inline, and gives the agent their paths (see
    /// `PromptPart.fileData`).
    // COMPATIBILITY 2026-11-08 (v1.12.0): Bridges before file uploads omit this, so
    // only images reach them and the client says so. Remove @Default and require
    // supportsFileUploads once those bridges are unsupported.
    @Default(false) bool supportsFileUploads,
  }) = _PluginListResponse;

  factory fromJson(Map<String, dynamic> json) => _$PluginListResponseFromJson(json);
}
