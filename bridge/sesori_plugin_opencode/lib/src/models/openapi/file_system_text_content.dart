// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.936929Z

import 'package:meta/meta.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileSystemTextContent &&
          other.type == type &&
          other.content == content &&
          other.mime == mime);

  @override
  int get hashCode => Object.hash(type, content, mime);

  final String type;
  final String content;
  final String mime;
}
