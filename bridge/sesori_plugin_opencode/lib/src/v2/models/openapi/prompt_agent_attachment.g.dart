// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'prompt_mention.g.dart';

@immutable
class PromptAgentAttachment {
  const PromptAgentAttachment({
    required this.name,
    required this.mention,
  });

  factory PromptAgentAttachment.fromJson(Map<String, dynamic> json) {
    return PromptAgentAttachment(
      name: json["name"] as String,
      mention: json["mention"] == null ? null : PromptMention.fromJson(json["mention"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "mention": ?mention?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PromptAgentAttachment copyWith({
    String? name,
    PromptMention? mention,
  }) {
    return PromptAgentAttachment(
      name: name ?? this.name,
      mention: mention ?? this.mention,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptAgentAttachment &&
          other.name == name &&
          other.mention == mention);

  @override
  int get hashCode => Object.hash(name, mention);

  final String name;
  final PromptMention? mention;
}
