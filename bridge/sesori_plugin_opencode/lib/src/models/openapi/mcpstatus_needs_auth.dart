// GENERATED FILE - DO NOT EDIT BY HAND

import 'mcpstatus.dart';

class MCPStatusNeedsAuth implements MCPStatus {
  const MCPStatusNeedsAuth({
    required this.status,
  });

  factory MCPStatusNeedsAuth.fromJson(Map<String, dynamic> json) {
    return MCPStatusNeedsAuth(
      status: json["status"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
    };
  }

  final String status;
}
