import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "request_handler.dart";

/// Handles `POST /session/messages` — returns all messages for a session.
class GetSessionMessagesHandler extends BodyRequestHandler<SessionIdRequest, MessageWithPartsResponse> {
  final SessionRepository _sessionRepository;

  GetSessionMessagesHandler({required SessionRepository sessionRepository})
    : _sessionRepository = sessionRepository,
      super(
        HttpMethod.post,
        "/session/messages",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<MessageWithPartsResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    return MessageWithPartsResponse(
      messages: await _sessionRepository.getSessionMessages(sessionId: sessionId),
    );
  }
}
