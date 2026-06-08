// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.968994Z

import 'package:meta/meta.dart';
import 'file_part_source.dart';

@immutable
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
      source: json["source"] == null ? null : FilePartSource.fromJson(json["source"] as Object),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": ?id,
      "type": type,
      "mime": mime,
      "filename": ?filename,
      "url": url,
      "source": ?source?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilePartInput &&
          other.id == id &&
          other.type == type &&
          other.mime == mime &&
          other.filename == filename &&
          other.url == url &&
          other.source == source);

  @override
  int get hashCode => Object.hash(id, type, mime, filename, url, source);

  final String? id;
  final String type;
  final String mime;
  final String? filename;
  final String url;
  final FilePartSource? source;
}
