// GENERATED FILE - DO NOT EDIT BY HAND

import 'auth.dart';

class OAuth implements Auth {
  const OAuth({
    required this.type,
    required this.refresh,
    required this.access,
    required this.expires,
    this.accountId,
    this.enterpriseUrl,
  });

  factory OAuth.fromJson(Map<String, dynamic> json) {
    return OAuth(
      type: json["type"] as String,
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
      "type": type,
      "refresh": refresh,
      "access": access,
      "expires": expires,
      "accountId": accountId,
      "enterpriseUrl": enterpriseUrl,
    };
  }

  final String type;
  final String refresh;
  final String access;
  final int expires;
  final String? accountId;
  final String? enterpriseUrl;
}
