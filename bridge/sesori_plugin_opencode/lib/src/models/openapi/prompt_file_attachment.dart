// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.239635Z

import 'package:meta/meta.dart';
import 'prompt_source.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptFileAttachment &&
          other.uri == uri &&
          other.mime == mime &&
          other.name == name &&
          other.description == description &&
          other.source == source);

  @override
  int get hashCode => Object.hash(uri, mime, name, description, source);

  final String uri;
  final String mime;
  final String? name;
  final String? description;
  final PromptSource? source;
}
