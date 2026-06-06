// GENERATED FILE - DO NOT EDIT BY HAND


/// Type alias for `List<String>` decoded from JSON.
class QuestionV2Answer {
  const QuestionV2Answer({required this.items});
  factory QuestionV2Answer.fromJson(List<dynamic> json) => QuestionV2Answer(items: json.map((e) => e as String).toList());
  List<dynamic> toJson() => items.toList();
  final List<String> items;
}
