// GENERATED FILE - DO NOT EDIT BY HAND


class VcsFileDiff {
  const VcsFileDiff({
    required this.file,
    this.patch,
    required this.additions,
    required this.deletions,
    this.status,
  });

  factory VcsFileDiff.fromJson(Map<String, dynamic> json) {
    return VcsFileDiff(
      file: json["file"] as String,
      patch: json["patch"] as String?,
      additions: (json["additions"] as num).toDouble(),
      deletions: (json["deletions"] as num).toDouble(),
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

  final String file;
  final String? patch;
  final double additions;
  final double deletions;
  final String? status;
}
