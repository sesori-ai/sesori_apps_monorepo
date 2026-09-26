// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'prompt_mention.g.dart';

@immutable
class PromptSkillAttachment {
  const PromptSkillAttachment({
    required this.id,
    required this.name,
    required this.text,
    required this.mention,
  });

  factory PromptSkillAttachment.fromJson(Map<String, dynamic> json) {
    return PromptSkillAttachment(
      id: json["id"] as String,
      name: json["name"] as String,
      text: json["text"] as String?,
      mention: json["mention"] == null ? null : PromptMention.fromJson(json["mention"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "text": ?text,
      "mention": ?mention?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PromptSkillAttachment copyWith({
    String? id,
    String? name,
    String? text,
    PromptMention? mention,
  }) {
    return PromptSkillAttachment(
      id: id ?? this.id,
      name: name ?? this.name,
      text: text ?? this.text,
      mention: mention ?? this.mention,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptSkillAttachment &&
          other.id == id &&
          other.name == name &&
          other.text == text &&
          other.mention == mention);

  @override
  int get hashCode => Object.hash(id, name, text, mention);

  final String id;
  final String name;
  final String? text;
  final PromptMention? mention;
}
