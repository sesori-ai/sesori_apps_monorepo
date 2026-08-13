class const QuestionReplyBody({required final List<List<String>> answers}) {
  Map<String, dynamic> toJson() {
    return {"answers": answers};
  }
}
