// GENERATED FILE - DO NOT EDIT BY HAND

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
