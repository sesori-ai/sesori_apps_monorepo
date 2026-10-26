// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'mcp_status_connected.g.dart';
import 'mcp_status_disabled.g.dart';
import 'mcp_status_failed.g.dart';
import 'mcp_status_needs_auth.g.dart';
import 'mcp_status_pending.g.dart';

@immutable
abstract interface class McpServerStatus {
  const McpServerStatus();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory McpServerStatus.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["status"];
    switch (discriminator) {
      case "connected":
        return McpStatusConnected.fromJson(map);
      case "pending":
        return McpStatusPending.fromJson(map);
      case "disabled":
        return McpStatusDisabled.fromJson(map);
      case "failed":
        return McpStatusFailed.fromJson(map);
      case "needs_auth":
        return McpStatusNeedsAuth.fromJson(map);
      default:
        return McpServerStatusUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [McpServerStatus] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class McpServerStatusUnknown implements McpServerStatus {
  const McpServerStatusUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpServerStatusUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
