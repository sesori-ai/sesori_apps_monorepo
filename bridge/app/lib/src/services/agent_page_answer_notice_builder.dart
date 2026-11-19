import "package:sesori_shared/sesori_shared.dart" show PendingPage;

import "../repositories/models/session_notice.dart";

/// What the session that sent a page is told once the user settled it: a
/// short line for the user and the agent's guidance.
class const AgentPageAnswerNoticeBuilder() {
  /// The user closed [page] without answering.
  SessionNotice dismissed({required PendingPage page}) {
    return SessionNotice(
      summary: "You closed ${_quoted(text: page.title)} without answering.",
      guidance: [
        if (page.displaySessionId != null) "Sub-agent session ${page.sessionId} sent this page.",
        "The user closed the page without answering it. Don't send it again unless they ask.",
        "Reply in one short line.",
      ].join(" "),
    );
  }

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
