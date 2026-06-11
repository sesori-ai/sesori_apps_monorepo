// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
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
      timeout: (json["timeout"] as num?)?.toInt(),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpRemoteConfig &&
          other.type == type &&
          other.url == url &&
          other.enabled == enabled &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          const DeepCollectionEquality().equals(other.oauth, oauth) &&
          other.timeout == timeout);

  @override
  int get hashCode => Object.hash(type, url, enabled, const DeepCollectionEquality().hash(headers), const DeepCollectionEquality().hash(oauth), timeout);

  final String type;
  final String url;
  final bool? enabled;
  final Map<String, String>? headers;
  final Object? oauth;
  final int? timeout;
}
