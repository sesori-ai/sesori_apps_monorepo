// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.251801Z

import 'package:meta/meta.dart';

@immutable
class SkillV2Info {
  const SkillV2Info({
    required this.name,
    this.description,
    this.slash,
    required this.location,
    required this.content,
  });

  factory SkillV2Info.fromJson(Map<String, dynamic> json) {
    return SkillV2Info(
      name: json["name"] as String,
      description: json["description"] as String?,
      slash: json["slash"] as bool?,
      location: json["location"] as String,
      content: json["content"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "description": ?description,
      "slash": ?slash,
      "location": location,
      "content": content,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkillV2Info &&
          other.name == name &&
          other.description == description &&
          other.slash == slash &&
          other.location == location &&
          other.content == content);

  @override
  int get hashCode => Object.hash(name, description, slash, location, content);

  final String name;
  final String? description;
  final bool? slash;
  final String location;
  final String content;
}
