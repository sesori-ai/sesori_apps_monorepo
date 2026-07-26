import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_list_response.freezed.dart";
part "plugin_list_response.g.dart";

enum PluginLifecycleState {
  unavailable,
  ready,
  degraded,
  failed,
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginMetadata with _$PluginMetadata {
  const factory PluginMetadata({
    required String id,
    required String displayName,
    required bool isDefault,
    @JsonKey(unknownEnumValue: PluginLifecycleState.unavailable) required PluginLifecycleState state,
    required String? actionHint,
  }) = _PluginMetadata;

  factory PluginMetadata.fromJson(Map<String, dynamic> json) => _$PluginMetadataFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginListResponse with _$PluginListResponse {
  const factory PluginListResponse({
    required List<PluginMetadata> plugins,
    // COMPATIBILITY 2026-07-26 (v1.7.0): Bridges predating per-bridge harness
    // preferences omit the ID; null disables preference recall. Remove the
    // nullable path once those bridges are unsupported.
    required String? bridgeId,
  }) = _PluginListResponse;

  factory PluginListResponse.fromJson(Map<String, dynamic> json) => _$PluginListResponseFromJson(json);
}
