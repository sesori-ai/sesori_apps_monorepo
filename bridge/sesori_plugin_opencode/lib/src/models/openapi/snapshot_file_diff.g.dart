// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SnapshotFileDiff {
  const SnapshotFileDiff({
    this.file,
    this.patch,
    this.additions = 0,
    this.deletions = 0,
    this.status,
  });

  factory SnapshotFileDiff.fromJson(Map<String, dynamic> json) {
    return SnapshotFileDiff(
      file: json["file"] as String?,
      patch: json["patch"] as String?,
      additions: ((json["additions"] ?? 0) as num).toDouble(),
      deletions: ((json["deletions"] ?? 0) as num).toDouble(),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SnapshotFileDiff copyWith({
    String? file,
    String? patch,
    double? additions,
    double? deletions,
    String? status,
  }) {
    return SnapshotFileDiff(
      file: file ?? this.file,
      patch: patch ?? this.patch,
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotFileDiff &&
          other.file == file &&
          other.patch == patch &&
          other.additions == additions &&
          other.deletions == deletions &&
          other.status == status);

  @override
  int get hashCode => Object.hash(file, patch, additions, deletions, status);

  final String? file;
  final String? patch;
  final double additions;
  final double deletions;
  final String? status;
}
