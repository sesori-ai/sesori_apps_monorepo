import "models/plugin_side_question.dart";

/// Optional support for side questions. A plugin that implements it also
/// returns true from `BridgePluginDescriptor.supportsSideQuestions`.
abstract interface class SideQuestionPluginApi() {
  /// Answers [question] from what the session already knows, without running
  /// tools and without writing to the session's transcript, while any running
  /// turn continues. [history] is this side chat's earlier exchanges, oldest
  /// first. May make an idle session resident; never starts or queues a turn,
  /// and never changes or restarts a running one. Returns the whole answer at
  /// once; side answers never stream.
  Future<PluginSideAnswer> askSideQuestion({
    required String sessionId,
    required String question,
    required List<PluginSideExchange> history,
  });
}
