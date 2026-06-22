// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthUser _$AuthUserFromJson(Map json) => _AuthUser(
  id: json['id'] as String,
  provider: authProviderConverter.fromJson(json['provider'] as String),
  providerUserId: json['providerUserId'] as String,
  providerUsername: json['providerUsername'] as String?,
);

Map<String, dynamic> _$AuthUserToJson(_AuthUser instance) => <String, dynamic>{
  'id': instance.id,
  'provider': authProviderConverter.toJson(instance.provider),
  'providerUserId': instance.providerUserId,
  'providerUsername': ?instance.providerUsername,
};
