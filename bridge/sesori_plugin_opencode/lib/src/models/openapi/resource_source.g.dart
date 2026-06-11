// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'file_part_source.g.dart';
import 'file_part_source_text.g.dart';

@immutable
class ResourceSource implements FilePartSource {
  const ResourceSource({
    required this.text,
    this.clientName = '',
    this.uri = '',
  });

  factory ResourceSource.fromJson(Map<String, dynamic> json) {
    return ResourceSource(
      text: FilePartSourceText.fromJson((json["text"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
      clientName: (json["clientName"] ?? '') as String,
      uri: (json["uri"] ?? '') as String,
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
