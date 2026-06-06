// GENERATED FILE - DO NOT EDIT BY HAND

import 'auth_api_key_credential.dart';
import 'auth_oauth_credential.dart';

abstract interface class AuthCredential {
  const AuthCredential();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory AuthCredential.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      case "oauth":
        return AuthOAuthCredential.fromJson(json);
      case "api":
        return AuthApiKeyCredential.fromJson(json);
      default:
        throw FormatException('Unknown AuthCredential value: $discriminator');
    }
  }
}
