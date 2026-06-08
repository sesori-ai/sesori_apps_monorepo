// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:39.987293Z


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

  final String path;
  final String uri;
  final String type;
  final String mime;
}
