// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.974019Z

import 'package:meta/meta.dart';
import 'mcpstatus.dart';

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MCPStatusNeedsClientRegistration &&
          other.error == error);

  @override
  int get hashCode => error.hashCode;

  final String error;
}
