// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.636174Z


class Command {
  const Command({
    required this.name,
    this.description,
    this.agent,
    this.model,
    this.source,
    required this.template,
    this.subtask,
    required this.hints,
  });

  factory Command.fromJson(Map<String, dynamic> json) {
    return Command(
      name: json["name"] as String,
      description: json["description"] as String?,
      agent: json["agent"] as String?,
      model: json["model"] as String?,
      source: json["source"] as String?,
      template: json["template"] as String,
      subtask: json["subtask"] as bool?,
      hints: (json["hints"] as List<dynamic>).cast<String>(),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "description": description,
      "agent": agent,
      "model": model,
      "source": source,
      "template": template,
      "subtask": subtask,
      "hints": hints,
    };
  }

  final String name;
  final String? description;
  final String? agent;
  final String? model;
  final String? source;
  final String template;
  final bool? subtask;
  final List<String> hints;
}
