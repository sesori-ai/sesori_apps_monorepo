// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.044203Z

import 'prompt_source.dart';

class PromptFileAttachment {
  const PromptFileAttachment({
    required this.uri,
    required this.mime,
    this.name,
    this.description,
    this.source,
  });

  factory PromptFileAttachment.fromJson(Map<String, dynamic> json) {
    return PromptFileAttachment(
      uri: json["uri"] as String,
      mime: json["mime"] as String,
      name: json["name"] as String?,
      description: json["description"] as String?,
      source: json["source"] == null ? null : PromptSource.fromJson(json["source"] as Map<String, dynamic>),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "uri": uri,
      "mime": mime,
      "name": ?name,
      "description": ?description,
      "source": ?source?.toJson(),
    };
  }

  final String uri;
  final String mime;
  final String? name;
  final String? description;
  final PromptSource? source;
}
