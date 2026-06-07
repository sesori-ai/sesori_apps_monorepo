// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.662091Z


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
      timeout: json["timeout"] as int?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "command": command,
      "environment": environment,
      "enabled": enabled,
      "timeout": timeout,
    };
  }

  final String type;
  final List<String> command;
  final Map<String, String>? environment;
  final bool? enabled;
  final int? timeout;
}
