// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.363573Z


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
      "branch": ?branch,
      "default_branch": ?defaultBranch,
    };
  }

  final String? branch;
  final String? defaultBranch;
}
