// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_prompt_error_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SendPromptErrorResponse _$SendPromptErrorResponseFromJson(Map json) =>
    _SendPromptErrorResponse(
      code: $enumDecode(
        _$SendPromptErrorCodeEnumMap,
        json['code'],
        unknownValue: SendPromptErrorCode.unknown,
      ),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$SendPromptErrorResponseToJson(
  _SendPromptErrorResponse instance,
) => <String, dynamic>{
  'code': _$SendPromptErrorCodeEnumMap[instance.code]!,
  'message': ?instance.message,
};

const _$SendPromptErrorCodeEnumMap = {
  SendPromptErrorCode.staleSessionOptions: 'staleSessionOptions',
  SendPromptErrorCode.unknown: 'unknown',
};
