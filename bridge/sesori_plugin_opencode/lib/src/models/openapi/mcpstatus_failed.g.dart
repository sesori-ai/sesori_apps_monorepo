// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'mcpstatus.g.dart';

@immutable
class MCPStatusFailed implements MCPStatus {
  const MCPStatusFailed({
    required this.error,
  });

  factory MCPStatusFailed.fromJson(Map<String, dynamic> json) {
    return MCPStatusFailed(
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
  MCPStatusFailed copyWith({
    String? error,
  }) {
    return MCPStatusFailed(
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MCPStatusFailed &&
          other.error == error);

  @override
  int get hashCode => error.hashCode;

  final String error;
}
