// GENERATED FILE - DO NOT EDIT BY HAND

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
