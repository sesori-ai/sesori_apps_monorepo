// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:40:29.649040Z


class WorktreeCreateInput {
  const WorktreeCreateInput({
    this.name,
    this.startCommand,
  });

  factory WorktreeCreateInput.fromJson(Map<String, dynamic> json) {
    return WorktreeCreateInput(
      name: json["name"] as String?,
      startCommand: json["startCommand"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": ?name,
      "startCommand": ?startCommand,
    };
  }

  final String? name;
  final String? startCommand;
}
