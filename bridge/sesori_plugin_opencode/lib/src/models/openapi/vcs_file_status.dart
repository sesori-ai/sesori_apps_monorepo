// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.206636Z


class VcsFileStatus {
  const VcsFileStatus({
    required this.file,
    required this.additions,
    required this.deletions,
    required this.status,
  });

  factory VcsFileStatus.fromJson(Map<String, dynamic> json) {
    return VcsFileStatus(
      file: json["file"] as String,
      additions: (json["additions"] as num).toDouble(),
      deletions: (json["deletions"] as num).toDouble(),
      status: json["status"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "file": file,
      "additions": additions,
      "deletions": deletions,
      "status": status,
    };
  }

  final String file;
  final double additions;
  final double deletions;
  final String status;
}
