// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_queued_prompt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginQueuedPromptToJson(_PluginQueuedPrompt instance) =>
    <String, dynamic>{
      'id': instance.id,
      'dispatchState':
          _$PluginQueuedPromptDispatchStateEnumMap[instance.dispatchState]!,
      'text': ?instance.text,
      'command': ?instance.command,
      'attachmentCount': instance.attachmentCount,
      'createdAt': instance.createdAt,
    };

const _$PluginQueuedPromptDispatchStateEnumMap = {
  PluginQueuedPromptDispatchState.queued: 'queued',
  PluginQueuedPromptDispatchState.dispatched: 'dispatched',
};
