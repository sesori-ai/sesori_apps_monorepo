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
