// GENERATED FILE - DO NOT EDIT BY HAND

import 'auth.dart';

class OAuth implements Auth {
  const OAuth({
    required this.refresh,
    required this.access,
    required this.expires,
    this.accountId,
    this.enterpriseUrl,
  });

  factory OAuth.fromJson(Map<String, dynamic> json) {
    return OAuth(
      refresh: json["refresh"] as String,
      access: json["access"] as String,
      expires: json["expires"] as int,
      accountId: json["accountId"] as String?,
      enterpriseUrl: json["enterpriseUrl"] as String?,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "oauth",
      "refresh": refresh,
      "access": access,
      "expires": expires,
      "accountId": accountId,
      "enterpriseUrl": enterpriseUrl,
    };
  }

  final String refresh;
  final String access;
  final int expires;
  final String? accountId;
  final String? enterpriseUrl;
}
