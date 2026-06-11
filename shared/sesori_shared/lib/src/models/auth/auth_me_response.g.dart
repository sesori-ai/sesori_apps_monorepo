// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_me_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthMeResponse _$AuthMeResponseFromJson(Map json) => _AuthMeResponse(
  user: AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
  bridges: (json['bridges'] as List<dynamic>)
      .map((e) => BridgeSummary.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
);
