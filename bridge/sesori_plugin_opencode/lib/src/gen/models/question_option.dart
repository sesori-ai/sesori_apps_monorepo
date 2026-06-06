// GENERATED FILE - DO NOT EDIT BY HAND


class QuestionOption {
  const QuestionOption({
    required this.label,
    required this.description,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      label: json["label"] as String,
      description: json["description"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "label": label,
      "description": description,
    };
  }

  final String label;
  final String description;
}
