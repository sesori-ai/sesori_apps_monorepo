// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class ToolFileContent {
  const ToolFileContent({
    required this.type,
    required this.source,
    required this.mime,
    this.name,
  });

  factory ToolFileContent.fromJson(Map<String, dynamic> json) {
    return ToolFileContent(
      type: json["type"] as String,
      source: json["source"] as Object,
      mime: json["mime"] as String,
      name: json["name"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "source": source,
      "mime": mime,
      "name": ?name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolFileContent &&
          other.type == type &&
          const DeepCollectionEquality().equals(other.source, source) &&
          other.mime == mime &&
          other.name == name);

  @override
  int get hashCode => Object.hash(type, const DeepCollectionEquality().hash(source), mime, name);

  final String type;
  final Object source;
  final String mime;
  final String? name;
}
