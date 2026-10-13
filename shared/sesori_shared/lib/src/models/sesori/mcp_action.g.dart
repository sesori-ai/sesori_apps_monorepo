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
    );

const _$McpServerActionEnumMap = {
  McpServerAction.unknown: 'unknown',
  McpServerAction.reconnect: 'reconnect',
  McpServerAction.enable: 'enable',
  McpServerAction.disable: 'disable',
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
};

McpActionFailed _$McpActionFailedFromJson(Map json) =>
    McpActionFailed($type: json['type'] as String?);

Map<String, dynamic> _$McpActionFailedToJson(McpActionFailed instance) =>
    <String, dynamic>{'type': instance.$type};
