// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.693017Z


class WorktreeResetInput {
  const WorktreeResetInput({
    required this.directory,
  });

  factory WorktreeResetInput.fromJson(Map<String, dynamic> json) {
    return WorktreeResetInput(
      directory: json["directory"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
    };
  }

  final String directory;
}
