// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

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
