// GENERATED FILE - DO NOT EDIT BY HAND


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
      "description": description,
      "mimeType": mimeType,
      "client": client,
    };
  }

  final String name;
  final String uri;
  final String? description;
  final String? mimeType;
  final String client;
}
