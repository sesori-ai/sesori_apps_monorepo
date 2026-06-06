// GENERATED FILE - DO NOT EDIT BY HAND

import 'auth_credential.dart';

class AuthOAuthCredential implements AuthCredential {
  const AuthOAuthCredential({
    required this.type,
    required this.refresh,
    required this.access,
    required this.expires,
  });

  factory AuthOAuthCredential.fromJson(Map<String, dynamic> json) {
    return AuthOAuthCredential(
      type: json["type"] as String,
      refresh: json["refresh"] as String,
      access: json["access"] as String,
      expires: json["expires"] as int,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "refresh": refresh,
      "access": access,
      "expires": expires,
    };
  }

  final String type;
  final String refresh;
  final String access;
  final int expires;
}
