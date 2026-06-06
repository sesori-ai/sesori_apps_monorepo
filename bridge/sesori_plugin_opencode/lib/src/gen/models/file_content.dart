// GENERATED FILE - DO NOT EDIT BY HAND


class FileContent {
  const FileContent({
    required this.type,
    required this.content,
    this.diff,
    this.patch,
    this.encoding,
    this.mimeType,
  });

  factory FileContent.fromJson(Map<String, dynamic> json) {
    return FileContent(
      type: json["type"] as String,
      content: json["content"] as String,
      diff: json["diff"] as String?,
      patch: json["patch"] as Map<String, dynamic>?,
      encoding: json["encoding"] as String?,
      mimeType: json["mimeType"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "content": content,
      "diff": diff,
      "patch": patch,
      "encoding": encoding,
      "mimeType": mimeType,
    };
  }

  final String type;
  final String content;
  final String? diff;
  final Map<String, dynamic>? patch;
  final String? encoding;
  final String? mimeType;
}
