// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

@immutable
class FileDiffInfo {
  const FileDiffInfo({
    required this.file,
    required this.patch,
    required this.additions,
    required this.deletions,
    required this.status,
  });

  factory FileDiffInfo.fromJson(Map<String, dynamic> json) {
    return FileDiffInfo(
      file: json["file"] as String,
      patch: json["patch"] as String,
      additions: (json["additions"] as num).toInt(),
      deletions: (json["deletions"] as num).toInt(),
      status: FileDiffInfoStatus.fromJson(json["status"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "file": file,
      "patch": patch,
      "additions": additions,
      "deletions": deletions,
      "status": status.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FileDiffInfo copyWith({
    String? file,
    String? patch,
    int? additions,
    int? deletions,
    FileDiffInfoStatus? status,
  }) {
    return FileDiffInfo(
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
      (other is FileDiffInfo &&
          other.file == file &&
          other.patch == patch &&
          other.additions == additions &&
          other.deletions == deletions &&
          other.status == status);

  @override
  int get hashCode => Object.hash(file, patch, additions, deletions, status);

  final String file;
  final String patch;
  final int additions;
  final int deletions;
  final FileDiffInfoStatus status;
}

enum FileDiffInfoStatus {
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

  static FileDiffInfoStatus fromJson(String value) {
    switch (value) {
      case "added":
        return FileDiffInfoStatus.added;
      case "deleted":
        return FileDiffInfoStatus.deleted;
      case "modified":
        return FileDiffInfoStatus.modified;
      default:
        return FileDiffInfoStatus.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case FileDiffInfoStatus.added:
        return "added";
      case FileDiffInfoStatus.deleted:
        return "deleted";
      case FileDiffInfoStatus.modified:
        return "modified";
      case FileDiffInfoStatus.unknown:
        return 'unknown';
    }
  }
}
