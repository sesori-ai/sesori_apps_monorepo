// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'integration_command_method.g.dart';
import 'integration_env_method.g.dart';
import 'integration_key_method.g.dart';
import 'integration_oauth_method.g.dart';

@immutable
abstract interface class IntegrationMethod {
  const IntegrationMethod();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory IntegrationMethod.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "oauth":
        return IntegrationOAuthMethod.fromJson(map);
      case "command":
        return IntegrationCommandMethod.fromJson(map);
      case "key":
        return IntegrationKeyMethod.fromJson(map);
      case "env":
        return IntegrationEnvMethod.fromJson(map);
      default:
        return IntegrationMethodUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [IntegrationMethod] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class IntegrationMethodUnknown implements IntegrationMethod {
  const IntegrationMethodUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationMethodUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
