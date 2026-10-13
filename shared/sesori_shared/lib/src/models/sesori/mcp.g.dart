// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

McpHarnessScope _$McpHarnessScopeFromJson(Map json) =>
    McpHarnessScope($type: json['type'] as String?);

Map<String, dynamic> _$McpHarnessScopeToJson(McpHarnessScope instance) =>
    <String, dynamic>{'type': instance.$type};

McpProjectScope _$McpProjectScopeFromJson(Map json) => McpProjectScope(
  projectId: json['projectId'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McpProjectScopeToJson(McpProjectScope instance) =>
    <String, dynamic>{'projectId': instance.projectId, 'type': instance.$type};

McpSessionScope _$McpSessionScopeFromJson(Map json) => McpSessionScope(
  sessionId: json['sessionId'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McpSessionScopeToJson(McpSessionScope instance) =>
    <String, dynamic>{'sessionId': instance.sessionId, 'type': instance.$type};

McpServerTarget _$McpServerTargetFromJson(Map json) => McpServerTarget(
  scope: McpScope.fromJson(Map<String, dynamic>.from(json['scope'] as Map)),
  serverKey: json['serverKey'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McpServerTargetToJson(McpServerTarget instance) =>
    <String, dynamic>{
      'scope': instance.scope.toJson(),
      'serverKey': instance.serverKey,
      'type': instance.$type,
    };

McpConnectorOfferTarget _$McpConnectorOfferTargetFromJson(Map json) =>
    McpConnectorOfferTarget(
      scope: McpScope.fromJson(Map<String, dynamic>.from(json['scope'] as Map)),
      offerKey: json['offerKey'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpConnectorOfferTargetToJson(
  McpConnectorOfferTarget instance,
) => <String, dynamic>{
  'scope': instance.scope.toJson(),
  'offerKey': instance.offerKey,
  'type': instance.$type,
};

McpConnectionUnknown _$McpConnectionUnknownFromJson(Map json) =>
    McpConnectionUnknown($type: json['type'] as String?);

Map<String, dynamic> _$McpConnectionUnknownToJson(
  McpConnectionUnknown instance,
) => <String, dynamic>{'type': instance.$type};

McpConnectionStatus _$McpConnectionStatusFromJson(Map json) =>
    McpConnectionStatus(
      phase: $enumDecode(
        _$McpConnectionPhaseEnumMap,
        json['phase'],
        unknownValue: McpConnectionPhase.unknown,
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpConnectionStatusToJson(
  McpConnectionStatus instance,
) => <String, dynamic>{
  'phase': _$McpConnectionPhaseEnumMap[instance.phase]!,
  'type': instance.$type,
};

const _$McpConnectionPhaseEnumMap = {
  McpConnectionPhase.unknown: 'unknown',
  McpConnectionPhase.pending: 'pending',
  McpConnectionPhase.connecting: 'connecting',
  McpConnectionPhase.connected: 'connected',
  McpConnectionPhase.authenticationRequired: 'authenticationRequired',
  McpConnectionPhase.disabled: 'disabled',
};

McpConnectionFailed _$McpConnectionFailedFromJson(Map json) =>
    McpConnectionFailed(
      message: json['message'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpConnectionFailedToJson(
  McpConnectionFailed instance,
) => <String, dynamic>{'message': instance.message, 'type': instance.$type};

_McpConfigurationSource _$McpConfigurationSourceFromJson(Map json) =>
    _McpConfigurationSource(
      scope: $enumDecode(
        _$McpConfigurationScopeEnumMap,
        json['scope'],
        unknownValue: McpConfigurationScope.unknown,
      ),
      mutability: $enumDecode(
        _$McpConfigurationMutabilityEnumMap,
        json['mutability'],
        unknownValue: McpConfigurationMutability.unknown,
      ),
    );

Map<String, dynamic> _$McpConfigurationSourceToJson(
  _McpConfigurationSource instance,
) => <String, dynamic>{
  'scope': _$McpConfigurationScopeEnumMap[instance.scope]!,
  'mutability': _$McpConfigurationMutabilityEnumMap[instance.mutability]!,
};

const _$McpConfigurationScopeEnumMap = {
  McpConfigurationScope.unknown: 'unknown',
  McpConfigurationScope.harness: 'harness',
  McpConfigurationScope.project: 'project',
  McpConfigurationScope.session: 'session',
};

const _$McpConfigurationMutabilityEnumMap = {
  McpConfigurationMutability.unknown: 'unknown',
  McpConfigurationMutability.userManaged: 'userManaged',
  McpConfigurationMutability.readOnly: 'readOnly',
};

_McpTool _$McpToolFromJson(Map json) => _McpTool(
  name: json['name'] as String,
  description: json['description'] as String?,
);

Map<String, dynamic> _$McpToolToJson(_McpTool instance) => <String, dynamic>{
  'name': instance.name,
  'description': ?instance.description,
};

McpToolsAvailable _$McpToolsAvailableFromJson(Map json) => McpToolsAvailable(
  tools: (json['tools'] as List<dynamic>)
      .map((e) => McpTool.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McpToolsAvailableToJson(McpToolsAvailable instance) =>
    <String, dynamic>{
      'tools': instance.tools.map((e) => e.toJson()).toList(),
      'type': instance.$type,
    };

McpToolsUnavailable _$McpToolsUnavailableFromJson(Map json) =>
    McpToolsUnavailable($type: json['type'] as String?);

Map<String, dynamic> _$McpToolsUnavailableToJson(
  McpToolsUnavailable instance,
) => <String, dynamic>{'type': instance.$type};

McpToolsFailed _$McpToolsFailedFromJson(Map json) => McpToolsFailed(
  message: json['message'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McpToolsFailedToJson(McpToolsFailed instance) =>
    <String, dynamic>{'message': instance.message, 'type': instance.$type};

McpUnknownInventoryEntry _$McpUnknownInventoryEntryFromJson(Map json) =>
    McpUnknownInventoryEntry($type: json['type'] as String?);

Map<String, dynamic> _$McpUnknownInventoryEntryToJson(
  McpUnknownInventoryEntry instance,
) => <String, dynamic>{'type': instance.$type};

McpServerSnapshot _$McpServerSnapshotFromJson(Map json) => McpServerSnapshot(
  serverTarget: McpServerTarget.fromJson(
    Map<String, dynamic>.from(json['target'] as Map),
  ),
  name: json['name'] as String,
  description: json['description'] as String?,
  endpointOrigin: json['endpointOrigin'] as String?,
  connection: McpConnectionState.fromJson(
    Map<String, dynamic>.from(json['connection'] as Map),
  ),
  authorization: $enumDecode(
    _$McpAuthorizationStateEnumMap,
    json['authorization'],
    unknownValue: McpAuthorizationState.unknown,
  ),
  configuration: json['configuration'] == null
      ? null
      : McpConfigurationSource.fromJson(
          Map<String, dynamic>.from(json['configuration'] as Map),
        ),
  tools: McpToolInventory.fromJson(
    Map<String, dynamic>.from(json['tools'] as Map),
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McpServerSnapshotToJson(McpServerSnapshot instance) =>
    <String, dynamic>{
      'target': instance.serverTarget.toJson(),
      'name': instance.name,
      'description': ?instance.description,
      'endpointOrigin': ?instance.endpointOrigin,
      'connection': instance.connection.toJson(),
      'authorization': _$McpAuthorizationStateEnumMap[instance.authorization]!,
      'configuration': ?instance.configuration?.toJson(),
      'tools': instance.tools.toJson(),
      'type': instance.$type,
    };

const _$McpAuthorizationStateEnumMap = {
  McpAuthorizationState.unknown: 'unknown',
  McpAuthorizationState.notRequired: 'notRequired',
  McpAuthorizationState.required: 'required',
  McpAuthorizationState.authenticated: 'authenticated',
};

McpConnectorOfferSnapshot _$McpConnectorOfferSnapshotFromJson(Map json) =>
    McpConnectorOfferSnapshot(
      offerTarget: McpConnectorOfferTarget.fromJson(
        Map<String, dynamic>.from(json['target'] as Map),
      ),
      name: json['name'] as String,
      description: json['description'] as String?,
      availability: $enumDecode(
        _$McpConnectorOfferAvailabilityEnumMap,
        json['availability'],
        unknownValue: McpConnectorOfferAvailability.unknown,
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpConnectorOfferSnapshotToJson(
  McpConnectorOfferSnapshot instance,
) => <String, dynamic>{
  'target': instance.offerTarget.toJson(),
  'name': instance.name,
  'description': ?instance.description,
  'availability':
      _$McpConnectorOfferAvailabilityEnumMap[instance.availability]!,
  'type': instance.$type,
};

const _$McpConnectorOfferAvailabilityEnumMap = {
  McpConnectorOfferAvailability.unknown: 'unknown',
  McpConnectorOfferAvailability.available: 'available',
  McpConnectorOfferAvailability.setupRequired: 'setupRequired',
  McpConnectorOfferAvailability.unavailable: 'unavailable',
};

McpCatalogUnknown _$McpCatalogUnknownFromJson(Map json) =>
    McpCatalogUnknown($type: json['type'] as String?);

Map<String, dynamic> _$McpCatalogUnknownToJson(McpCatalogUnknown instance) =>
    <String, dynamic>{'type': instance.$type};

McpCatalogAvailable _$McpCatalogAvailableFromJson(Map json) =>
    McpCatalogAvailable($type: json['type'] as String?);

Map<String, dynamic> _$McpCatalogAvailableToJson(
  McpCatalogAvailable instance,
) => <String, dynamic>{'type': instance.$type};

McpCatalogNotSupported _$McpCatalogNotSupportedFromJson(Map json) =>
    McpCatalogNotSupported($type: json['type'] as String?);

Map<String, dynamic> _$McpCatalogNotSupportedToJson(
  McpCatalogNotSupported instance,
) => <String, dynamic>{'type': instance.$type};

McpCatalogUnavailable _$McpCatalogUnavailableFromJson(Map json) =>
    McpCatalogUnavailable(
      message: json['message'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpCatalogUnavailableToJson(
  McpCatalogUnavailable instance,
) => <String, dynamic>{'message': instance.message, 'type': instance.$type};

McpInventoryUnknown _$McpInventoryUnknownFromJson(Map json) =>
    McpInventoryUnknown($type: json['type'] as String?);

Map<String, dynamic> _$McpInventoryUnknownToJson(
  McpInventoryUnknown instance,
) => <String, dynamic>{'type': instance.$type};

McpInventorySnapshot _$McpInventorySnapshotFromJson(Map json) =>
    McpInventorySnapshot(
      scope: McpScope.fromJson(Map<String, dynamic>.from(json['scope'] as Map)),
      entries: (json['entries'] as List<dynamic>)
          .map(
            (e) =>
                McpInventoryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      servers: McpCatalogAvailability.fromJson(
        Map<String, dynamic>.from(json['servers'] as Map),
      ),
      connectors: McpCatalogAvailability.fromJson(
        Map<String, dynamic>.from(json['connectors'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpInventorySnapshotToJson(
  McpInventorySnapshot instance,
) => <String, dynamic>{
  'scope': instance.scope.toJson(),
  'entries': instance.entries.map((e) => e.toJson()).toList(),
  'servers': instance.servers.toJson(),
  'connectors': instance.connectors.toJson(),
  'type': instance.$type,
};

McpInventoryUnavailable _$McpInventoryUnavailableFromJson(Map json) =>
    McpInventoryUnavailable(
      scope: McpScope.fromJson(Map<String, dynamic>.from(json['scope'] as Map)),
      reason: $enumDecode(
        _$McpInventoryUnavailableReasonEnumMap,
        json['reason'],
        unknownValue: McpInventoryUnavailableReason.unknown,
      ),
      message: json['message'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpInventoryUnavailableToJson(
  McpInventoryUnavailable instance,
) => <String, dynamic>{
  'scope': instance.scope.toJson(),
  'reason': _$McpInventoryUnavailableReasonEnumMap[instance.reason]!,
  'message': instance.message,
  'type': instance.$type,
};

const _$McpInventoryUnavailableReasonEnumMap = {
  McpInventoryUnavailableReason.unknown: 'unknown',
  McpInventoryUnavailableReason.unsupportedHarness: 'unsupportedHarness',
  McpInventoryUnavailableReason.unsupportedScope: 'unsupportedScope',
  McpInventoryUnavailableReason.liveSessionRequired: 'liveSessionRequired',
  McpInventoryUnavailableReason.pluginInactive: 'pluginInactive',
};

_McpInventoryRequest _$McpInventoryRequestFromJson(Map json) =>
    _McpInventoryRequest(
      pluginId: json['pluginId'] as String,
      scope: McpScope.fromJson(Map<String, dynamic>.from(json['scope'] as Map)),
    );

Map<String, dynamic> _$McpInventoryRequestToJson(
  _McpInventoryRequest instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'scope': instance.scope.toJson(),
};
