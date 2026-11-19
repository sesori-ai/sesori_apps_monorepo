import "package:sesori_shared/sesori_shared.dart";

/// What the user has picked and written on one question page, and the page's
/// closing note. A question the user hasn't touched has no entry in [answers].
/// Blank text counts as no text, so the draft never holds an empty string.
final class PageDraft({required Map<String, PageAnswer> answers, required final String? note}) {
  final Map<String, PageAnswer> answers = Map.unmodifiable(answers);

  static final PageDraft empty = PageDraft(answers: const {}, note: null);

  /// Whether the user has picked or written anything on the page.
  bool get hasInput => answers.isNotEmpty || note != null;

  /// The questions on [page] this draft leaves unanswered, in page order. A
  /// question of a kind this app doesn't know can't be answered here, so it is
  /// never listed.
  List<PageQuestion> unanswered({required PendingPage page}) => [
    for (final section in page.sections)
      for (final question in section.questions)
        if (question.kind is! PageQuestionKindUnknown && !_answers(question: question)) question,
  ];

  /// A note alone doesn't answer a question.
  bool _answers({required PageQuestion question}) => switch ((question.kind, answers[question.id]?.value)) {
    (PageSingleChoice(), PageChoiceAnswer()) || (PageTextInput(), PageTextAnswer()) => true,
    (PageMultipleChoice(), PageChoicesAnswer(:final optionIds)) => optionIds.isNotEmpty,
    _ => false,
  };

  /// A null [optionId] clears a single-choice pick.
  PageDraft withChoice({required String questionId, required String? optionId}) => _withAnswer(
    questionId: questionId,
    value: optionId == null ? null : PageChoiceAnswer(optionId: optionId),
    note: answers[questionId]?.note,
  );

  /// An empty [optionIds] clears a multiple-choice pick.
  PageDraft withChoices({required String questionId, required List<String> optionIds}) => _withAnswer(
    questionId: questionId,
    value: optionIds.isEmpty ? null : PageChoicesAnswer(optionIds: List.unmodifiable(optionIds)),
    note: answers[questionId]?.note,
  );

  PageDraft withText({required String questionId, required String? text}) {
    final present = _present(text: text);
    return _withAnswer(
      questionId: questionId,
      value: present == null ? null : PageTextAnswer(text: present),
      note: answers[questionId]?.note,
    );
  }

  PageDraft withQuestionNote({required String questionId, required String? note}) =>
      _withAnswer(questionId: questionId, value: answers[questionId]?.value, note: note);

  PageDraft withNote({required String? note}) => PageDraft(
    answers: answers,
    note: _present(text: note),
  );

  PageDraft _withAnswer({required String questionId, required PageAnswerValue? value, required String? note}) {
    final presentNote = _present(text: note);
    final next = {...answers};
    if (value == null && presentNote == null) {
      next.remove(questionId);
    } else {
      next[questionId] = PageAnswer(questionId: questionId, value: value, note: presentNote);
    }
    return PageDraft(answers: next, note: this.note);
  }

  static String? _present({required String? text}) => text == null || text.trim().isEmpty ? null : text;
}
