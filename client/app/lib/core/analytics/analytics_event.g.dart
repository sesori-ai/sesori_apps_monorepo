// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NeedHelpMenuOpened _$NeedHelpMenuOpenedFromJson(Map json) =>
    NeedHelpMenuOpened($type: json['event_name'] as String?);

Map<String, dynamic> _$NeedHelpMenuOpenedToJson(NeedHelpMenuOpened instance) =>
    <String, dynamic>{'event_name': instance.$type};

SupportLinkOpened _$SupportLinkOpenedFromJson(Map json) => SupportLinkOpened(
  channel: $enumDecode(_$SupportChannelEnumMap, json['channel']),
  $type: json['event_name'] as String?,
);

Map<String, dynamic> _$SupportLinkOpenedToJson(SupportLinkOpened instance) =>
    <String, dynamic>{
      'channel': _$SupportChannelEnumMap[instance.channel]!,
      'event_name': instance.$type,
    };

const _$SupportChannelEnumMap = {
  SupportChannel.email: 'email',
  SupportChannel.discord: 'discord',
  SupportChannel.x: 'x',
};
