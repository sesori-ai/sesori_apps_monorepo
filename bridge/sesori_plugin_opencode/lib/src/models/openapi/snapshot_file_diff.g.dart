// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

@immutable
class SnapshotFileDiff {
  const SnapshotFileDiff({
    required this.file,
    required this.patch,
    required this.additions,
    required this.deletions,
    required this.status,
  });

  factory SnapshotFileDiff.fromJson(Map<String, dynamic> json) {
    return SnapshotFileDiff(
      file: json["file"] as String?,
      patch: json["patch"] as String?,
      additions: (json["additions"] as num).toDouble(),
      deletions: (json["deletions"] as num).toDouble(),
      status: json["status"] == null ? null : SnapshotFileDiffStatus.fromJson(json["status"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "file": ?file,
      "patch": ?patch,
      "additions": additions,
      "deletions": deletions,
      "status": ?status?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SnapshotFileDiff copyWith({
    String? file,
    String? patch,
    double? additions,
    double? deletions,
    SnapshotFileDiffStatus? status,
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
  final SnapshotFileDiffStatus? status;
}

enum SnapshotFileDiffStatus {
  @JsonValue("added")
  added,
  @JsonValue("deleted")
  deleted,
  @JsonValue("modified")
  modified,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static SnapshotFileDiffStatus fromJson(String value) {
    switch (value) {
      case "added":
        return SnapshotFileDiffStatus.added;
      case "deleted":
        return SnapshotFileDiffStatus.deleted;
      case "modified":
        return SnapshotFileDiffStatus.modified;
      default:
        return SnapshotFileDiffStatus.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case SnapshotFileDiffStatus.added:
        return "added";
      case SnapshotFileDiffStatus.deleted:
        return "deleted";
      case SnapshotFileDiffStatus.modified:
        return "modified";
      case SnapshotFileDiffStatus.unknown:
        return 'unknown';
    }
  }
}
