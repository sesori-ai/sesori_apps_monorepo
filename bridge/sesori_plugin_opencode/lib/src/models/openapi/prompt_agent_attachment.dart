// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.670450Z

import 'prompt_source.dart';

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
      "source": source?.toJson(),
    };
  }

  final String name;
  final PromptSource? source;
}
