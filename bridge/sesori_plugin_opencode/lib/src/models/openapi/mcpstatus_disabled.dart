// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.660701Z

import 'mcpstatus.dart';

class MCPStatusDisabled implements MCPStatus {
  const MCPStatusDisabled();

  // ignore: avoid_unused_constructor_parameters
  factory MCPStatusDisabled.fromJson(Map<String, dynamic> json) {
    return const MCPStatusDisabled();
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "disabled",
    };
  }

}
