// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.974832Z

import 'package:meta/meta.dart';

@immutable
class McpResource {
  const McpResource({
    required this.name,
    required this.uri,
    this.description,
    this.mimeType,
    required this.client,
  });

  factory McpResource.fromJson(Map<String, dynamic> json) {
    return McpResource(
      name: json["name"] as String,
      uri: json["uri"] as String,
      description: json["description"] as String?,
      mimeType: json["mimeType"] as String?,
      client: json["client"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "uri": uri,
      "description": ?description,
      "mimeType": ?mimeType,
      "client": client,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpResource &&
          other.name == name &&
          other.uri == uri &&
          other.description == description &&
          other.mimeType == mimeType &&
          other.client == client);

  @override
  int get hashCode => Object.hash(name, uri, description, mimeType, client);

  final String name;
  final String uri;
  final String? description;
  final String? mimeType;
  final String client;
}
