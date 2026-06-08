// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.229191Z

import 'package:meta/meta.dart';
import 'mcpstatus_connected.dart';
import 'mcpstatus_disabled.dart';
import 'mcpstatus_failed.dart';
import 'mcpstatus_needs_auth.dart';
import 'mcpstatus_needs_client_registration.dart';

@immutable
abstract interface class MCPStatus {
  const MCPStatus();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory MCPStatus.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["status"];
    switch (discriminator) {
      case "connected":
        return MCPStatusConnected.fromJson(map);
      case "disabled":
        return MCPStatusDisabled.fromJson(map);
      case "failed":
        return MCPStatusFailed.fromJson(map);
      case "needs_auth":
        return MCPStatusNeedsAuth.fromJson(map);
      case "needs_client_registration":
        return MCPStatusNeedsClientRegistration.fromJson(map);
      default:
        throw FormatException('Unknown MCPStatus value: $discriminator');
    }
  }
}
