// GENERATED FILE - DO NOT EDIT BY HAND


class QuestionV2Option {
  const QuestionV2Option({
    required this.label,
    required this.description,
  });

  factory QuestionV2Option.fromJson(Map<String, dynamic> json) {
    return QuestionV2Option(
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
