// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.974263Z

import 'package:meta/meta.dart';

@immutable
class McpLocalConfig {
  const McpLocalConfig({
    required this.type,
    required this.command,
    this.environment,
    this.enabled,
    this.timeout,
  });

  factory McpLocalConfig.fromJson(Map<String, dynamic> json) {
    return McpLocalConfig(
      type: json["type"] as String,
      command: (json["command"] as List<dynamic>).cast<String>(),
      environment: (json["environment"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
      enabled: json["enabled"] as bool?,
      timeout: (json["timeout"] as num?)?.toInt(),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "command": command,
      "environment": ?environment,
      "enabled": ?enabled,
      "timeout": ?timeout,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpLocalConfig &&
          other.type == type &&
          other.command == command &&
          other.environment == environment &&
          other.enabled == enabled &&
          other.timeout == timeout);

  @override
  int get hashCode => Object.hash(type, command, environment, enabled, timeout);

  final String type;
  final List<String> command;
  final Map<String, String>? environment;
  final bool? enabled;
  final int? timeout;
}
