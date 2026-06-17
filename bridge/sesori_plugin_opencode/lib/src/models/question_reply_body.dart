class QuestionReplyBody {
  final List<List<String>> answers;

  const QuestionReplyBody({required this.answers});

  Map<String, dynamic> toJson() {
    return {"answers": answers};
  }
}
