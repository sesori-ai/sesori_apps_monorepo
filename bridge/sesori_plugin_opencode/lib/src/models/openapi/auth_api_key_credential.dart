// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.200702Z

import 'package:meta/meta.dart';
import 'auth_credential.dart';

@immutable
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
      "metadata": ?metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthApiKeyCredential &&
          other.key == key &&
          other.metadata == metadata);

  @override
  int get hashCode => Object.hash(key, metadata);

  final String key;
  final Map<String, String>? metadata;
}
