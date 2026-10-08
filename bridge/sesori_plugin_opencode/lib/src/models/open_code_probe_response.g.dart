// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_code_probe_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OpenCodeProbeResponse _$OpenCodeProbeResponseFromJson(Map json) =>
    $checkedCreate('_OpenCodeProbeResponse', json, ($checkedConvert) {
      final val = _OpenCodeProbeResponse(
        version: $checkedConvert('version', (v) => v as String?),
        pid: $checkedConvert('pid', (v) => (v as num?)?.toInt()),
      );
      return val;
    });

Map<String, dynamic> _$OpenCodeProbeResponseToJson(
  _OpenCodeProbeResponse instance,
) => <String, dynamic>{'version': ?instance.version, 'pid': ?instance.pid};
