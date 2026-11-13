// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'file_part_source.g.dart';
import 'file_part_source_text.g.dart';

@immutable
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FileSource copyWith({
    FilePartSourceText? text,
    String? path,
  }) {
    return FileSource(
      text: text ?? this.text,
      path: path ?? this.path,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileSource &&
          other.text == text &&
          other.path == path);

  @override
  int get hashCode => Object.hash(text, path);

  final FilePartSourceText text;
  final String path;
}
