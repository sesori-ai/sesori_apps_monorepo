// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.147155Z


class CommandV2Info {
  const CommandV2Info({
    required this.name,
    required this.template,
    this.description,
    this.agent,
    this.model,
    this.subtask,
  });

  factory CommandV2Info.fromJson(Map<String, dynamic> json) {
    return CommandV2Info(
      name: json["name"] as String,
      template: json["template"] as String,
      description: json["description"] as String?,
      agent: json["agent"] as String?,
      model: json["model"] as Map<String, dynamic>?,
      subtask: json["subtask"] as bool?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "template": template,
      "description": ?description,
      "agent": ?agent,
      "model": ?model,
      "subtask": ?subtask,
    };
  }

  final String name;
  final String template;
  final String? description;
  final String? agent;
  final Map<String, dynamic>? model;
  final bool? subtask;
}
