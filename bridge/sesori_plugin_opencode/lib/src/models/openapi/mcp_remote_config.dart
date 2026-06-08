// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.905184Z


class McpRemoteConfig {
  const McpRemoteConfig({
    required this.type,
    required this.url,
    this.enabled,
    this.headers,
    this.oauth,
    this.timeout,
  });

  factory McpRemoteConfig.fromJson(Map<String, dynamic> json) {
    return McpRemoteConfig(
      type: json["type"] as String,
      url: json["url"] as String,
      enabled: json["enabled"] as bool?,
      headers: (json["headers"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
      oauth: json["oauth"] as Object?,
      timeout: json["timeout"] as int?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "url": url,
      "enabled": ?enabled,
      "headers": ?headers,
      "oauth": ?oauth,
      "timeout": ?timeout,
    };
  }

  final String type;
  final String url;
  final bool? enabled;
  final Map<String, String>? headers;
  final Object? oauth;
  final int? timeout;
}
