// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.879045Z

import 'api_auth.dart';
import 'oauth.dart';
import 'well_known_auth.dart';

abstract interface class Auth {
  const Auth();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `dynamic` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `dynamic`.
  dynamic toJson();

  factory Auth.fromJson(dynamic json) {
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
