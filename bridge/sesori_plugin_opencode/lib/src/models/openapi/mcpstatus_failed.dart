// GENERATED FILE - DO NOT EDIT BY HAND

import 'mcpstatus.dart';

class MCPStatusFailed implements MCPStatus {
  const MCPStatusFailed({
    required this.status,
    required this.error,
  });

  factory MCPStatusFailed.fromJson(Map<String, dynamic> json) {
    return MCPStatusFailed(
      status: json["status"] as String,
      error: json["error"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "error": error,
    };
  }

  final String status;
  final String error;
}
