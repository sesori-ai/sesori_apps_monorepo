// GENERATED FILE - DO NOT EDIT BY HAND


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
