import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../codex_app_server_client.dart";
import "../models/codex_user_input_dto.dart";

class const CodexQuestionParser() {
  CodexUserInputParamsDto parseUserInput({required Map<String, dynamic> params}) =>
      CodexUserInputParamsDto.fromJson(params);

  ({String threadId, List<CodexAsyncUserInputQuestionDto> questions})? parseAsyncQuestion({
    required CodexServerNotification notification,
  }) {
    if (notification.method != "item/completed") return null;
    try {
      final params = CodexQuestionItemParamsDto.fromJson(notification.params);
      if (params.item
          case CodexAgentQuestionItemDto(
            delivery: CodexAgentMessageDelivery.async,
            questions: final questions?,
          )
          when questions.isNotEmpty) {
        return (threadId: params.threadId, questions: questions);
      }
    } on Object catch (error, stackTrace) {
      Log.w("[codex] failed to decode question item notification", error, stackTrace);
    }
    return null;
  }
}
