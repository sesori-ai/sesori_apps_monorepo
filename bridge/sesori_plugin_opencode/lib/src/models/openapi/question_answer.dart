// GENERATED FILE - DO NOT EDIT BY HAND


/// Type alias for `List<String>` decoded from JSON.
class QuestionAnswer {
  const QuestionAnswer({required this.items});
  factory QuestionAnswer.fromJson(List<dynamic> json) => QuestionAnswer(items: json.map((e) => e as String).toList());
  List<dynamic> toJson() => items.toList();
  final List<String> items;
}
