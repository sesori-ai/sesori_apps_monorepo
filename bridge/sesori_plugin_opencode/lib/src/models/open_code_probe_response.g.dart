// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_code_probe_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OpenCodeProbeResponse _$OpenCodeProbeResponseFromJson(Map json) =>
    $checkedCreate('_OpenCodeProbeResponse', json, ($checkedConvert) {
      final val = _OpenCodeProbeResponse(
        version: $checkedConvert('version', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$OpenCodeProbeResponseToJson(
  _OpenCodeProbeResponse instance,
) => <String, dynamic>{'version': ?instance.version};
