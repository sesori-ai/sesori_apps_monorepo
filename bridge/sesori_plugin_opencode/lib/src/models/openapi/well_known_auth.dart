// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.691737Z

import 'auth.dart';

class WellKnownAuth implements Auth {
  const WellKnownAuth({
    required this.key,
    required this.token,
  });

  factory WellKnownAuth.fromJson(Map<String, dynamic> json) {
    return WellKnownAuth(
      key: json["key"] as String,
      token: json["token"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "wellknown",
      "key": key,
      "token": token,
    };
  }

  final String key;
  final String token;
}
