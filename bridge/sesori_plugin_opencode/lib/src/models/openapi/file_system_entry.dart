// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.970017Z

import 'package:meta/meta.dart';

@immutable
class FileSystemEntry {
  const FileSystemEntry({
    required this.path,
    required this.uri,
    required this.type,
    required this.mime,
  });

  factory FileSystemEntry.fromJson(Map<String, dynamic> json) {
    return FileSystemEntry(
      path: json["path"] as String,
      uri: json["uri"] as String,
      type: json["type"] as String,
      mime: json["mime"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "path": path,
      "uri": uri,
      "type": type,
      "mime": mime,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileSystemEntry &&
          other.path == path &&
          other.uri == uri &&
          other.type == type &&
          other.mime == mime);

  @override
  int get hashCode => Object.hash(path, uri, type, mime);

  final String path;
  final String uri;
  final String type;
  final String mime;
}
