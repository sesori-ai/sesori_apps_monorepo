// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.2 (fc31a485317970bcf6be7b431a9830aaef875731)

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
