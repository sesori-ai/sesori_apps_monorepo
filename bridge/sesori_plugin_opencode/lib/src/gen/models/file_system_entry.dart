// GENERATED FILE - DO NOT EDIT BY HAND


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
