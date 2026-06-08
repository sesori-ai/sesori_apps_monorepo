// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.036265Z


class MoveSessionDestination {
  const MoveSessionDestination({
    required this.directory,
  });

  factory MoveSessionDestination.fromJson(Map<String, dynamic> json) {
    return MoveSessionDestination(
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
