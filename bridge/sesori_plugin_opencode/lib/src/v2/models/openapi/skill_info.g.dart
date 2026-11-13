// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:meta/meta.dart';

@immutable
class SkillInfo {
  const SkillInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.autoinvoke,
    required this.path,
    required this.content,
  });

  factory SkillInfo.fromJson(Map<String, dynamic> json) {
    return SkillInfo(
      id: json["id"] as String,
      name: json["name"] as String,
      description: json["description"] as String?,
      autoinvoke: json["autoinvoke"] as bool?,
      path: json["path"] as String,
      content: json["content"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "description": ?description,
      "autoinvoke": ?autoinvoke,
      "path": path,
      "content": content,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SkillInfo copyWith({
    String? id,
    String? name,
    String? description,
    bool? autoinvoke,
    String? path,
    String? content,
  }) {
    return SkillInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      autoinvoke: autoinvoke ?? this.autoinvoke,
      path: path ?? this.path,
      content: content ?? this.content,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkillInfo &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.autoinvoke == autoinvoke &&
          other.path == path &&
          other.content == content);

  @override
  int get hashCode => Object.hash(id, name, description, autoinvoke, path, content);

  final String id;
  final String name;
  final String? description;
  final bool? autoinvoke;
  final String path;
  final String content;
}
