// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'control_provision_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ControlProvisionResolving _$ControlProvisionResolvingFromJson(Map json) =>
    ControlProvisionResolving($type: json['type'] as String?);

Map<String, dynamic> _$ControlProvisionResolvingToJson(
  ControlProvisionResolving instance,
) => <String, dynamic>{'type': instance.$type};

ControlProvisionDownloading _$ControlProvisionDownloadingFromJson(Map json) =>
    ControlProvisionDownloading(
      receivedBytes: (json['receivedBytes'] as num).toInt(),
      totalBytes: (json['totalBytes'] as num?)?.toInt(),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ControlProvisionDownloadingToJson(
  ControlProvisionDownloading instance,
) => <String, dynamic>{
  'receivedBytes': instance.receivedBytes,
  'totalBytes': ?instance.totalBytes,
  'type': instance.$type,
};

ControlProvisionExtracting _$ControlProvisionExtractingFromJson(Map json) =>
    ControlProvisionExtracting($type: json['type'] as String?);

Map<String, dynamic> _$ControlProvisionExtractingToJson(
  ControlProvisionExtracting instance,
) => <String, dynamic>{'type': instance.$type};

ControlProvisionVerifying _$ControlProvisionVerifyingFromJson(Map json) =>
    ControlProvisionVerifying($type: json['type'] as String?);

Map<String, dynamic> _$ControlProvisionVerifyingToJson(
  ControlProvisionVerifying instance,
) => <String, dynamic>{'type': instance.$type};

ControlProvisionNotice _$ControlProvisionNoticeFromJson(Map json) =>
    ControlProvisionNotice(
      message: json['message'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ControlProvisionNoticeToJson(
  ControlProvisionNotice instance,
) => <String, dynamic>{'message': instance.message, 'type': instance.$type};

ControlProvisionReady _$ControlProvisionReadyFromJson(Map json) =>
    ControlProvisionReady(
      binaryPath: json['binaryPath'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ControlProvisionReadyToJson(
  ControlProvisionReady instance,
) => <String, dynamic>{
  'binaryPath': instance.binaryPath,
  'type': instance.$type,
};

ControlProvisionFailed _$ControlProvisionFailedFromJson(Map json) =>
    ControlProvisionFailed(
      message: json['message'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ControlProvisionFailedToJson(
  ControlProvisionFailed instance,
) => <String, dynamic>{'message': instance.message, 'type': instance.$type};
