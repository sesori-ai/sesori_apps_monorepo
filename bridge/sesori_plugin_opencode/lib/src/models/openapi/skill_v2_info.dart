// GENERATED FILE - DO NOT EDIT BY HAND


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
      "description": description,
      "slash": slash,
      "location": location,
      "content": content,
    };
  }

  final String name;
  final String? description;
  final bool? slash;
  final String location;
  final String content;
}
