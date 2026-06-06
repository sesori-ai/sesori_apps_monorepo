// GENERATED FILE - DO NOT EDIT BY HAND

import 'mcpstatus_connected.dart';
import 'mcpstatus_disabled.dart';
import 'mcpstatus_failed.dart';
import 'mcpstatus_needs_auth.dart';
import 'mcpstatus_needs_client_registration.dart';

abstract interface class MCPStatus {
  const MCPStatus();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory MCPStatus.fromJson(dynamic json) {
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
