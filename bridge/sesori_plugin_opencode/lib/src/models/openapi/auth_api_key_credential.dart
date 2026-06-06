// GENERATED FILE - DO NOT EDIT BY HAND

import 'auth_credential.dart';

class AuthApiKeyCredential implements AuthCredential {
  const AuthApiKeyCredential({
    required this.key,
    this.metadata,
  });

  factory AuthApiKeyCredential.fromJson(Map<String, dynamic> json) {
    return AuthApiKeyCredential(
      key: json["key"] as String,
      metadata: (json["metadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "api",
      "key": key,
      "metadata": metadata,
    };
  }

  final String key;
  final Map<String, String>? metadata;
}
