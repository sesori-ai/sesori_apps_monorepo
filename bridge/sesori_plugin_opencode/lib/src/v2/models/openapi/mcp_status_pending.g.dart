// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

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
