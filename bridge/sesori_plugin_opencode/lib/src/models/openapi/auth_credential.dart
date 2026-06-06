// GENERATED FILE - DO NOT EDIT BY HAND

import 'auth_api_key_credential.dart';
import 'auth_oauth_credential.dart';

abstract interface class AuthCredential {
  const AuthCredential();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory AuthCredential.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "oauth":
        return AuthOAuthCredential.fromJson(map);
      case "api":
        return AuthApiKeyCredential.fromJson(map);
      default:
        throw FormatException('Unknown AuthCredential value: $discriminator');
    }
  }
}
