// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.911001Z

import 'package:meta/meta.dart';
import 'api_auth.dart';
import 'oauth.dart';
import 'well_known_auth.dart';

@immutable
abstract interface class Auth {
  const Auth();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory Auth.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "oauth":
        return OAuth.fromJson(map);
      case "api":
        return ApiAuth.fromJson(map);
      case "wellknown":
        return WellKnownAuth.fromJson(map);
      default:
        throw FormatException('Unknown Auth value: $discriminator');
    }
  }
}
