// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TokenData _$TokenDataFromJson(Map json) =>
    $checkedCreate('_TokenData', json, ($checkedConvert) {
      final val = _TokenData(
        accessToken: $checkedConvert('accessToken', (v) => v as String),
        refreshToken: $checkedConvert('refreshToken', (v) => v as String),
        lastProvider: $checkedConvert(
          'lastProvider',
          (v) => authProviderConverter.fromJson(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$TokenDataToJson(_TokenData instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'lastProvider': authProviderConverter.toJson(instance.lastProvider),
    };
