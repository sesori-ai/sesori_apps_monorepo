// GENERATED FILE - DO NOT EDIT BY HAND

import 'auth.dart';

class WellKnownAuth implements Auth {
  const WellKnownAuth({
    required this.type,
    required this.key,
    required this.token,
  });

  factory WellKnownAuth.fromJson(Map<String, dynamic> json) {
    return WellKnownAuth(
      type: json["type"] as String,
      key: json["key"] as String,
      token: json["token"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "key": key,
      "token": token,
    };
  }

  final String type;
  final String key;
  final String token;
}
