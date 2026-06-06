// GENERATED FILE - DO NOT EDIT BY HAND


class WorktreeRemoveInput {
  const WorktreeRemoveInput({
    required this.directory,
  });

  factory WorktreeRemoveInput.fromJson(Map<String, dynamic> json) {
    return WorktreeRemoveInput(
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
