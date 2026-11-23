// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

import 'package:meta/meta.dart';
import 'mcp_server_status.g.dart';

@immutable
class McpStatusPending implements McpServerStatus {
  const McpStatusPending();

  // ignore: avoid_unused_constructor_parameters
  factory McpStatusPending.fromJson(Map<String, dynamic> json) {
    return const McpStatusPending();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "pending",
    };
  }

}
