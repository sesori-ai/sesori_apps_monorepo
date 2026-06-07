// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.656590Z

import 'file_part_source.dart';
import 'file_part_source_text.dart';

class FileSource implements FilePartSource {
  const FileSource({
    required this.text,
    required this.path,
  });

  factory FileSource.fromJson(Map<String, dynamic> json) {
    return FileSource(
      text: FilePartSourceText.fromJson(json["text"] as Map<String, dynamic>),
      path: json["path"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text.toJson(),
      "type": "file",
      "path": path,
    };
  }

  final FilePartSourceText text;
  final String path;
}
