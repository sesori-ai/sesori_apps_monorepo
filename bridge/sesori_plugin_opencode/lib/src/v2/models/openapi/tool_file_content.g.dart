// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';
import 'tool_content.g.dart';

@immutable
class ToolFileContent implements ToolContent {
  const ToolFileContent({
    required this.uri,
    required this.mime,
    required this.name,
  });

  factory ToolFileContent.fromJson(Map<String, dynamic> json) {
    return ToolFileContent(
      uri: json["uri"] as String,
      mime: json["mime"] as String,
      name: json["name"] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "file",
      "uri": uri,
      "mime": mime,
      "name": ?name,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ToolFileContent copyWith({
    String? uri,
    String? mime,
    String? name,
  }) {
    return ToolFileContent(
      uri: uri ?? this.uri,
      mime: mime ?? this.mime,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolFileContent &&
          other.uri == uri &&
          other.mime == mime &&
          other.name == name);

  @override
  int get hashCode => Object.hash(uri, mime, name);

  final String uri;
  final String mime;
  final String? name;
}
