// GENERATED FILE - DO NOT EDIT BY HAND

import 'api_auth.dart';
import 'oauth.dart';
import 'well_known_auth.dart';

abstract interface class Auth {
  const Auth();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

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
