// GENERATED FILE - DO NOT EDIT BY HAND


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
