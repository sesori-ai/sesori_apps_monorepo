// GENERATED FILE - DO NOT EDIT BY HAND


class WorktreeResetInput {
  const WorktreeResetInput({
    required this.directory,
  });

  factory WorktreeResetInput.fromJson(Map<String, dynamic> json) {
    return WorktreeResetInput(
      directory: json["directory"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
    };
  }

  final String directory;
}
