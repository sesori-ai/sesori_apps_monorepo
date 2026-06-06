// GENERATED FILE - DO NOT EDIT BY HAND

import 'mcpstatus.dart';

class MCPStatusNeedsClientRegistration implements MCPStatus {
  const MCPStatusNeedsClientRegistration({
    required this.status,
    required this.error,
  });

  factory MCPStatusNeedsClientRegistration.fromJson(Map<String, dynamic> json) {
    return MCPStatusNeedsClientRegistration(
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
