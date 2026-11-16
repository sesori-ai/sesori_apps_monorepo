import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/claude_side_question_response_dto.dart";
import "../../foundation/trimmed_or_null.dart";

/// Maps Claude's `side_question` reply into the plugin contract.
class const ClaudeSideAnswerMapper() {
  /// [turnRepliesDuringAsk] are the final replies of the turns that ended
  /// while the question was out.
  PluginSideAnswer map({
    required ClaudeSideQuestionResponseDto response,
    required List<String> turnRepliesDuringAsk,
  }) {
    // A synthetic reply is the CLI's stand-in text, such as "(The model tried
    // to call a tool instead of answering…)" or "(API error: …)", not an answer.
    final text = response.synthetic ? null : trimmedOrNull(value: response.response);
    if (text == null) return const PluginSideRefused(reason: PluginSideRefusal.noAnswer);
    // A question asked early in a streaming turn can come back after that
    // turn's result holding the turn's whole reply instead of an answer (seen
    // on 2.1.325, anthropics/claude-code#110490). A real answer that happens
    // to equal a reply ending meanwhile is rare, and only costs a re-ask.
    if (turnRepliesDuringAsk.any((reply) => trimmedOrNull(value: reply) == text)) {
      return const PluginSideRefused(reason: PluginSideRefusal.repeatedRunningReply);
    }
    return PluginSideAnswered(
      text: text,
      notice: trimmedOrNull(value: response.refusalFallback?.content),
    );
  }

  /// The CLI predates the `side_question` handler.
  PluginSideAnswer unsupported() => const PluginSideRefused(reason: PluginSideRefusal.harnessUpdateRequired);
}
