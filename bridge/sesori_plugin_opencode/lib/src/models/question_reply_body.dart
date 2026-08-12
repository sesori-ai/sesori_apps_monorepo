class const QuestionReplyBody({required this.answers}) {
  final List<List<String>> answers;

  Map<String, dynamic> toJson() {
    return {"answers": answers};
  }
}
