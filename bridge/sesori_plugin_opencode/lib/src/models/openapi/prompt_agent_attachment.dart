// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.951183Z

import 'package:meta/meta.dart';
import 'prompt_source.dart';

@immutable
class PromptAgentAttachment {
  const PromptAgentAttachment({
    required this.name,
    this.source,
  });

  factory PromptAgentAttachment.fromJson(Map<String, dynamic> json) {
    return PromptAgentAttachment(
      name: json["name"] as String,
      source: json["source"] == null ? null : PromptSource.fromJson(json["source"] as Map<String, dynamic>),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "source": ?source?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptAgentAttachment &&
          other.name == name &&
          other.source == source);

  @override
  int get hashCode => Object.hash(name, source);

  final String name;
  final PromptSource? source;
}
