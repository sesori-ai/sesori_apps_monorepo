// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';
import 'prompt_mention.g.dart';

@immutable
class PromptInputFileAttachment {
  const PromptInputFileAttachment({
    required this.uri,
    required this.name,
    required this.description,
    required this.mention,
  });

  factory PromptInputFileAttachment.fromJson(Map<String, dynamic> json) {
    return PromptInputFileAttachment(
      uri: json["uri"] as String,
      name: json["name"] as String?,
      description: json["description"] as String?,
      mention: json["mention"] == null ? null : PromptMention.fromJson(json["mention"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "uri": uri,
      "name": ?name,
      "description": ?description,
      "mention": ?mention?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PromptInputFileAttachment copyWith({
    String? uri,
    String? name,
    String? description,
    PromptMention? mention,
  }) {
    return PromptInputFileAttachment(
      uri: uri ?? this.uri,
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
          other.name == name &&
          other.description == description &&
          other.mention == mention);

  @override
  int get hashCode => Object.hash(uri, name, description, mention);

  final String uri;
  final String? name;
  final String? description;
  final PromptMention? mention;
}
