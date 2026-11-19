// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.2 (c0ad18b402eb2827fc1ee71c171b1177b3fc02d1)

import 'package:meta/meta.dart';
import 'mcp_server_status.g.dart';

@immutable
class McpStatusFailed implements McpServerStatus {
  const McpStatusFailed({
    required this.error,
  });

  factory McpStatusFailed.fromJson(Map<String, dynamic> json) {
    return McpStatusFailed(
      error: json["error"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "failed",
      "error": error,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  McpStatusFailed copyWith({
    String? error,
  }) {
    return McpStatusFailed(
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpStatusFailed &&
          other.error == error);

  @override
  int get hashCode => error.hashCode;

  final String error;
}
