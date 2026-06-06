// GENERATED FILE - DO NOT EDIT BY HAND


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
