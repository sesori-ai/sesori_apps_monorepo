// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.202072Z

import 'package:meta/meta.dart';
import 'auth_api_key_credential.dart';
import 'auth_oauth_credential.dart';

@immutable
abstract interface class AuthCredential {
  const AuthCredential();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory AuthCredential.fromJson(Object json) {
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
