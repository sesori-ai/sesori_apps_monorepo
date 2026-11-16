// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.0 (a6b15d33daf6ab7d35569f6d711fdb630b9f04e7)

import 'package:meta/meta.dart';
import 'mcp_server_status.g.dart';

@immutable
class McpStatusDisabled implements McpServerStatus {
  const McpStatusDisabled();

  // ignore: avoid_unused_constructor_parameters
  factory McpStatusDisabled.fromJson(Map<String, dynamic> json) {
    return const McpStatusDisabled();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "disabled",
    };
  }

}
