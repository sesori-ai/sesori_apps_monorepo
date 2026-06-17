// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'file_part_source.g.dart';
import 'file_part_source_text.g.dart';

@immutable
class ResourceSource implements FilePartSource {
  const ResourceSource({
    required this.text,
    required this.clientName,
    required this.uri,
  });

  factory ResourceSource.fromJson(Map<String, dynamic> json) {
    return ResourceSource(
      text: FilePartSourceText.fromJson(json["text"] as Map<String, dynamic>),
      clientName: json["clientName"] as String,
      uri: json["uri"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text.toJson(),
      "type": "resource",
      "clientName": clientName,
      "uri": uri,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ResourceSource copyWith({
    FilePartSourceText? text,
    String? clientName,
    String? uri,
  }) {
    return ResourceSource(
      text: text ?? this.text,
      clientName: clientName ?? this.clientName,
      uri: uri ?? this.uri,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceSource &&
          other.text == text &&
          other.clientName == clientName &&
          other.uri == uri);

  @override
  int get hashCode => Object.hash(text, clientName, uri);

  final FilePartSourceText text;
  final String clientName;
  final String uri;
}
