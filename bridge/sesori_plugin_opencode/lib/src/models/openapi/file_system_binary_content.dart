// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:40:29.611760Z


class FileSystemBinaryContent {
  const FileSystemBinaryContent({
    required this.type,
    required this.content,
    required this.encoding,
    required this.mime,
  });

  factory FileSystemBinaryContent.fromJson(Map<String, dynamic> json) {
    return FileSystemBinaryContent(
      type: json["type"] as String,
      content: json["content"] as String,
      encoding: json["encoding"] as String,
      mime: json["mime"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "content": content,
      "encoding": encoding,
      "mime": mime,
    };
  }

  final String type;
  final String content;
  final String encoding;
  final String mime;
}
