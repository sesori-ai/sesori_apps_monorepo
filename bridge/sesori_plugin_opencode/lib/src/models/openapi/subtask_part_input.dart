// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.196027Z


class SubtaskPartInput {
  const SubtaskPartInput({
    this.id,
    required this.type,
    required this.prompt,
    required this.description,
    required this.agent,
    this.model,
    this.command,
  });

  factory SubtaskPartInput.fromJson(Map<String, dynamic> json) {
    return SubtaskPartInput(
      id: json["id"] as String?,
      type: json["type"] as String,
      prompt: json["prompt"] as String,
      description: json["description"] as String,
      agent: json["agent"] as String,
      model: json["model"] as Map<String, dynamic>?,
      command: json["command"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": ?id,
      "type": type,
      "prompt": prompt,
      "description": description,
      "agent": agent,
      "model": ?model,
      "command": ?command,
    };
  }

  final String? id;
  final String type;
  final String prompt;
  final String description;
  final String agent;
  final Map<String, dynamic>? model;
  final String? command;
}
