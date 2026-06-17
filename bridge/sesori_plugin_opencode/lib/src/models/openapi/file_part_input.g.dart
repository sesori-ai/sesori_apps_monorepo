// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'file_part_source.g.dart';

@immutable
class FilePartInput {
  const FilePartInput({
    required this.id,
    required this.type,
    required this.mime,
    required this.filename,
    required this.url,
    required this.source,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FilePartInput copyWith({
    String? id,
    String? type,
    String? mime,
    String? filename,
    String? url,
    FilePartSource? source,
  }) {
    return FilePartInput(
      id: id ?? this.id,
      type: type ?? this.type,
      mime: mime ?? this.mime,
      filename: filename ?? this.filename,
      url: url ?? this.url,
      source: source ?? this.source,
    );
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
