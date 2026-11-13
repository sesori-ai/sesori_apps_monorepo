// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'file_part_source.g.dart';
import 'file_part_source_text.g.dart';
import 'range.g.dart';

@immutable
class SymbolSource implements FilePartSource {
  const SymbolSource({
    required this.text,
    required this.path,
    required this.range,
    required this.name,
    required this.kind,
  });

  factory SymbolSource.fromJson(Map<String, dynamic> json) {
    return SymbolSource(
      text: FilePartSourceText.fromJson(json["text"] as Map<String, dynamic>),
      path: json["path"] as String,
      range: Range.fromJson(json["range"] as Map<String, dynamic>),
      name: json["name"] as String,
      kind: (json["kind"] as num).toInt(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text.toJson(),
      "type": "symbol",
      "path": path,
      "range": range.toJson(),
      "name": name,
      "kind": kind,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SymbolSource copyWith({
    FilePartSourceText? text,
    String? path,
    Range? range,
    String? name,
    int? kind,
  }) {
    return SymbolSource(
      text: text ?? this.text,
      path: path ?? this.path,
      range: range ?? this.range,
      name: name ?? this.name,
      kind: kind ?? this.kind,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SymbolSource &&
          other.text == text &&
          other.path == path &&
          other.range == range &&
          other.name == name &&
          other.kind == kind);

  @override
  int get hashCode => Object.hash(text, path, range, name, kind);

  final FilePartSourceText text;
  final String path;
  final Range range;
  final String name;
  final int kind;
}
