// GENERATED FILE - DO NOT EDIT BY HAND

import 'file_part_source.dart';

class FilePartInput {
  const FilePartInput({
    this.id,
    required this.type,
    required this.mime,
    this.filename,
    required this.url,
    this.source,
  });

  factory FilePartInput.fromJson(Map<String, dynamic> json) {
    return FilePartInput(
      id: json["id"] as String?,
      type: json["type"] as String,
      mime: json["mime"] as String,
      filename: json["filename"] as String?,
      url: json["url"] as String,
      source: json["source"] == null ? null : FilePartSource.fromJson(json["source"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": type,
      "mime": mime,
      "filename": filename,
      "url": url,
      "source": source?.toJson(),
    };
  }

  final String? id;
  final String type;
  final String mime;
  final String? filename;
  final String url;
  final FilePartSource? source;
}
