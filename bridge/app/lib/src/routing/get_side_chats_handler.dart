import "package:sesori_shared/sesori_shared.dart";

import "../repositories/side_chat_repository.dart";
import "request_handler.dart";

class GetSideChatsHandler({required final SideChatRepository _sideChatRepository})
    extends BodyRequestHandler<SessionIdRequest, SideChatListResponse> {
  this : super(method: HttpMethod.post, path: "/session/side-chats", fromJson: SessionIdRequest.fromJson);

  @override
  Future<SideChatListResponse> handle({required RelayRequest request, required SessionIdRequest body}) {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    return _sideChatRepository.listForSession(sessionId: body.sessionId);
  }
}
