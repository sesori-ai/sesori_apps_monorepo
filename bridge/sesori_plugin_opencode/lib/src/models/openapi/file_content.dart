// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.025916Z


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
      "diff": ?diff,
      "patch": ?patch,
      "encoding": ?encoding,
      "mimeType": ?mimeType,
    };
  }

  final String type;
  final String content;
  final String? diff;
  final Map<String, dynamic>? patch;
  final String? encoding;
  final String? mimeType;
}
