import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/claude_side_question_response_dto.dart";
import "../../foundation/trimmed_or_null.dart";

/// Maps Claude's `side_question` reply into the plugin contract.
class const ClaudeSideAnswerMapper() {
  PluginSideAnswer map({required ClaudeSideQuestionResponseDto response}) {
    // A synthetic reply is the CLI's stand-in text, such as "(The model tried
    // to call a tool instead of answering…)" or "(API error: …)", not an answer.
    final text = response.synthetic ? null : trimmedOrNull(value: response.response);
    if (text == null) return const PluginSideRefused(reason: PluginSideRefusal.noAnswer);
    return PluginSideAnswered(text: text, notice: trimmedOrNull(value: response.refusalFallback?.content));
  }

  /// The CLI predates the `side_question` handler.
  PluginSideAnswer unsupported() => const PluginSideRefused(reason: PluginSideRefusal.harnessUpdateRequired);
}
