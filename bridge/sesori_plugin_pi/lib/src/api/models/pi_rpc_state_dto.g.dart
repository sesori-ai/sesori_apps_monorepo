// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pi_rpc_state_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PiRpcStateDto _$PiRpcStateDtoFromJson(Map json) => _PiRpcStateDto(
  model: json['model'] == null
      ? null
      : PiRpcStateModelDto.fromJson(
          Map<String, dynamic>.from(json['model'] as Map),
        ),
  thinkingLevel: json['thinkingLevel'] as String?,
  isStreaming: json['isStreaming'] as bool? ?? false,
  pendingMessageCount: (json['pendingMessageCount'] as num?)?.toInt() ?? 0,
);

_PiRpcStateModelDto _$PiRpcStateModelDtoFromJson(Map json) =>
    _PiRpcStateModelDto(
      provider: json['provider'] as String,
      id: json['id'] as String,
    );
