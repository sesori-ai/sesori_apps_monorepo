import "package:sesori_shared/sesori_shared.dart";

import "../services/side_question_service.dart";
import "request_handler.dart";

class AskSideQuestionHandler({required final SideQuestionService _sideQuestionService})
    extends BodyRequestHandler<AskSideQuestionRequest, AskSideQuestionResponse> {
  this : super(method: HttpMethod.post, path: "/session/side-question", fromJson: AskSideQuestionRequest.fromJson);

  @override
  Future<AskSideQuestionResponse> handle({required RelayRequest request, required AskSideQuestionRequest body}) {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    requireNonEmpty(request: request, value: body.question.trim(), label: "question");
    return _sideQuestionService.ask(request: body);
  }
}
