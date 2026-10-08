// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_code_service_registration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OpenCodeServiceRegistration _$OpenCodeServiceRegistrationFromJson(Map json) =>
    $checkedCreate('_OpenCodeServiceRegistration', json, ($checkedConvert) {
      final val = _OpenCodeServiceRegistration(
        url: $checkedConvert('url', (v) => v as String),
        pid: $checkedConvert('pid', (v) => (v as num).toInt()),
        password: $checkedConvert('password', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$OpenCodeServiceRegistrationToJson(
  _OpenCodeServiceRegistration instance,
) => <String, dynamic>{
  'url': instance.url,
  'pid': instance.pid,
  'password': ?instance.password,
};
