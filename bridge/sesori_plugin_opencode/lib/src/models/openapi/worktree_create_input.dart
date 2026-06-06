// GENERATED FILE - DO NOT EDIT BY HAND


class WorktreeCreateInput {
  const WorktreeCreateInput({
    this.name,
    this.startCommand,
  });

  factory WorktreeCreateInput.fromJson(Map<String, dynamic> json) {
    return WorktreeCreateInput(
      name: json["name"] as String?,
      startCommand: json["startCommand"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "startCommand": startCommand,
    };
  }

  final String? name;
  final String? startCommand;
}
