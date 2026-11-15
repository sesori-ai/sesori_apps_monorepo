import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/side_chat_api.dart";

/// A session's side chats, stored on the bridge. The wire models are already
/// the domain models, so nothing is mapped here.
@lazySingleton
class SideChatRepository({required final SideChatApi _api}) {
  /// The session's side chats, newest first by their last answer.
  Future<ApiResponse<SideChatListResponse>> listSideChats({required String sessionId}) =>
      _api.listSideChats(sessionId: sessionId);

  /// Asks [question] in the side chat [sideChatId], or in a new one when it
  /// is null. The bridge stores the exchange only when it answers.
  Future<ApiResponse<AskSideQuestionResponse>> askSideQuestion({
    required String sessionId,
    required String? sideChatId,
    required String question,
  }) => _api.askSideQuestion(
    request: AskSideQuestionRequest(sessionId: sessionId, sideChatId: sideChatId, question: question),
  );
}
