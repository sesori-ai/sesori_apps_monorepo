import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_notice.dart";

/// What the session that sent a page is told once the user settled it: a
/// short line for the user and the agent's guidance.
class const AgentPageAnswerNoticeBuilder() {
  static const String _answerFormat =
      "Each line below is one question: its id and title, then the chosen option ids and labels or the text "
      "answer. Text answers, notes and “Anything else” are the user's own words.";

  /// The user submitted [page] with [answers] and the closing [note]. The
  /// guidance carries every answer in full, one line per question, so the
  /// agent needs nothing else to act on it.
  SessionNotice answered({required PendingPage page, required List<PageAnswer> answers, required String? note}) {
    final byQuestion = {for (final answer in answers) answer.questionId: answer};
    final questions = [for (final section in page.sections) ...section.questions];
    return SessionNotice(
      summary: "You answered ${_quoted(text: page.title)}.",
      guidance: [
        if (page.displaySessionId != null) "Sub-agent session ${page.sessionId} sent this page.",
        "The user answered the page ${_plain(text: page.title)}.",
        _answerFormat,
        for (final question in questions) _answerLine(question: question, answer: byQuestion[question.id]),
        if (note != null) "Anything else: ${_userText(text: note)}",
        "Act on the answers, and acknowledge them in one short line.",
      ].join("\n"),
      pageRequestId: page.id,
    );
  }

  /// The user closed [page] without answering.
  SessionNotice dismissed({required PendingPage page}) {
    return SessionNotice(
      summary: "You closed ${_quoted(text: page.title)} without answering.",
      guidance: [
        if (page.displaySessionId != null) "Sub-agent session ${page.sessionId} sent this page.",
        "The user closed the page without answering it. Don't send it again unless they ask.",
        "Reply in one short line.",
      ].join(" "),
      pageRequestId: page.id,
    );
  }

  /// `- id “Title”: answer; note: …`, on one line.
  String _answerLine({required PageQuestion question, required PageAnswer? answer}) {
    final value = switch ((question.kind, answer?.value)) {
      (_, null) => "no answer",
      (PageSingleChoice(:final options), PageChoiceAnswer(:final optionId)) => _option(
        options: options,
        optionId: optionId,
      ),
      (PageMultipleChoice(:final options), PageChoicesAnswer(:final optionIds)) => [
        for (final optionId in optionIds) _option(options: options, optionId: optionId),
      ].join(", "),
      (_, PageTextAnswer(:final text)) => _userText(text: text),
      // Submit validation lets no other pairing through.
      (_, PageChoiceAnswer() || PageChoicesAnswer() || PageAnswerUnknown()) => "no answer",
    };
    final note = answer?.note;
    return "- ${question.id} ${_plain(text: question.title)}: $value"
        "${note == null ? "" : "; note: ${_userText(text: note)}"}";
  }

  String _option({required List<PageOption> options, required String optionId}) {
    final label = options.where((option) => option.id == optionId).firstOrNull?.label;
    return label == null ? optionId : "$optionId ${_plain(text: label)}";
  }

  /// The user's free text on one line, quoted, so a line break in it can't
  /// pass for a line of the notice or break its frame.
  String _userText({required String text}) => "“${text.trim().replaceAll(RegExp(r"\s*\n\s*"), " / ")}”";

  /// The agent's own text on one line, quoted.
  String _plain({required String text}) => "“${text.replaceAll(RegExp(r"\s+"), " ").trim()}”";

  String _quoted({required String text}) => "“${_inline(text: text)}”";

  /// [text] on one line with Markdown syntax escaped, as the summary renders
  /// as Markdown.
  String _inline({required String text}) {
    return text
        .replaceAll(RegExp(r"\s+"), " ")
        .trim()
        .replaceAllMapped(RegExp(r"[\\`*_\[\]<>~|#!]"), (match) => "\\${match[0]}");
  }
}
