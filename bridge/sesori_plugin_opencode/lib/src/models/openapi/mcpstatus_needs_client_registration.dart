// GENERATED FILE - DO NOT EDIT BY HAND

import 'mcpstatus.dart';

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

  final String error;
}
