// GENERATED FILE - DO NOT EDIT BY HAND

import 'file_part_source.dart';
import 'file_part_source_text.dart';

class FileSource implements FilePartSource {
  const FileSource({
    required this.text,
    required this.type,
    required this.path,
  });

  factory FileSource.fromJson(Map<String, dynamic> json) {
    return FileSource(
      text: FilePartSourceText.fromJson(json["text"] as Map<String, dynamic>),
      type: json["type"] as String,
      path: json["path"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text.toJson(),
      "type": type,
      "path": path,
    };
  }

  final FilePartSourceText text;
  final String type;
  final String path;
}
