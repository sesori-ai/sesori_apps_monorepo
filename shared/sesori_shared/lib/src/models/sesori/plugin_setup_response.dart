import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_setup_response.freezed.dart";
part "plugin_setup_response.g.dart";

enum PluginSetupState() {
  notInspected,
  ready,
  runtimeMissing,
  authenticationRequired,
  unavailable,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginSetupMetadata with _$PluginSetupMetadata {
  const factory({
    required String id,
    required String displayName,
    @JsonKey(unknownEnumValue: PluginSetupState.unknown) required PluginSetupState state,
    // COMPATIBILITY 2026-08-17 (v1.8.0): Older bridge payloads omit
    // runtimeVersion; null means that peer did not report the selected harness
    // runtime. Remove the nullable fallback when those bridges are unsupported.
    required String? runtimeVersion,
    required String? actionHint,
  }) = _PluginSetupMetadata;

  factory fromJson(Map<String, dynamic> json) => _$PluginSetupMetadataFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginSetupResponse with _$PluginSetupResponse {
  const factory({
    required List<PluginSetupMetadata> plugins,
  }) = _PluginSetupResponse;

  factory fromJson(Map<String, dynamic> json) => _$PluginSetupResponseFromJson(json);
}
