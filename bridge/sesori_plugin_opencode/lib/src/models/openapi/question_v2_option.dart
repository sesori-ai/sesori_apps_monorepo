// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.185807Z


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
