// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

McpServerEntryAction _$McpServerEntryActionFromJson(Map json) =>
    McpServerEntryAction(
      target: McpEntryTarget.serverFromJson(
        json['target'] as Map<String, dynamic>,
      ),
      action: $enumDecode(_$McpServerActionEnumMap, json['action']),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpServerEntryActionToJson(
  McpServerEntryAction instance,
) => <String, dynamic>{
  'target': instance.target.toJson(),
  'action': _$McpServerActionEnumMap[instance.action]!,
  'type': instance.$type,
};

const _$McpServerActionEnumMap = {
  McpServerAction.unknown: 'unknown',
  McpServerAction.reconnect: 'reconnect',
  McpServerAction.enable: 'enable',
  McpServerAction.disable: 'disable',
};

McpForgetAuthenticationEntryAction _$McpForgetAuthenticationEntryActionFromJson(
  Map json,
) => McpForgetAuthenticationEntryAction(
  target: McpEntryTarget.serverFromJson(json['target'] as Map<String, dynamic>),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McpForgetAuthenticationEntryActionToJson(
  McpForgetAuthenticationEntryAction instance,
) => <String, dynamic>{
  'target': instance.target.toJson(),
  'type': instance.$type,
};

McpConnectorSetupEntryAction _$McpConnectorSetupEntryActionFromJson(Map json) =>
    McpConnectorSetupEntryAction(
      offerTarget: McpEntryTarget.connectorOfferFromJson(
        json['target'] as Map<String, dynamic>,
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpConnectorSetupEntryActionToJson(
  McpConnectorSetupEntryAction instance,
) => <String, dynamic>{
  'target': instance.offerTarget.toJson(),
  'type': instance.$type,
};

_McpEntryActionRequest _$McpEntryActionRequestFromJson(Map json) =>
    _McpEntryActionRequest(
      pluginId: json['pluginId'] as String,
      action: McpEntryAction.fromJson(
        Map<String, dynamic>.from(json['action'] as Map),
      ),
    );

Map<String, dynamic> _$McpEntryActionRequestToJson(
  _McpEntryActionRequest instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'action': instance.action.toJson(),
};

McpActionUnknown _$McpActionUnknownFromJson(Map json) =>
    McpActionUnknown($type: json['type'] as String?);

Map<String, dynamic> _$McpActionUnknownToJson(McpActionUnknown instance) =>
    <String, dynamic>{'type': instance.$type};

McpActionCompleted _$McpActionCompletedFromJson(Map json) => McpActionCompleted(
  inventory: McpInventoryResult.fromJson(
    Map<String, dynamic>.from(json['inventory'] as Map),
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McpActionCompletedToJson(McpActionCompleted instance) =>
    <String, dynamic>{
      'inventory': instance.inventory.toJson(),
      'type': instance.$type,
    };

McpExternalSetup _$McpExternalSetupFromJson(Map json) => McpExternalSetup(
  setupUrl: json['setupUrl'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McpExternalSetupToJson(McpExternalSetup instance) =>
    <String, dynamic>{'setupUrl': instance.setupUrl, 'type': instance.$type};

McpActionUnavailable _$McpActionUnavailableFromJson(Map json) =>
    McpActionUnavailable(
      reason: $enumDecode(
        _$McpActionUnavailableReasonEnumMap,
        json['reason'],
        unknownValue: McpActionUnavailableReason.unknown,
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$McpActionUnavailableToJson(
  McpActionUnavailable instance,
) => <String, dynamic>{
  'reason': _$McpActionUnavailableReasonEnumMap[instance.reason]!,
  'type': instance.$type,
};

const _$McpActionUnavailableReasonEnumMap = {
  McpActionUnavailableReason.unknown: 'unknown',
  McpActionUnavailableReason.unsupportedHarness: 'unsupportedHarness',
  McpActionUnavailableReason.unsupportedScope: 'unsupportedScope',
  McpActionUnavailableReason.liveSessionRequired: 'liveSessionRequired',
  McpActionUnavailableReason.pluginInactive: 'pluginInactive',
  McpActionUnavailableReason.targetNotFound: 'targetNotFound',
  McpActionUnavailableReason.busy: 'busy',
  McpActionUnavailableReason.notSupported: 'notSupported',
  McpActionUnavailableReason.notImplemented: 'notImplemented',
  McpActionUnavailableReason.nativeConfigurationRequired:
      'nativeConfigurationRequired',
};

McpActionFailed _$McpActionFailedFromJson(Map json) =>
    McpActionFailed($type: json['type'] as String?);

Map<String, dynamic> _$McpActionFailedToJson(McpActionFailed instance) =>
    <String, dynamic>{'type': instance.$type};
