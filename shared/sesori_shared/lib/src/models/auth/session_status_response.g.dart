// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_status_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthSessionStatusResponsePending _$AuthSessionStatusResponsePendingFromJson(
  Map json,
) => AuthSessionStatusResponsePending($type: json['status'] as String?);

Map<String, dynamic> _$AuthSessionStatusResponsePendingToJson(
  AuthSessionStatusResponsePending instance,
) => <String, dynamic>{'status': instance.$type};

AuthSessionStatusResponseComplete _$AuthSessionStatusResponseCompleteFromJson(
  Map json,
) => AuthSessionStatusResponseComplete(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
  user: AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
  accountStatus: $enumDecode(
    _$AccountStatusEnumMap,
    json['accountStatus'],
    unknownValue: AccountStatus.unknown,
  ),
  $type: json['status'] as String?,
);

Map<String, dynamic> _$AuthSessionStatusResponseCompleteToJson(
  AuthSessionStatusResponseComplete instance,
) => <String, dynamic>{
  'accessToken': instance.accessToken,
  'refreshToken': instance.refreshToken,
  'user': instance.user.toJson(),
  'accountStatus': _$AccountStatusEnumMap[instance.accountStatus]!,
  'status': instance.$type,
};

const _$AccountStatusEnumMap = {
  AccountStatus.created: 'created',
  AccountStatus.existing: 'existing',
  AccountStatus.unknown: 'unknown',
};

AuthSessionStatusResponseDenied _$AuthSessionStatusResponseDeniedFromJson(
  Map json,
) => AuthSessionStatusResponseDenied($type: json['status'] as String?);

Map<String, dynamic> _$AuthSessionStatusResponseDeniedToJson(
  AuthSessionStatusResponseDenied instance,
) => <String, dynamic>{'status': instance.$type};

AuthSessionStatusResponseExpired _$AuthSessionStatusResponseExpiredFromJson(
  Map json,
) => AuthSessionStatusResponseExpired($type: json['status'] as String?);

Map<String, dynamic> _$AuthSessionStatusResponseExpiredToJson(
  AuthSessionStatusResponseExpired instance,
) => <String, dynamic>{'status': instance.$type};

AuthSessionStatusResponseError _$AuthSessionStatusResponseErrorFromJson(
  Map json,
) => AuthSessionStatusResponseError(
  message: json['message'] as String,
  $type: json['status'] as String?,
);

Map<String, dynamic> _$AuthSessionStatusResponseErrorToJson(
  AuthSessionStatusResponseError instance,
) => <String, dynamic>{'message': instance.message, 'status': instance.$type};
