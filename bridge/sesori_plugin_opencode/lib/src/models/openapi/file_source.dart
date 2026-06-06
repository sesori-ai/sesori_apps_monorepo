// GENERATED FILE - DO NOT EDIT BY HAND

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
