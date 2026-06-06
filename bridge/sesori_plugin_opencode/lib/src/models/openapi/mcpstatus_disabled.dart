// GENERATED FILE - DO NOT EDIT BY HAND

import 'mcpstatus.dart';

class MCPStatusDisabled implements MCPStatus {
  const MCPStatusDisabled({
    required this.status,
  });

  factory MCPStatusDisabled.fromJson(Map<String, dynamic> json) {
    return MCPStatusDisabled(
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
