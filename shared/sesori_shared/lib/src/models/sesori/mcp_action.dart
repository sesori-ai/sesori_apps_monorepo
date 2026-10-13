import "package:freezed_annotation/freezed_annotation.dart";

import "mcp.dart";

part "mcp_action.freezed.dart";
part "mcp_action.g.dart";

/// Server controls and future connector setup remain distinct target variants.
@Freezed(unionKey: "type", copyWith: false, fromJson: true, toJson: true)
sealed class McpEntryAction with _$McpEntryAction {
  const factory server({
    @JsonKey(fromJson: McpEntryTarget.serverFromJson) required McpServerTarget target,
    required McpServerAction action,
  }) = McpServerEntryAction;

  factory fromJson(Map<String, dynamic> json) => _$McpEntryActionFromJson(json);
}

@Freezed(copyWith: false, fromJson: true, toJson: true)
sealed class McpEntryActionRequest with _$McpEntryActionRequest {
  const factory({required String pluginId, required McpEntryAction action}) = _McpEntryActionRequest;

  factory fromJson(Map<String, dynamic> json) => _$McpEntryActionRequestFromJson(json);
}

enum McpActionUnavailableReason() {
  unknown,
  unsupportedHarness,
  unsupportedScope,
  liveSessionRequired,
  pluginInactive,
  targetNotFound,
}

@Freezed(unionKey: "type", fallbackUnion: "unknown", copyWith: false, fromJson: true, toJson: true)
sealed class McpEntryActionResult with _$McpEntryActionResult {
  const factory unknown() = McpActionUnknown;

  /// The native control completed; connection/discovery truth comes from this read.
  const factory completed({required McpInventoryResult inventory}) = McpActionCompleted;
  const factory unavailable({
    @JsonKey(unknownEnumValue: McpActionUnavailableReason.unknown) required McpActionUnavailableReason reason,
  }) = McpActionUnavailable;
  const factory failed() = McpActionFailed;

  factory fromJson(Map<String, dynamic> json) => _$McpEntryActionResultFromJson(json);
}
