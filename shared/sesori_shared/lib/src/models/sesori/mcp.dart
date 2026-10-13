import "package:freezed_annotation/freezed_annotation.dart";

part "mcp.freezed.dart";
part "mcp.g.dart";

@Freezed(unionKey: "type", copyWith: false, fromJson: true, toJson: true)
sealed class McpScope with _$McpScope {
  const factory harness() = McpHarnessScope;
  const factory project({required String projectId}) = McpProjectScope;
  const factory session({required String sessionId}) = McpSessionScope;

  factory fromJson(Map<String, dynamic> json) => _$McpScopeFromJson(json);
}

@Freezed(unionKey: "type", copyWith: false, fromJson: true, toJson: true)
sealed class McpEntryTarget with _$McpEntryTarget {
  const factory server({required McpScope scope, required String serverKey}) = McpServerTarget;
  const factory connectorOffer({required McpScope scope, required String offerKey}) = McpConnectorOfferTarget;

  factory fromJson(Map<String, dynamic> json) => _$McpEntryTargetFromJson(json);
}

enum McpConnectionPhase() { unknown, pending, connecting, connected, authenticationRequired, disabled }

@Freezed(unionKey: "type", fallbackUnion: "unknown", copyWith: false, fromJson: true, toJson: true)
sealed class McpConnectionState with _$McpConnectionState {
  const factory unknown() = McpConnectionUnknown;
  const factory status({@JsonKey(unknownEnumValue: McpConnectionPhase.unknown) required McpConnectionPhase phase}) = McpConnectionStatus;
  const factory failed({required String message}) = McpConnectionFailed;

  factory fromJson(Map<String, dynamic> json) => _$McpConnectionStateFromJson(json);
}

enum McpAuthorizationState() { unknown, notRequired, required, authenticated }

enum McpConfigurationScope() { unknown, harness, project, session }

enum McpConfigurationMutability() { unknown, userManaged, readOnly }

/// Scope describes configuration origin; it grants no action or write access.
/// Native configuration values and credentials never cross this boundary.
@Freezed(unionKey: "type", copyWith: false, fromJson: true, toJson: true)
sealed class McpConfigurationSource with _$McpConfigurationSource {
  const factory({@JsonKey(unknownEnumValue: McpConfigurationScope.unknown) required McpConfigurationScope scope,
    @JsonKey(unknownEnumValue: McpConfigurationMutability.unknown) required McpConfigurationMutability mutability})
      = _McpConfigurationSource;

  factory fromJson(Map<String, dynamic> json) => _$McpConfigurationSourceFromJson(json);
}

@Freezed(unionKey: "type", copyWith: false, fromJson: true, toJson: true)
sealed class McpTool with _$McpTool {
  const factory({required String name, required String? description}) = _McpTool;

  factory fromJson(Map<String, dynamic> json) => _$McpToolFromJson(json);
}

@Freezed(unionKey: "type", fallbackUnion: "unavailable", copyWith: false, fromJson: true, toJson: true)
sealed class McpToolInventory with _$McpToolInventory {
  const factory available({required List<McpTool> tools}) = McpToolsAvailable;
  const factory unavailable() = McpToolsUnavailable;
  const factory failed({required String message}) = McpToolsFailed;

  factory fromJson(Map<String, dynamic> json) => _$McpToolInventoryFromJson(json);
}

enum McpConnectorOfferAvailability() { unknown, available, setupRequired, unavailable }

@Freezed(unionKey: "type", fallbackUnion: "unknown", copyWith: false, fromJson: true, toJson: true)
sealed class McpInventoryEntry with _$McpInventoryEntry {
  const factory unknown() = McpUnknownInventoryEntry;
  const factory server({
    @JsonKey(name: "target") required McpServerTarget serverTarget,
    required String name,
    required String? description,
    required String? endpointOrigin,
    required McpConnectionState connection,
    @JsonKey(unknownEnumValue: McpAuthorizationState.unknown) required McpAuthorizationState authorization,
    required McpConfigurationSource? configuration,
    required McpToolInventory tools,
  }) = McpServerSnapshot;

  const factory connectorOffer({
    @JsonKey(name: "target") required McpConnectorOfferTarget offerTarget,
    required String name,
    required String? description,
    @JsonKey(unknownEnumValue: McpConnectorOfferAvailability.unknown) required McpConnectorOfferAvailability availability,
  }) = McpConnectorOfferSnapshot;

  factory fromJson(Map<String, dynamic> json) => _$McpInventoryEntryFromJson(json);
}

@Freezed(unionKey: "type", fallbackUnion: "unknown", copyWith: false, fromJson: true, toJson: true)
sealed class McpCatalogAvailability with _$McpCatalogAvailability {
  const factory unknown() = McpCatalogUnknown;
  const factory available() = McpCatalogAvailable;
  const factory notSupported() = McpCatalogNotSupported;
  const factory unavailable({required String message}) = McpCatalogUnavailable;

  factory fromJson(Map<String, dynamic> json) => _$McpCatalogAvailabilityFromJson(json);
}

enum McpInventoryUnavailableReason() { unknown, unsupportedHarness, unsupportedScope, liveSessionRequired, pluginInactive }

@Freezed(unionKey: "type", fallbackUnion: "unknown", copyWith: false, fromJson: true, toJson: true)
sealed class McpInventoryResult with _$McpInventoryResult {
  const factory unknown() = McpInventoryUnknown;
  const factory available({
    required McpScope scope,
    required List<McpInventoryEntry> entries,
    required McpCatalogAvailability servers,
    required McpCatalogAvailability connectors,
  }) = McpInventorySnapshot;
  const factory unavailable({
    required McpScope scope,
    @JsonKey(unknownEnumValue: McpInventoryUnavailableReason.unknown) required McpInventoryUnavailableReason reason,
    required String message,
  }) = McpInventoryUnavailable;

  factory fromJson(Map<String, dynamic> json) => _$McpInventoryResultFromJson(json);
}

@Freezed(unionKey: "type", copyWith: false, fromJson: true, toJson: true)
sealed class McpInventoryRequest with _$McpInventoryRequest {
  const factory({required String pluginId, required McpScope scope}) = _McpInventoryRequest;

  factory fromJson(Map<String, dynamic> json) => _$McpInventoryRequestFromJson(json);
}
