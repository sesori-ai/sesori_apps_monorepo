// GENERATED FILE - DO NOT EDIT BY HAND


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
      additions: json["additions"] as double,
      deletions: json["deletions"] as double,
      status: json["status"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "file": file,
      "patch": patch,
      "additions": additions,
      "deletions": deletions,
      "status": status,
    };
  }

  final String? file;
  final String? patch;
  final double additions;
  final double deletions;
  final String? status;
}
