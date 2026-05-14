import "package:freezed_annotation/freezed_annotation.dart";

part "auth_user.freezed.dart";
part "auth_user.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String id,
    required String provider,
    required String providerUserId,
    required String? providerUsername,
  }) = _AuthUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) => _$AuthUserFromJson(json);
}
