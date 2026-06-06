// GENERATED FILE - DO NOT EDIT BY HAND

import 'mcpstatus.dart';

class MCPStatusConnected implements MCPStatus {
  const MCPStatusConnected({
    required this.status,
  });

  factory MCPStatusConnected.fromJson(Map<String, dynamic> json) {
    return MCPStatusConnected(
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
