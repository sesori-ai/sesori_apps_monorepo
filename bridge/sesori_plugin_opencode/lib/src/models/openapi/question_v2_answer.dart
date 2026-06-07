// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.673298Z


/// Type alias for `List<String>` decoded from JSON.
class QuestionV2Answer {
  const QuestionV2Answer({required this.items});
  factory QuestionV2Answer.fromJson(List<dynamic> json) => QuestionV2Answer(items: json.map((e) => e as String).toList());
  List<dynamic> toJson() => items.toList();
  final List<String> items;
}
