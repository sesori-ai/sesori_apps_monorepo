// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'mcpstatus.g.dart';

@immutable
class MCPStatusConnected implements MCPStatus {
  const MCPStatusConnected();

  // ignore: avoid_unused_constructor_parameters
  factory MCPStatusConnected.fromJson(Map<String, dynamic> json) {
    return const MCPStatusConnected();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "connected",
    };
  }

}
