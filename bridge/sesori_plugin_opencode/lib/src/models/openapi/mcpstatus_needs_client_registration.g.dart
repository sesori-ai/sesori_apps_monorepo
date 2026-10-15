// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'mcpstatus.g.dart';

@immutable
class MCPStatusNeedsClientRegistration implements MCPStatus {
  const MCPStatusNeedsClientRegistration({
    required this.error,
  });

  factory MCPStatusNeedsClientRegistration.fromJson(Map<String, dynamic> json) {
    return MCPStatusNeedsClientRegistration(
      error: json["error"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "needs_client_registration",
      "error": error,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  MCPStatusNeedsClientRegistration copyWith({
    String? error,
  }) {
    return MCPStatusNeedsClientRegistration(
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MCPStatusNeedsClientRegistration &&
          other.error == error);

  @override
  int get hashCode => error.hashCode;

  final String error;
}
