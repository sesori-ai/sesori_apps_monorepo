// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommandListResponse _$CommandListResponseFromJson(Map json) =>
    _CommandListResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => CommandInfo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );

Map<String, dynamic> _$CommandListResponseToJson(
  _CommandListResponse instance,
) => <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};
