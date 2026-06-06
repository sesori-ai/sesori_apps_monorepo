// GENERATED FILE - DO NOT EDIT BY HAND

import 'api_auth.dart';
import 'oauth.dart';
import 'well_known_auth.dart';

abstract interface class Auth {
  const Auth();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory Auth.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      case "oauth":
        return OAuth.fromJson(json);
      case "api":
        return ApiAuth.fromJson(json);
      case "wellknown":
        return WellKnownAuth.fromJson(json);
      default:
        throw FormatException('Unknown Auth value: $discriminator');
    }
  }
}
