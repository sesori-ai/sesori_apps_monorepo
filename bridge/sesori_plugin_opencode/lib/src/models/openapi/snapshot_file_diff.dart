// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.194836Z


class SnapshotFileDiff {
  const SnapshotFileDiff({
    this.file,
    this.patch,
    required this.additions,
    required this.deletions,
    this.status,
  });

  factory SnapshotFileDiff.fromJson(Map<String, dynamic> json) {
    return SnapshotFileDiff(
      file: json["file"] as String?,
      patch: json["patch"] as String?,
      additions: (json["additions"] as num).toDouble(),
      deletions: (json["deletions"] as num).toDouble(),
      status: json["status"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "file": ?file,
      "patch": ?patch,
      "additions": additions,
      "deletions": deletions,
      "status": ?status,
    };
  }

  final String? file;
  final String? patch;
  final double additions;
  final double deletions;
  final String? status;
}
