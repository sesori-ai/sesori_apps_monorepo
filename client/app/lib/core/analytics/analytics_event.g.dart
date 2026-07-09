// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NeedHelpMenuOpened _$NeedHelpMenuOpenedFromJson(Map json) => NeedHelpMenuOpened(
  surface: $enumDecode(_$OnboardingSurfaceEnumMap, json['surface']),
  $type: json['event_name'] as String?,
);

Map<String, dynamic> _$NeedHelpMenuOpenedToJson(NeedHelpMenuOpened instance) =>
    <String, dynamic>{
      'surface': _$OnboardingSurfaceEnumMap[instance.surface]!,
      'event_name': instance.$type,
    };

const _$OnboardingSurfaceEnumMap = {
  OnboardingSurface.connectSetup: 'connect_setup',
  OnboardingSurface.connectedEmpty: 'connected_empty',
  OnboardingSurface.bridgeOffline: 'bridge_offline',
};

SupportLinkOpened _$SupportLinkOpenedFromJson(Map json) => SupportLinkOpened(
  channel: $enumDecode(_$SupportChannelEnumMap, json['channel']),
  surface: $enumDecode(_$OnboardingSurfaceEnumMap, json['surface']),
  $type: json['event_name'] as String?,
);

Map<String, dynamic> _$SupportLinkOpenedToJson(SupportLinkOpened instance) =>
    <String, dynamic>{
      'channel': _$SupportChannelEnumMap[instance.channel]!,
      'surface': _$OnboardingSurfaceEnumMap[instance.surface]!,
      'event_name': instance.$type,
    };

const _$SupportChannelEnumMap = {
  SupportChannel.email: 'email',
  SupportChannel.discord: 'discord',
  SupportChannel.x: 'x',
};

WhyBridgeOpened _$WhyBridgeOpenedFromJson(Map json) => WhyBridgeOpened(
  surface: $enumDecode(_$OnboardingSurfaceEnumMap, json['surface']),
  $type: json['event_name'] as String?,
);

Map<String, dynamic> _$WhyBridgeOpenedToJson(WhyBridgeOpened instance) =>
    <String, dynamic>{
      'surface': _$OnboardingSurfaceEnumMap[instance.surface]!,
      'event_name': instance.$type,
    };

InstallCommandCopied _$InstallCommandCopiedFromJson(Map json) =>
    InstallCommandCopied(
      method: $enumDecode(_$BridgeInstallMethodEnumMap, json['method']),
      os: $enumDecode(_$BridgeInstallOsEnumMap, json['os']),
      surface: $enumDecode(_$OnboardingSurfaceEnumMap, json['surface']),
      $type: json['event_name'] as String?,
    );

Map<String, dynamic> _$InstallCommandCopiedToJson(
  InstallCommandCopied instance,
) => <String, dynamic>{
  'method': _$BridgeInstallMethodEnumMap[instance.method]!,
  'os': _$BridgeInstallOsEnumMap[instance.os]!,
  'surface': _$OnboardingSurfaceEnumMap[instance.surface]!,
  'event_name': instance.$type,
};

const _$BridgeInstallMethodEnumMap = {
  BridgeInstallMethod.curl: 'curl',
  BridgeInstallMethod.powershell: 'powershell',
  BridgeInstallMethod.npm: 'npm',
  BridgeInstallMethod.bun: 'bun',
};

const _$BridgeInstallOsEnumMap = {
  BridgeInstallOs.unix: 'unix',
  BridgeInstallOs.windows: 'windows',
};

InstallCommandShared _$InstallCommandSharedFromJson(Map json) =>
    InstallCommandShared(
      method: $enumDecode(_$BridgeInstallMethodEnumMap, json['method']),
      os: $enumDecode(_$BridgeInstallOsEnumMap, json['os']),
      surface: $enumDecode(_$OnboardingSurfaceEnumMap, json['surface']),
      $type: json['event_name'] as String?,
    );

Map<String, dynamic> _$InstallCommandSharedToJson(
  InstallCommandShared instance,
) => <String, dynamic>{
  'method': _$BridgeInstallMethodEnumMap[instance.method]!,
  'os': _$BridgeInstallOsEnumMap[instance.os]!,
  'surface': _$OnboardingSurfaceEnumMap[instance.surface]!,
  'event_name': instance.$type,
};

RunCommandCopied _$RunCommandCopiedFromJson(Map json) => RunCommandCopied(
  surface: $enumDecode(_$OnboardingSurfaceEnumMap, json['surface']),
  $type: json['event_name'] as String?,
);

Map<String, dynamic> _$RunCommandCopiedToJson(RunCommandCopied instance) =>
    <String, dynamic>{
      'surface': _$OnboardingSurfaceEnumMap[instance.surface]!,
      'event_name': instance.$type,
    };

RunCommandShared _$RunCommandSharedFromJson(Map json) => RunCommandShared(
  surface: $enumDecode(_$OnboardingSurfaceEnumMap, json['surface']),
  $type: json['event_name'] as String?,
);

Map<String, dynamic> _$RunCommandSharedToJson(RunCommandShared instance) =>
    <String, dynamic>{
      'surface': _$OnboardingSurfaceEnumMap[instance.surface]!,
      'event_name': instance.$type,
    };
