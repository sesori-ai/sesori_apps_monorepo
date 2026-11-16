/// One earlier question and answer of a side chat, passed back to the plugin
/// as history for the next side question.
final class const PluginSideExchange({
  required final String question,
  required final String answer,
});

/// Why a plugin answered a side question with no answer.
enum PluginSideRefusal() {
  /// The installed harness lacks the side-question seam, or can't ask while a
  /// turn runs.
  harnessUpdateRequired,

  /// The session has no turn yet, so there is nothing to answer from.
  noTurnYet,

  /// The question, with its history, is too long for the harness.
  tooLong,

  /// The model tried a tool, gave no text, or gave a stand-in answer.
  noAnswer,

  /// The harness returned the reply of the turn running beside the question
  /// instead of an answer to it.
  repeatedRunningReply,
}

sealed class const PluginSideAnswer();

/// The whole answer. [notice] is a harness note about how it was answered,
/// for example Claude's fallback-model notice; null when there is none.
final class const PluginSideAnswered({
  required final String text,
  required final String? notice,
}) extends PluginSideAnswer;

/// The harness answered the request but gave no answer, for [reason].
final class const PluginSideRefused({
  required final PluginSideRefusal reason,
}) extends PluginSideAnswer;
