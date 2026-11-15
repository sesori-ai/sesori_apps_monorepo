import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/models/side_question_ask_result.dart";
import "../repositories/session_repository.dart";
import "../repositories/side_chat_repository.dart";
import "archived_session_validator.dart";

/// Asks one side question and stores its answer.
///
/// Deliberately not on a session lane: a lane would hold the session's
/// prompts, aborts and replies behind a slow ask, and a side question writes
/// nothing the lane protects. An archive during an ask stores one more
/// exchange on a now read-only chat; a delete fails the insert's foreign key,
/// which fails this request.
///
/// Logs never carry question or answer text.
class SideQuestionService({
  required final ArchivedSessionValidator _archivedSessionValidator,
  required final SessionRepository _sessionRepository,
  required final SideChatRepository _sideChatRepository,
}) {
  Future<AskSideQuestionResponse> ask({required AskSideQuestionRequest request}) async {
    final sessionId = request.sessionId;
    final storedSession = await _archivedSessionValidator.requireNotArchived(sessionId: sessionId);
    if (storedSession == null) {
      throw PluginOperationException.notFound(
        operation: SessionOperation.askSideQuestion.name,
        message: "session $sessionId was not found",
      );
    }
    if (storedSession.parentSessionId != null) {
      throw PluginOperationException(
        operation: SessionOperation.askSideQuestion.name,
        statusCode: 400,
        message: "session $sessionId is a sub-agent session; side questions are asked of its root session",
      );
    }
    final history = await _sideChatRepository.historyFor(sessionId: sessionId, sideChatId: request.sideChatId);
    final askedAt = clock.now();
    final result = await _sessionRepository.askSideQuestion(
      sessionId: sessionId,
      question: request.question,
      history: history,
    );
    final elapsedMs = clock.now().difference(askedAt).inMilliseconds;
    switch (result) {
      case SideQuestionAnswered(:final text, :final notice):
        final recorded = await _sideChatRepository.recordExchange(
          sessionId: sessionId,
          sideChatId: request.sideChatId,
          question: request.question,
          answer: text,
          notice: notice,
          askedAt: askedAt,
        );
        Log.i(
          "Side question answered for session $sessionId (${storedSession.pluginId}) in ${elapsedMs}ms, "
          "side chat ${recorded.sideChatId}, ${history.length} earlier exchanges",
        );
        return AskSideQuestionResponse.answered(sideChatId: recorded.sideChatId, exchange: recorded.exchange);
      case SideQuestionRefused(:final reason):
        Log.i(
          "Side question refused for session $sessionId (${storedSession.pluginId}) after ${elapsedMs}ms: "
          "${reason.name}",
        );
        return AskSideQuestionResponse.refused(reason: reason);
    }
  }
}
