// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.976702Z

import 'package:meta/meta.dart';
import 'auth.dart';

@immutable
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
      expires: (json["expires"] as num).toInt(),
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
      "accountId": ?accountId,
      "enterpriseUrl": ?enterpriseUrl,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OAuth &&
          other.refresh == refresh &&
          other.access == access &&
          other.expires == expires &&
          other.accountId == accountId &&
          other.enterpriseUrl == enterpriseUrl);

  @override
  int get hashCode => Object.hash(refresh, access, expires, accountId, enterpriseUrl);

  final String refresh;
  final String access;
  final int expires;
  final String? accountId;
  final String? enterpriseUrl;
}
