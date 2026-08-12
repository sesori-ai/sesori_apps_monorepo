// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_account_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$CodexDeviceLoginStartParamsDtoToJson(
  _CodexDeviceLoginStartParamsDto instance,
) => <String, dynamic>{'type': _$CodexAccountLoginTypeEnumMap[instance.type]!};

const _$CodexAccountLoginTypeEnumMap = {
  CodexAccountLoginType.chatgptDeviceCode: 'chatgptDeviceCode',
};

_CodexDeviceLoginStartResponseDto _$CodexDeviceLoginStartResponseDtoFromJson(
  Map json,
) => _CodexDeviceLoginStartResponseDto(
  type: $enumDecode(_$CodexAccountLoginTypeEnumMap, json['type']),
  loginId: json['loginId'] as String,
  verificationUrl: json['verificationUrl'] as String,
  userCode: json['userCode'] as String,
);

Map<String, dynamic> _$CodexAccountLoginCancelParamsDtoToJson(
  _CodexAccountLoginCancelParamsDto instance,
) => <String, dynamic>{'loginId': instance.loginId};

_CodexAccountLoginCancelResponseDto
_$CodexAccountLoginCancelResponseDtoFromJson(Map json) =>
    _CodexAccountLoginCancelResponseDto(
      status: $enumDecode(
        _$CodexAccountLoginCancelStatusEnumMap,
        json['status'],
        unknownValue: CodexAccountLoginCancelStatus.unknown,
      ),
    );

const _$CodexAccountLoginCancelStatusEnumMap = {
  CodexAccountLoginCancelStatus.canceled: 'canceled',
  CodexAccountLoginCancelStatus.notFound: 'notFound',
  CodexAccountLoginCancelStatus.unknown: 'unknown',
};

_CodexAccountLoginCompletedNotificationDto
_$CodexAccountLoginCompletedNotificationDtoFromJson(Map json) =>
    _CodexAccountLoginCompletedNotificationDto(
      loginId: json['loginId'] as String?,
      success: json['success'] as bool,
      error: json['error'] as String?,
    );
