// GENERATED FILE - DO NOT EDIT BY HAND


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
      oauth: json["oauth"],
      timeout: json["timeout"] as int?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "url": url,
      "enabled": enabled,
      "headers": headers,
      "oauth": oauth,
      "timeout": timeout,
    };
  }

  final String type;
  final String url;
  final bool? enabled;
  final Map<String, String>? headers;
  final dynamic oauth;
  final int? timeout;
}
