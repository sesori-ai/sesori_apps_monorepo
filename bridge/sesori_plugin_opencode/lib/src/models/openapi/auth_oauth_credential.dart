// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.913801Z

import 'package:meta/meta.dart';
import 'auth_credential.dart';

@immutable
class AuthOAuthCredential implements AuthCredential {
  const AuthOAuthCredential({
    required this.refresh,
    required this.access,
    required this.expires,
  });

  factory AuthOAuthCredential.fromJson(Map<String, dynamic> json) {
    return AuthOAuthCredential(
      refresh: json["refresh"] as String,
      access: json["access"] as String,
      expires: (json["expires"] as num).toInt(),
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "oauth",
      "refresh": refresh,
      "access": access,
      "expires": expires,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthOAuthCredential &&
          other.refresh == refresh &&
          other.access == access &&
          other.expires == expires);

  @override
  int get hashCode => Object.hash(refresh, access, expires);

  final String refresh;
  final String access;
  final int expires;
}
