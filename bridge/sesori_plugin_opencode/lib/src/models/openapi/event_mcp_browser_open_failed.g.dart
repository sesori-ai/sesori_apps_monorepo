// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventMcpBrowserOpenFailed implements Event {
  const EventMcpBrowserOpenFailed({
    this.id = '',
    required this.properties,
  });

  factory EventMcpBrowserOpenFailed.fromJson(Map<String, dynamic> json) {
    return EventMcpBrowserOpenFailed(
      id: (json["id"] ?? '') as String,
      properties: EventMcpBrowserOpenFailedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "mcp.browser.open.failed",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMcpBrowserOpenFailed copyWith({
    String? id,
    EventMcpBrowserOpenFailedProperties? properties,
  }) {
    return EventMcpBrowserOpenFailed(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMcpBrowserOpenFailed &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventMcpBrowserOpenFailedProperties properties;
}

@immutable
class EventMcpBrowserOpenFailedProperties {
  const EventMcpBrowserOpenFailedProperties({
    this.mcpName = '',
    this.url = '',
  });

  factory EventMcpBrowserOpenFailedProperties.fromJson(Map<String, dynamic> json) {
    return EventMcpBrowserOpenFailedProperties(
      mcpName: (json["mcpName"] ?? '') as String,
      url: (json["url"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "mcpName": mcpName,
      "url": url,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMcpBrowserOpenFailedProperties copyWith({
    String? mcpName,
    String? url,
  }) {
    return EventMcpBrowserOpenFailedProperties(
      mcpName: mcpName ?? this.mcpName,
      url: url ?? this.url,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMcpBrowserOpenFailedProperties &&
          other.mcpName == mcpName &&
          other.url == url);

  @override
  int get hashCode => Object.hash(mcpName, url);

  final String mcpName;
  final String url;
}
