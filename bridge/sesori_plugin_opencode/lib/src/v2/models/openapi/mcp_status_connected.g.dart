// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:meta/meta.dart';

import 'mcp_server_status.g.dart';

@immutable
class McpStatusConnected implements McpServerStatus {
  const McpStatusConnected();

  // ignore: avoid_unused_constructor_parameters
  factory McpStatusConnected.fromJson(Map<String, dynamic> json) {
    return const McpStatusConnected();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "connected",
    };
  }
}
