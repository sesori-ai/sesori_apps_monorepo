// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'prompt_mention.g.dart';

@immutable
class PromptInputSkillAttachment {
  const PromptInputSkillAttachment({
    required this.id,
    required this.mention,
  });

  factory PromptInputSkillAttachment.fromJson(Map<String, dynamic> json) {
    return PromptInputSkillAttachment(
      id: json["id"] as String,
      mention: json["mention"] == null ? null : PromptMention.fromJson(json["mention"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "mention": ?mention?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PromptInputSkillAttachment copyWith({
    String? id,
    PromptMention? mention,
  }) {
    return PromptInputSkillAttachment(
      id: id ?? this.id,
      mention: mention ?? this.mention,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptInputSkillAttachment &&
          other.id == id &&
          other.mention == mention);

  @override
  int get hashCode => Object.hash(id, mention);

  final String id;
  final PromptMention? mention;
}
