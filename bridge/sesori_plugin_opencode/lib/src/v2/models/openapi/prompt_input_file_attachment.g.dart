// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:meta/meta.dart';

import 'prompt_file_source.g.dart';
import 'prompt_mention.g.dart';

@immutable
class PromptInputFileAttachment {
  const PromptInputFileAttachment({
    required this.uri,
    required this.source,
    required this.name,
    required this.description,
    required this.mention,
  });

  factory PromptInputFileAttachment.fromJson(Map<String, dynamic> json) {
    return PromptInputFileAttachment(
      uri: json["uri"] as String,
      source: json["source"] == null ? null : PromptFileSource.fromJson(json["source"] as Object),
      name: json["name"] as String?,
      description: json["description"] as String?,
      mention: json["mention"] == null ? null : PromptMention.fromJson(json["mention"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "uri": uri,
      "source": ?source?.toJson(),
      "name": ?name,
      "description": ?description,
      "mention": ?mention?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PromptInputFileAttachment copyWith({
    String? uri,
    PromptFileSource? source,
    String? name,
    String? description,
    PromptMention? mention,
  }) {
    return PromptInputFileAttachment(
      uri: uri ?? this.uri,
      source: source ?? this.source,
      name: name ?? this.name,
      description: description ?? this.description,
      mention: mention ?? this.mention,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptInputFileAttachment &&
          other.uri == uri &&
          other.source == source &&
          other.name == name &&
          other.description == description &&
          other.mention == mention);

  @override
  int get hashCode => Object.hash(uri, source, name, description, mention);

  final String uri;
  final PromptFileSource? source;
  final String? name;
  final String? description;
  final PromptMention? mention;
}
