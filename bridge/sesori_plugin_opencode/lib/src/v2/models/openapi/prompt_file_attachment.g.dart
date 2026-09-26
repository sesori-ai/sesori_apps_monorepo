// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';
import 'prompt_file_source.g.dart';
import 'prompt_mention.g.dart';

@immutable
class PromptFileAttachment {
  const PromptFileAttachment({
    required this.data,
    required this.mime,
    required this.source,
    required this.name,
    required this.description,
    required this.mention,
  });

  factory PromptFileAttachment.fromJson(Map<String, dynamic> json) {
    return PromptFileAttachment(
      data: json["data"] as String,
      mime: json["mime"] as String,
      source: PromptFileSource.fromJson(json["source"] as Object),
      name: json["name"] as String?,
      description: json["description"] as String?,
      mention: json["mention"] == null ? null : PromptMention.fromJson(json["mention"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "data": data,
      "mime": mime,
      "source": source.toJson(),
      "name": ?name,
      "description": ?description,
      "mention": ?mention?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PromptFileAttachment copyWith({
    String? data,
    String? mime,
    PromptFileSource? source,
    String? name,
    String? description,
    PromptMention? mention,
  }) {
    return PromptFileAttachment(
      data: data ?? this.data,
      mime: mime ?? this.mime,
      source: source ?? this.source,
      name: name ?? this.name,
      description: description ?? this.description,
      mention: mention ?? this.mention,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptFileAttachment &&
          other.data == data &&
          other.mime == mime &&
          other.source == source &&
          other.name == name &&
          other.description == description &&
          other.mention == mention);

  @override
  int get hashCode => Object.hash(data, mime, source, name, description, mention);

  final String data;
  final String mime;
  final PromptFileSource source;
  final String? name;
  final String? description;
  final PromptMention? mention;
}
