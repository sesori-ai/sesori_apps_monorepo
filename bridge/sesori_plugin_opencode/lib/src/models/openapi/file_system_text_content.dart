// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:39.987449Z


class FileSystemTextContent {
  const FileSystemTextContent({
    required this.type,
    required this.content,
    required this.mime,
  });

  factory FileSystemTextContent.fromJson(Map<String, dynamic> json) {
    return FileSystemTextContent(
      type: json["type"] as String,
      content: json["content"] as String,
      mime: json["mime"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "content": content,
      "mime": mime,
    };
  }

  final String type;
  final String content;
  final String mime;
}
