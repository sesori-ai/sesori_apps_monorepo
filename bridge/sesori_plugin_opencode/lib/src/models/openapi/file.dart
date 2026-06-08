// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.224409Z

import 'package:meta/meta.dart';

@immutable
class File {
  const File({
    required this.path,
    required this.added,
    required this.removed,
    required this.status,
  });

  factory File.fromJson(Map<String, dynamic> json) {
    return File(
      path: json["path"] as String,
      added: (json["added"] as num).toInt(),
      removed: (json["removed"] as num).toInt(),
      status: json["status"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "path": path,
      "added": added,
      "removed": removed,
      "status": status,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is File &&
          other.path == path &&
          other.added == added &&
          other.removed == removed &&
          other.status == status);

  @override
  int get hashCode => Object.hash(path, added, removed, status);

  final String path;
  final int added;
  final int removed;
  final String status;
}
