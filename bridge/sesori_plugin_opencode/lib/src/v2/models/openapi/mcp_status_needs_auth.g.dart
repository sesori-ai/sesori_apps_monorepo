// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

import 'package:meta/meta.dart';
import 'mcp_server_status.g.dart';

@immutable
class McpStatusNeedsAuth implements McpServerStatus {
  const McpStatusNeedsAuth({
    required this.error,
  });

  factory McpStatusNeedsAuth.fromJson(Map<String, dynamic> json) {
    return McpStatusNeedsAuth(
      error: json["error"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "needs_auth",
      "error": error,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  McpStatusNeedsAuth copyWith({
    String? error,
  }) {
    return McpStatusNeedsAuth(
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpStatusNeedsAuth &&
          other.error == error);

  @override
  int get hashCode => error.hashCode;

  final String error;
}
