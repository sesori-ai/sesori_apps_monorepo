// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:40:29.616021Z

import 'mcpstatus.dart';

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

  final String error;
}
