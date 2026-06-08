// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.261999Z

import 'package:meta/meta.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VcsInfo &&
          other.branch == branch &&
          other.defaultBranch == defaultBranch);

  @override
  int get hashCode => Object.hash(branch, defaultBranch);

  final String? branch;
  final String? defaultBranch;
}
