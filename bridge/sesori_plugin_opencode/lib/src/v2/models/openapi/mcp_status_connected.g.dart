// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.2 (c0ad18b402eb2827fc1ee71c171b1177b3fc02d1)

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
