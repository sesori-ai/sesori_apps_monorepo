// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.939776Z

import 'package:meta/meta.dart';
import 'mcpstatus.dart';

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
