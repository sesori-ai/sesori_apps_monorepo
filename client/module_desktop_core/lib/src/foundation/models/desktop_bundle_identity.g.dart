// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desktop_bundle_identity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DesktopBundleIdentity _$DesktopBundleIdentityFromJson(
  Map<String, dynamic> json,
) => _DesktopBundleIdentity(
  version: json['version'] as String,
  buildNumber: (json['buildNumber'] as num).toInt(),
  sourceSha: json['sourceSha'] as String,
  os: $enumDecode(_$DesktopBundleOsEnumMap, json['os']),
  architecture: $enumDecode(
    _$DesktopBundleArchitectureEnumMap,
    json['architecture'],
  ),
);

Map<String, dynamic> _$DesktopBundleIdentityToJson(
  _DesktopBundleIdentity instance,
) => <String, dynamic>{
  'version': instance.version,
  'buildNumber': instance.buildNumber,
  'sourceSha': instance.sourceSha,
  'os': _$DesktopBundleOsEnumMap[instance.os]!,
  'architecture': _$DesktopBundleArchitectureEnumMap[instance.architecture]!,
};

const _$DesktopBundleOsEnumMap = {
  DesktopBundleOs.macos: 'macos',
  DesktopBundleOs.windows: 'windows',
  DesktopBundleOs.linux: 'linux',
};

const _$DesktopBundleArchitectureEnumMap = {
  DesktopBundleArchitecture.x64: 'x64',
  DesktopBundleArchitecture.arm64: 'arm64',
};
