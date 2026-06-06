// GENERATED FILE - DO NOT EDIT BY HAND


class VcsInfo {
  const VcsInfo({
    this.branch,
    this.defaultBranch,
  });

  factory VcsInfo.fromJson(Map<String, dynamic> json) {
    return VcsInfo(
      branch: json["branch"] as String?,
      defaultBranch: json["default_branch"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "branch": branch,
      "default_branch": defaultBranch,
    };
  }

  final String? branch;
  final String? defaultBranch;
}
