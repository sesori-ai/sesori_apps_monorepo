// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JsonParsingError _$JsonParsingErrorFromJson(Map json) => JsonParsingError(
  json['jsonString'] as String,
  $type: json['runtimeType'] as String?,
);

DartHttpClientError _$DartHttpClientErrorFromJson(Map json) =>
    DartHttpClientError(
      json['innerError'] as Object,
      $type: json['runtimeType'] as String?,
    );

GenericError _$GenericErrorFromJson(Map json) =>
    GenericError($type: json['runtimeType'] as String?);

NotAuthenticatedError _$NotAuthenticatedErrorFromJson(Map json) =>
    NotAuthenticatedError($type: json['runtimeType'] as String?);

NonSuccessCodeError _$NonSuccessCodeErrorFromJson(Map json) =>
    NonSuccessCodeError(
      errorCode: (json['errorCode'] as num).toInt(),
      rawErrorString: json['rawErrorString'] as String?,
      $type: json['runtimeType'] as String?,
    );

EmptyResponseError _$EmptyResponseErrorFromJson(Map json) =>
    EmptyResponseError($type: json['runtimeType'] as String?);
